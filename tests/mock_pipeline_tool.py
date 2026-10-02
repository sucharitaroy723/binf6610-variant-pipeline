#!/usr/bin/env python3
"""Test-only output contracts for the external tools; no scientific computation."""
import gzip
import json
import os
from pathlib import Path
import shutil
import sys

tool = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TOOL_TRACE"], "a") as trace:
    trace.write(json.dumps([tool] + args) + "\n")


def option(flag):
    return args[args.index(flag) + 1]


def write(path, text="test output\n"):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(text)


def variant(path, samples):
    text = "##fileformat=VCFv4.2\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t" + "\t".join(samples) + "\n"
    text += "chr20\t10\t.\tA\tG\t60\tPASS\t.\tGT\t" + "\t".join("0/1" for _ in samples) + "\n"
    with gzip.open(path, "wt") as stream:
        stream.write(text)
    write(path + ".tbi")


def samples(path):
    with gzip.open(path, "rt") as stream:
        return next(line for line in stream if line.startswith("#CHROM")).strip().split("\t")[9:]


if "--version" in args or tool == "bwa" and not args:
    print(f"Version: {tool} 1.0.0")
elif tool == "fastqc":
    if "--version" in args:
        print("FastQC v1.0.0")
    else:
        base = Path(args[-1]).name.removesuffix(".fastq.gz")
        write(str(Path(option("-o")) / (base + "_fastqc.zip")))
elif tool == "fastp":
    shutil.copyfile(option("-i"), option("-o"))
    if "-I" in args:
        shutil.copyfile(option("-I"), option("-O"))
    write(option("-j"), "{}\n")
    write(option("-h"))
elif tool == "bwa":
    print("@HD\tVN:1.6")
elif tool == "samtools":
    if args[0] == "view" and "-c" in args:
        print(1)
    elif args[0] in {"view", "sort"}:
        if args[-1] == "-":
            sys.stdin.read()
        write(option("-o"))
    elif args[0] == "index":
        write(args[-1] + ".bai")
    elif args[0] == "flagstat":
        print("1 + 0 in total")
    elif args[0] == "quickcheck":
        if not Path(args[-1]).is_file():
            sys.exit(1)
elif tool == "gatk":
    stage = args[0]
    if stage == "MarkDuplicates":
        write(option("-O"))
        write(option("-M"))
    elif stage == "HaplotypeCaller":
        sample = Path(option("-I")).name.removesuffix(".dedup.bam")
        variant(option("-O"), [sample])
    elif stage == "CombineGVCFs":
        cohort = [name for i, arg in enumerate(args) if arg == "-V" for name in samples(args[i + 1])]
        variant(option("-O"), cohort)
    elif stage in {"GenotypeGVCFs", "VariantFiltration"}:
        variant(option("-O"), samples(option("-V")))
elif tool == "bcftools":
    with gzip.open(args[-1], "rt") as stream:
        text = stream.read()
    if args[0] == "query":
        print("\n".join(samples(args[-1])))
    elif "-h" in args:
        print("\n".join(line for line in text.splitlines() if line.startswith("#")))
    else:
        print("\n".join(line for line in text.splitlines() if not line.startswith("#")))
elif tool == "multiqc":
    out = Path(option("--outdir"))
    write(str(out / "multiqc_report.html"))
    write(str(out / "multiqc_report_data/test.txt"))
