#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
RUN_STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
export RUN_STARTED

SHEET=${1:?usage: run_pipeline.sh <samplesheet.csv> <outdir> [last-stage]}
OUT=${2:?usage: run_pipeline.sh <samplesheet.csv> <outdir> [last-stage]}
LAST=${3:-publish}

REF=${REF:-/courses/BINF6610.202710/data/refs/grch38-1000g/GRCh38_full_analysis_set_plus_decoy_hla.fa}
REGION=${REGION:-chr20:1-10000000}
THREADS=${THREADS:-4}
REF_DICT=${REF%.*}.dict

QC="${OUT}/qc_raw"
TRIM="${OUT}/trim"
ALN="${OUT}/align"
POST="${OUT}/postprocess"
GVCF="${OUT}/gvcf"
COHORT="${OUT}/cohort"
RES="${OUT}/results"
LOG="${OUT}/logs"

mkdir -p "$QC" "$TRIM" "$ALN" "$POST" "$GVCF" "$COHORT" "$RES" "$LOG"

log() {
    printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 65
}

STAGES=(
    validate
    qc_raw
    trim
    align
    postprocess
    quantify
    merge
    analyze
    qc_report
    publish
)

known=0
for stage in "${STAGES[@]}"; do
    [[ "$stage" == "$LAST" ]] && known=1
done
(( known )) || die "unknown stage: ${LAST}"

stage_validate() {
    local id _cond _rep lt r1 r2
    local problems=0
    local n1 n2 dupes

    if [[ ! -s "$SHEET" ]]; then
        die "samplesheet missing or empty: $SHEET"
    fi

    while IFS=, read -r id _cond _rep lt r1 r2; do
        if [[ -z "$id" ]]; then
            log "ERROR: a samplesheet row has no sample_id"
            problems=$(( problems + 1 ))
            continue
        fi

        if [[ "$lt" != "single" && "$lt" != "paired" ]]; then
            log "ERROR: $id: invalid library_type: $lt"
            problems=$(( problems + 1 ))
        fi

        if [[ ! -s "$r1" ]]; then
            log "ERROR: $id: R1 missing or empty: $r1"
            problems=$(( problems + 1 ))
        else
            if ! gzip -t "$r1" 2>/dev/null; then
                log "ERROR: $id: R1 is not a valid complete gzip file: $r1"
                problems=$(( problems + 1 ))
            else
                n1=$(gzip -dc "$r1" | wc -l)
                if (( n1 % 4 != 0 )); then
                    log "ERROR: $id: R1 has $n1 lines, not complete FASTQ records"
                    problems=$(( problems + 1 ))
                fi
            fi
        fi

        if [[ "$lt" == "paired" ]]; then
            if [[ -z "$r2" ]]; then
                log "ERROR: $id: paired library has an empty r2_fastq"
                problems=$(( problems + 1 ))
            elif [[ ! -s "$r2" ]]; then
                log "ERROR: $id: R2 missing or empty: $r2"
                problems=$(( problems + 1 ))
            elif ! gzip -t "$r2" 2>/dev/null; then
                log "ERROR: $id: R2 is not a valid complete gzip file: $r2"
                problems=$(( problems + 1 ))
            elif [[ -s "$r1" ]] && gzip -t "$r1" 2>/dev/null; then
                n1=$(gzip -dc "$r1" | wc -l)
                n2=$(gzip -dc "$r2" | wc -l)

                if (( n2 % 4 != 0 )); then
                    log "ERROR: $id: R2 has $n2 lines, not complete FASTQ records"
                    problems=$(( problems + 1 ))
                fi

                if (( n1 != n2 )); then
                    log "ERROR: $id: R1 has $(( n1 / 4 )) reads but R2 has $(( n2 / 4 ))"
                    problems=$(( problems + 1 ))
                fi
            fi
        elif [[ "$lt" == "single" && -n "$r2" ]]; then
            log "ERROR: $id: single-end library has an unexpected r2_fastq"
            problems=$(( problems + 1 ))
        fi
    done < <(tail -n +2 "$SHEET")

    dupes=$(awk -F, 'NR > 1 {print $1}' "$SHEET" | sort | uniq -d)
    if [[ -n "$dupes" ]]; then
        while IFS= read -r duplicate; do
            log "ERROR: duplicate sample_id: $duplicate"
            problems=$(( problems + 1 ))
        done <<< "$dupes"
    fi

    if [[ ! -s "$REF" ]]; then
        log "ERROR: reference FASTA missing or empty: $REF"
        problems=$(( problems + 1 ))
    fi

    if [[ ! -s "${REF}.bwt" ]]; then
        log "ERROR: BWA reference index missing for: $REF"
        problems=$(( problems + 1 ))
    fi

    if [[ ! -s "${REF}.fai" ]]; then
        log "ERROR: FASTA index missing for reference: $REF"
        problems=$(( problems + 1 ))
    fi

    if [[ ! -s "$REF_DICT" ]]; then
        log "ERROR: GATK sequence dictionary missing for reference: $REF_DICT"
        problems=$(( problems + 1 ))
    fi

    if (( problems > 0 )); then
        die "validation failed with ${problems} problem(s)"
    fi

    log "validation passed"
}

stage_qc_raw() {
    local id _cond _rep lt r1 r2 base

    while IFS=, read -r id _cond _rep lt r1 r2; do
        fastqc -q -o "$QC" "$r1" > "${LOG}/${id}.fastqc.log" 2>&1

        if [[ "$lt" == "paired" ]]; then
            fastqc -q -o "$QC" "$r2" >> "${LOG}/${id}.fastqc.log" 2>&1
        fi

        base=$(basename "$r1" .fastq.gz)
        if [[ ! -s "${QC}/${base}_fastqc.zip" ]]; then
            die "$id: FastQC produced no R1 report"
        fi

        if [[ "$lt" == "paired" ]]; then
            base=$(basename "$r2" .fastq.gz)
            if [[ ! -s "${QC}/${base}_fastqc.zip" ]]; then
                die "$id: FastQC produced no R2 report"
            fi
        fi

        log "$id: raw-read QC completed"
    done < <(tail -n +2 "$SHEET")
}

stage_trim() {
    local id _cond _rep lt r1 r2
    local n1 n2

    while IFS=, read -r id _cond _rep lt r1 r2; do
        if [[ "$lt" == "paired" ]]; then
            fastp \
                -i "$r1" \
                -I "$r2" \
                -o "${TRIM}/${id}_R1.fastq.gz" \
                -O "${TRIM}/${id}_R2.fastq.gz" \
                -j "${LOG}/${id}.fastp.json" \
                -h "${LOG}/${id}.fastp.html" \
                --thread "$THREADS" \
                2> "${LOG}/${id}.fastp.log"
        else
            fastp \
                -i "$r1" \
                -o "${TRIM}/${id}_R1.fastq.gz" \
                -j "${LOG}/${id}.fastp.json" \
                -h "${LOG}/${id}.fastp.html" \
                --thread "$THREADS" \
                2> "${LOG}/${id}.fastp.log"
        fi

        if [[ ! -s "${TRIM}/${id}_R1.fastq.gz" ]]; then
            die "$id: fastp produced no R1 output"
        fi

        if ! gzip -t "${TRIM}/${id}_R1.fastq.gz" 2>/dev/null; then
            die "$id: trimmed R1 is not a valid gzip file"
        fi

        n1=$(gzip -dc "${TRIM}/${id}_R1.fastq.gz" | wc -l)

        if (( n1 == 0 || n1 % 4 != 0 )); then
            die "$id: trimmed R1 does not contain complete FASTQ records"
        fi

        if [[ "$lt" == "paired" ]]; then
            if [[ ! -s "${TRIM}/${id}_R2.fastq.gz" ]]; then
                die "$id: fastp produced no R2 output"
            fi

            if ! gzip -t "${TRIM}/${id}_R2.fastq.gz" 2>/dev/null; then
                die "$id: trimmed R2 is not a valid gzip file"
            fi

            n2=$(gzip -dc "${TRIM}/${id}_R2.fastq.gz" | wc -l)

            if (( n2 == 0 || n2 % 4 != 0 )); then
                die "$id: trimmed R2 does not contain complete FASTQ records"
            fi

            if (( n1 != n2 )); then
                die "$id: trimmed R1 and R2 contain different read counts"
            fi
        fi

        log "$id: trimming completed with $(( n1 / 4 )) reads"
    done < <(tail -n +2 "$SHEET")
}

stage_align() {
    local id _cond _rep lt _r1 _r2
    local read_group n_records

    while IFS=, read -r id _cond _rep lt _r1 _r2; do
        read_group="@RG\tID:${id}\tSM:${id}\tPL:ILLUMINA"

        if [[ "$lt" == "paired" ]]; then
            bwa mem \
                -t "$THREADS" \
                -R "$read_group" \
                "$REF" \
                "${TRIM}/${id}_R1.fastq.gz" \
                "${TRIM}/${id}_R2.fastq.gz" \
                2> "${LOG}/${id}.bwa.log"
        else
            bwa mem \
                -t "$THREADS" \
                -R "$read_group" \
                "$REF" \
                "${TRIM}/${id}_R1.fastq.gz" \
                2> "${LOG}/${id}.bwa.log"
        fi | samtools view \
                -@ "$THREADS" \
                -b \
                -o "${ALN}/${id}.unsorted.bam" \
                - \
                2>> "${LOG}/${id}.bwa.log"

        if [[ ! -s "${ALN}/${id}.unsorted.bam" ]]; then
            die "$id: alignment produced no BAM file"
        fi

        if ! samtools quickcheck "${ALN}/${id}.unsorted.bam"; then
            die "$id: alignment produced an invalid or truncated BAM"
        fi

        n_records=$(samtools view -c "${ALN}/${id}.unsorted.bam")

        if (( n_records == 0 )); then
            die "$id: BAM contains no alignment records"
        fi

        log "$id: alignment produced ${n_records} records"
    done < <(tail -n +2 "$SHEET")
}

stage_postprocess() {
    local id _cond _rep _lt _r1 _r2
    local sorted_bam final_bam metrics index_file n_records

    while IFS=, read -r id _cond _rep _lt _r1 _r2; do
        sorted_bam="${POST}/${id}.sorted.bam"
        final_bam="${POST}/${id}.dedup.bam"
        metrics="${LOG}/${id}.duplicate_metrics.txt"
        index_file="${final_bam}.bai"

        samtools sort \
            -@ "$THREADS" \
            -o "$sorted_bam" \
            "${ALN}/${id}.unsorted.bam" \
            2> "${LOG}/${id}.samtools_sort.log"

        if [[ ! -s "$sorted_bam" ]]; then
            die "$id: sorting produced no BAM file"
        fi

        if ! samtools quickcheck "$sorted_bam"; then
            die "$id: sorted BAM is invalid or truncated"
        fi

        gatk MarkDuplicates \
            -I "$sorted_bam" \
            -O "$final_bam" \
            -M "$metrics" \
            --CREATE_INDEX false \
            > "${LOG}/${id}.markduplicates.log" 2>&1

        if [[ ! -s "$final_bam" ]]; then
            die "$id: duplicate marking produced no BAM file"
        fi

        if ! samtools quickcheck "$final_bam"; then
            die "$id: duplicate-marked BAM is invalid or truncated"
        fi

        if [[ ! -s "$metrics" ]]; then
            die "$id: duplicate marking produced no metrics"
        fi

        samtools index "$final_bam"

        if [[ ! -s "$index_file" ]]; then
            die "$id: BAM indexing produced no index"
        fi

        samtools flagstat "$final_bam" > "${LOG}/${id}.flagstat.txt"

        if [[ ! -s "${LOG}/${id}.flagstat.txt" ]]; then
            die "$id: samtools flagstat produced no report"
        fi

        n_records=$(samtools view -c "$final_bam")

        if (( n_records == 0 )); then
            die "$id: duplicate-marked BAM contains no records"
        fi

        log "$id: postprocessing completed with ${n_records} records"
    done < <(tail -n +2 "$SHEET")
}

stage_quantify() {
    local id _cond _rep _lt _r1 _r2
    local input_bam sample_gvcf gvcf_index n_records

    while IFS=, read -r id _cond _rep _lt _r1 _r2; do
        input_bam="${POST}/${id}.dedup.bam"
        sample_gvcf="${GVCF}/${id}.g.vcf.gz"
        gvcf_index="${sample_gvcf}.tbi"

        gatk HaplotypeCaller \
            -R "$REF" \
            -I "$input_bam" \
            -O "$sample_gvcf" \
            -ERC GVCF \
            -L "$REGION" \
            --native-pair-hmm-threads "$THREADS" \
            > "${LOG}/${id}.haplotypecaller.log" 2>&1

        if [[ ! -s "$sample_gvcf" ]]; then
            die "$id: HaplotypeCaller produced no GVCF"
        fi

        if ! gzip -t "$sample_gvcf" 2>/dev/null; then
            die "$id: HaplotypeCaller produced an invalid compressed GVCF"
        fi

        if ! bcftools view -h "$sample_gvcf" >/dev/null; then
            die "$id: HaplotypeCaller output is not a readable variant file"
        fi

        if [[ ! -s "$gvcf_index" ]]; then
            die "$id: HaplotypeCaller produced no GVCF index"
        fi

        n_records=$(bcftools view -H "$sample_gvcf" | wc -l)

        if (( n_records == 0 )); then
            die "$id: GVCF contains no records"
        fi

        log "$id: HaplotypeCaller produced ${n_records} GVCF records"
    done < <(tail -n +2 "$SHEET")
}
stage_merge() {
    local id _cond _rep _lt _r1 _r2
    local sample_gvcf combined_gvcf raw_vcf
    local sample_names expected_samples observed_samples n_variants
    local -a gvcf_args=()

    combined_gvcf="${COHORT}/cohort.g.vcf.gz"
    raw_vcf="${COHORT}/cohort.raw.vcf.gz"

    while IFS=, read -r id _cond _rep _lt _r1 _r2; do
        sample_gvcf="${GVCF}/${id}.g.vcf.gz"

        if [[ ! -s "$sample_gvcf" ]]; then
            die "$id: sample GVCF is missing or empty"
        fi

        if [[ ! -s "${sample_gvcf}.tbi" ]]; then
            die "$id: sample GVCF index is missing"
        fi

        if ! bcftools view -h "$sample_gvcf" >/dev/null; then
            die "$id: sample GVCF is not readable"
        fi

        gvcf_args+=( -V "$sample_gvcf" )
    done < <(tail -n +2 "$SHEET")

    if (( ${#gvcf_args[@]} == 0 )); then
        die "no sample GVCFs were found for joint genotyping"
    fi

    gatk CombineGVCFs \
        -R "$REF" \
        "${gvcf_args[@]}" \
        -O "$combined_gvcf" \
        -L "$REGION" \
        > "${LOG}/cohort.combinegvcfs.log" 2>&1

    if [[ ! -s "$combined_gvcf" ]]; then
        die "CombineGVCFs produced no combined GVCF"
    fi

    if ! gzip -t "$combined_gvcf" 2>/dev/null; then
        die "combined GVCF is not a valid compressed file"
    fi

    if [[ ! -s "${combined_gvcf}.tbi" ]]; then
        die "combined GVCF index is missing"
    fi

    log "individual GVCFs combined successfully"

    gatk GenotypeGVCFs \
        -R "$REF" \
        -V "$combined_gvcf" \
        -O "$raw_vcf" \
        -L "$REGION" \
        > "${LOG}/cohort.genotypegvcfs.log" 2>&1

    if [[ ! -s "$raw_vcf" ]]; then
        die "GenotypeGVCFs produced no cohort VCF"
    fi

    if ! gzip -t "$raw_vcf" 2>/dev/null; then
        die "raw cohort VCF is not a valid compressed file"
    fi

    if ! bcftools view -h "$raw_vcf" >/dev/null; then
        die "raw cohort VCF is not readable"
    fi

    if [[ ! -s "${raw_vcf}.tbi" ]]; then
        die "raw cohort VCF index is missing"
    fi

    sample_names=$(bcftools query -l "$raw_vcf")
    expected_samples=$(tail -n +2 "$SHEET" | awk 'NF {n++} END {print n+0}')
    observed_samples=$(printf '%s\n' "$sample_names" |
        awk 'NF {n++} END {print n+0}')

    if (( observed_samples != expected_samples )); then
        die "cohort VCF contains ${observed_samples} samples; expected ${expected_samples}"
    fi

    while IFS=, read -r id _cond _rep _lt _r1 _r2; do
        if ! grep -Fqx -- "$id" <<< "$sample_names"; then
            die "$id: sample is missing from the cohort VCF"
        fi
    done < <(tail -n +2 "$SHEET")

    n_variants=$(bcftools view -H "$raw_vcf" | wc -l | tr -d ' ')

    if (( n_variants == 0 )); then
        die "raw cohort VCF contains no variant records"
    fi

    log "joint genotyping completed with ${observed_samples} samples and ${n_variants} variant records"
}

stage_analyze() {
    local raw_vcf filtered_vcf
    local total_records pass_records filtered_records
    local sample_names expected_samples observed_samples

    raw_vcf="${COHORT}/cohort.raw.vcf.gz"
    filtered_vcf="${RES}/cohort.filtered.vcf.gz"

    if [[ ! -s "$raw_vcf" ]]; then
        die "raw cohort VCF is missing or empty"
    fi

    if [[ ! -s "${raw_vcf}.tbi" ]]; then
        die "raw cohort VCF index is missing"
    fi

    if ! bcftools view -h "$raw_vcf" >/dev/null; then
        die "raw cohort VCF is not readable"
    fi

    gatk VariantFiltration \
        -R "$REF" \
        -V "$raw_vcf" \
        -O "$filtered_vcf" \
        --filter-name "QD2" \
        --filter-expression "QD < 2.0" \
        --filter-name "QUAL30" \
        --filter-expression "QUAL < 30.0" \
        --filter-name "FS60" \
        --filter-expression "FS > 60.0" \
        --filter-name "SOR3" \
        --filter-expression "SOR > 3.0" \
        --filter-name "MQ40" \
        --filter-expression "MQ < 40.0" \
        --filter-name "MQRankSum-12.5" \
        --filter-expression "MQRankSum < -12.5" \
        --filter-name "ReadPosRankSum-8" \
        --filter-expression "ReadPosRankSum < -8.0" \
        > "${LOG}/cohort.variantfiltration.log" 2>&1

    if [[ ! -s "$filtered_vcf" ]]; then
        die "VariantFiltration produced no filtered VCF"
    fi

    if ! gzip -t "$filtered_vcf" 2>/dev/null; then
        die "filtered cohort VCF is not a valid compressed file"
    fi

    if ! bcftools view -h "$filtered_vcf" >/dev/null; then
        die "filtered cohort VCF is not readable"
    fi

    if [[ ! -s "${filtered_vcf}.tbi" ]]; then
        die "filtered cohort VCF index is missing"
    fi

    sample_names=$(bcftools query -l "$filtered_vcf")
    expected_samples=$(tail -n +2 "$SHEET" |
        awk 'NF {n++} END {print n+0}')
    observed_samples=$(printf '%s\n' "$sample_names" |
        awk 'NF {n++} END {print n+0}')

    if (( observed_samples != expected_samples )); then
        die "filtered VCF contains ${observed_samples} samples; expected ${expected_samples}"
    fi

    total_records=$(bcftools view -H "$filtered_vcf" |
        wc -l | tr -d ' ')
    pass_records=$(bcftools view -H -f PASS "$filtered_vcf" |
        wc -l | tr -d ' ')
    filtered_records=$(( total_records - pass_records ))

    if (( total_records == 0 )); then
        die "filtered cohort VCF contains no variant records"
    fi

    log "hard filtering completed: ${total_records} total, ${pass_records} PASS, ${filtered_records} flagged"
}

stage_qc_report() {
    local report data_directory

    report="${RES}/multiqc_report.html"
    data_directory="${RES}/multiqc_report_data"

    if [[ ! -d "$QC" ]]; then
        die "raw-QC directory is missing"
    fi

    if [[ ! -d "$LOG" ]]; then
        die "pipeline log directory is missing"
    fi

    multiqc \
        --force \
        --outdir "$RES" \
        "$QC" "$LOG" "$POST" \
        > "${LOG}/multiqc.log" 2>&1

    if [[ ! -s "$report" ]]; then
        die "MultiQC produced no HTML report"
    fi

    if [[ ! -d "$data_directory" ]]; then
        die "MultiQC produced no data directory"
    fi

    if [[ -z $(find "$data_directory" -type f -print -quit) ]]; then
        die "MultiQC data directory is empty"
    fi

    log "MultiQC report created at ${report}"
}

stage_publish() {
    bash "${HERE}/lib/write_manifest.sh" \
        "${RES}" "${SHEET}" "${REF}" "${REGION}"
}

n=0
for stage in "${STAGES[@]}"; do
    log "===== stage ${n}: ${stage} ====="
    "stage_${stage}"

    [[ "$stage" == "$LAST" ]] && break
    n=$(( n + 1 ))
done

log "done"
