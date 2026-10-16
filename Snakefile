# variant-call: the ten-stage germline variant pipeline in Snakemake.
#
# Read it from the bottom of the DAG up. `rule all` names the files the run must
# end with. For each one Snakemake finds the rule whose output pattern matches it,
# and then does the same for that rule's inputs, back to the FASTQs. Nothing here
# says "run this, then that": the order comes from which file each rule needs.

import csv
import os
import re

from snakemake.utils import min_version

min_version("9.0")

configfile: "config.yaml"

# A --config key that nothing reads would be ignored without a word, so refuse it.
KNOWN = {"samplesheet", "ref", "region", "outdir", "platform", "executor", "containers"}
unknown = sorted(set(config) - KNOWN)
if unknown:
    raise ValueError(f"unknown config key(s): {', '.join(unknown)}; known: {', '.join(sorted(KNOWN))}")
for key in ("samplesheet", "ref", "region"):
    if not config.get(key):
        raise ValueError(f"give --config {key}=...")

PIPELINE = {"name": "variant-call", "version": "1.0.0"}
OUT = config["outdir"]
BIN = os.path.join(workflow.basedir, "bin")      # bin/ is not on the PATH: each script is called by its path
IMAGES = {name: f"docker://{image}" for name, image in config["containers"].items()}

REF = config["ref"]
REF_FAI = REF + ".fai"
REF_BWA = [REF + ext for ext in (".amb", ".ann", ".bwt", ".pac", ".sa")]
REF_DICT = os.path.splitext(REF)[0] + ".dict"
REGION = config["region"]

# ---------------------------------------------------------------------------
# The samplesheet, read once, in plain Python, before any rule runs.
# A FASTQ path is absolute or relative to the samplesheet's folder.
# ---------------------------------------------------------------------------
SHEET = config["samplesheet"]
with open(SHEET) as fh:
    ROWS = list(csv.DictReader(fh))
SAMPLES = [row["sample_id"] for row in ROWS]
PAIRED = [row["sample_id"] for row in ROWS if row["library_type"] == "paired"]
SINGLE = [row["sample_id"] for row in ROWS if row["library_type"] == "single"]


def resolve(path):
    return path if os.path.isabs(path) else os.path.join(os.path.dirname(SHEET), path)


READS = {
    row["sample_id"]: [resolve(row["r1_fastq"])]
    + ([resolve(row["r2_fastq"])] if row["library_type"] == "paired" else [])
    for row in ROWS
}


def one_of(names):
    """A wildcard pattern matching exactly
    these sample names, or nothing at all."""
    return "|".join(map(re.escape, names)) \
        if names else "(?!)"


def trimmed(wildcards):
    """The trimmed reads of one sample: one file if single-end, two if paired."""
    s = wildcards.sample
    if s in PAIRED:
        return [f"work/trim/{s}_R1.trim.fastq.gz", f"work/trim/{s}_R2.trim.fastq.gz"]
    return [f"work/trim/{s}_R1.trim.fastq.gz"]


# ---------------------------------------------------------------------------
# What the run asks for.
# ---------------------------------------------------------------------------
rule all:
    input:
        f"{OUT}/cohort.filtered.vcf.gz",
        f"{OUT}/variants.tsv",
        f"{OUT}/multiqc_report.html",
        f"{OUT}/samples.tsv",
        f"{OUT}/manifest.json",


# Every rule below writes what its command prints to stderr into its own log
# under logs/, one per sample where the output has {sample}. A failed job's
# output is deleted, its log is kept: that is where to look.

# Stage 0: validate the samplesheet, FASTQs and reference indexes,
# before anything computes. A rule must make a file, so this one makes a copy of
# the samplesheet; every per-sample rule takes that copy as an input, which is
# what makes them all wait until validation has passed.
rule validate:
    input:
        sheet=SHEET,
        fastqs=[fq for reads in READS.values() for fq in reads],
        ref=REF,
        ref_index=[REF_FAI] + REF_BWA,
        ref_dict=REF_DICT,
    output:
        "work/validate/samplesheet.csv",
    log:
        "logs/validate.log",
    container: IMAGES["tools"]
    shell:
        "({BIN}/validate_samplesheet_smk.sh {input.sheet:q} {input.ref:q} {input.ref_dict:q} && cp {input.sheet} {output}) 2> {log}"


# Stage 1 · qc_raw — FastQC on the reads as they arrived.
# `{sample}` is a wildcard. This rule can make work/fastqc/<anything>; which
# samples it actually runs for is decided by who asks (multiqc, below).
# FastQC names its files after the FASTQs, so the rule's output is the folder.
rule fastqc:
    input:
        reads=lambda wc: READS[wc.sample],
        checked=rules.validate.output,
    output:
        directory("work/fastqc/{sample}"),
    threads: 4
    log:
        "logs/fastqc/{sample}.log",
    container: IMAGES["fastqc"]
    shell:
        "(mkdir -p {output} && fastqc -q -t {threads} -o {output} {input.reads}) 2> {log}"


# Stage 2 · trim. Two rules, because a rule's outputs are fixed: a paired sample
# makes two trimmed files and a single-end sample makes one. wildcard_constraints
# say which samples each rule may make, so for every sample exactly one rule fits.
rule fastp_paired:
    input:
        r1=lambda wc: READS[wc.sample][0],
        r2=lambda wc: READS[wc.sample][1],
        checked=rules.validate.output,
    output:
        r1="work/trim/{sample}_R1.trim.fastq.gz",
        r2="work/trim/{sample}_R2.trim.fastq.gz",
        json="work/trim/{sample}.fastp.json",
        html="work/trim/{sample}.fastp.html",
    wildcard_constraints:
        sample=one_of(PAIRED),
    threads: 4
    log:
        "logs/fastp/{sample}.log",
    container: IMAGES["fastp"]
    shell:
        "fastp -w {threads} -i {input.r1} -I {input.r2} -o {output.r1} -O {output.r2}"
        " -j {output.json} -h {output.html} 2> {log}"


rule fastp_single:
    input:
        r1=lambda wc: READS[wc.sample][0],
        checked=rules.validate.output,
    output:
        r1="work/trim/{sample}_R1.trim.fastq.gz",
        json="work/trim/{sample}.fastp.json",
        html="work/trim/{sample}.fastp.html",
    wildcard_constraints:
        sample=one_of(SINGLE),
    threads: 4
    log:
        "logs/fastp/{sample}.log",
    container: IMAGES["fastp"]
    shell:
        "fastp -w {threads} -i {input.r1} -o {output.r1} -j {output.json} -h {output.html} 2> {log}"


# Stage 3: align trimmed reads and retain read groups.
rule bwa_mem:
    input:
        reads=trimmed,
        ref=REF,
        ref_index=REF_BWA,
    output:
        bam="work/align/{sample}.unsorted.bam",
        report="work/align/{sample}.bwa.log",
    threads: 8
    log:
        "logs/bwa_mem/{sample}.log",
    container: IMAGES["bwa"]
    shell:
        r"""
        (bwa mem -t {threads} -R '@RG\tID:{wildcards.sample}\tSM:{wildcards.sample}\tPL:ILLUMINA' \
            {input.ref:q} {input.reads:q} | samtools view -b -o {output.bam:q} -
         samtools quickcheck {output.bam:q}
         test "$(samtools view -c {output.bam:q})" -gt 0) 2> {log:q}
        cp {log:q} {output.report:q}
        """


# Stage 4: coordinate sort, mark duplicates, index and summarize.
rule markduplicates:
    input:
        bam=rules.bwa_mem.output.bam,
    output:
        bam="work/postprocess/{sample}.dedup.bam",
        bai="work/postprocess/{sample}.dedup.bam.bai",
        metrics="work/postprocess/{sample}.duplicate_metrics.txt",
        stats="work/postprocess/{sample}.flagstat.txt",
    params:
        tmp="work/postprocess/{sample}.tmp",
    threads: 4
    resources:
        mem_mb=8000,
    log:
        "logs/markduplicates/{sample}.log",
    container: IMAGES["gatk"]
    shell:
        r"""
        (mkdir -p {params.tmp:q}
         samtools sort -@ $(( {threads} - 1 )) -T {params.tmp:q}/sort \
             -o {params.tmp:q}/sorted.bam {input.bam:q}
         gatk --java-options '-Xmx4g' MarkDuplicates \
             -I {params.tmp:q}/sorted.bam -O {output.bam:q} -M {output.metrics:q} \
             --TMP_DIR {params.tmp:q} --CREATE_INDEX false
         samtools quickcheck {output.bam:q}
         samtools index {output.bam:q}
         samtools flagstat {output.bam:q} > {output.stats:q}
         rm -rf {params.tmp:q}) > {log:q} 2>&1
        """


# Stage 5: one gVCF per sample.
rule haplotypecaller:
    input:
        bam=rules.markduplicates.output.bam,
        bai=rules.markduplicates.output.bai,
        ref=REF,
        fai=REF_FAI,
        dictionary=REF_DICT,
    output:
        gvcf="work/gvcf/{sample}.g.vcf.gz",
        tbi="work/gvcf/{sample}.g.vcf.gz.tbi",
    params:
        region=REGION,
        tmp="work/gvcf/{sample}.tmp",
    threads: 8
    resources:
        mem_mb=16000,
    log:
        "logs/haplotypecaller/{sample}.log",
    container: IMAGES["gatk"]
    shell:
        r"""
        (mkdir -p {params.tmp:q}
         gatk --java-options '-Xmx4g' HaplotypeCaller \
             -R {input.ref:q} -I {input.bam:q} -O {output.gvcf:q} \
             -ERC GVCF -L {params.region:q} --tmp-dir {params.tmp:q} \
             --native-pair-hmm-threads {threads}
         gzip -t {output.gvcf:q}
         test -s {output.tbi:q}) > {log:q} 2>&1
        """


# Stage 6: wait for every sample before joint genotyping.
rule joint_genotype:
    input:
        gvcfs=expand("work/gvcf/{sample}.g.vcf.gz", sample=SAMPLES),
        tbis=expand("work/gvcf/{sample}.g.vcf.gz.tbi", sample=SAMPLES),
        ref=REF,
        fai=REF_FAI,
        dictionary=REF_DICT,
    output:
        vcf="work/joint/cohort.raw.vcf.gz",
        tbi="work/joint/cohort.raw.vcf.gz.tbi",
    params:
        variants=lambda wc, input: " ".join("-V " + __import__("shlex").quote(g) for g in input.gvcfs),
        region=REGION,
    resources:
        mem_mb=8000,
    log:
        "logs/joint_genotype.log",
    container: IMAGES["gatk"]
    shell:
        r"""
        (gatk --java-options '-Xmx4g' CombineGVCFs \
             -R {input.ref:q} {params.variants} -O work/joint/cohort.g.vcf.gz -L {params.region:q}
         gatk --java-options '-Xmx4g' GenotypeGVCFs \
             -R {input.ref:q} -V work/joint/cohort.g.vcf.gz -O {output.vcf:q} -L {params.region:q}
         gzip -t {output.vcf:q}
         test -s {output.tbi:q}) > {log:q} 2>&1
        """


# Stage 7: retain every record and label records failing the week-4 filters.
rule filter:
    input:
        vcf=rules.joint_genotype.output.vcf,
        tbi=rules.joint_genotype.output.tbi,
        ref=REF,
        fai=REF_FAI,
        dictionary=REF_DICT,
    output:
        vcf=f"{OUT}/cohort.filtered.vcf.gz",
        tbi=f"{OUT}/cohort.filtered.vcf.gz.tbi",
        table=f"{OUT}/variants.tsv",
    resources:
        mem_mb=8000,
    log:
        "logs/filter.log",
    container: IMAGES["gatk"]
    shell:
        r"""
        (gatk --java-options '-Xmx4g' VariantFiltration \
             -R {input.ref:q} -V {input.vcf:q} -O {output.vcf:q} \
             --filter-name QD2 --filter-expression 'QD < 2.0' \
             --filter-name QUAL30 --filter-expression 'QUAL < 30.0' \
             --filter-name FS60 --filter-expression 'FS > 60.0' \
             --filter-name SOR3 --filter-expression 'SOR > 3.0' \
             --filter-name MQ40 --filter-expression 'MQ < 40.0' \
             --filter-name MQRankSum-12.5 --filter-expression 'MQRankSum < -12.5' \
             --filter-name ReadPosRankSum-8 --filter-expression 'ReadPosRankSum < -8.0'
         gzip -t {output.vcf:q}
         test -s {output.tbi:q}
         printf 'chrom\tpos\tref\talt\tqual\tfilter\n' > {output.table:q}
         bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t%QUAL\t%FILTER\n' \
             {output.vcf:q} >> {output.table:q}) > {log:q} 2>&1
        """


# Stage 8 · qc_report — one report across the cohort.
rule multiqc:
    input:
        expand("work/fastqc/{sample}", sample=SAMPLES),
        expand("work/trim/{sample}.fastp.json", sample=SAMPLES),
        expand("work/align/{sample}.bwa.log", sample=SAMPLES),
        expand("work/postprocess/{sample}.flagstat.txt", sample=SAMPLES),
        expand("work/postprocess/{sample}.duplicate_metrics.txt", sample=SAMPLES),
    output:
        f"{OUT}/multiqc_report.html",
    log:
        "logs/multiqc.log",
    container: IMAGES["multiqc"]
    shell:
        "(multiqc -q -f -o work/multiqc {input} && cp work/multiqc/multiqc_report.html {output}) 2> {log}"


# Stage 9 · publish — the course's rules/publish.smk, unchanged. It writes samples.tsv
# and manifest.json from what it is given here: the validated samplesheet, and the files
# the manifest describes.
PUBLISH_SHEET = rules.validate.output
PUBLISH_RESULTS = [*rules.filter.output, *rules.multiqc.output]
include: "rules/publish.smk"
