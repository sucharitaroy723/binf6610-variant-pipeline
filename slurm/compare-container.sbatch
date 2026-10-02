#!/bin/bash
#SBATCH -A binf6610.202710
#SBATCH -p courses
#SBATCH -c 2 --mem=4G -t 00:30:00
#SBATCH -J variant-record-compare
#SBATCH -o logs/a3-compare-%j.out
#SBATCH --export=NONE
set -euo pipefail
source "$SLURM_SUBMIT_DIR/conf/slurm.env"
cd "$PIPELINE_DIR"
{
    apptainer exec --cleanenv --bind "$PIPELINE_DIR,/courses/BINF6610.202710,/scratch/$USER" "$SIF" \
        bcftools view -H "$PIPELINE_DIR/cluster-run/cohort.filtered.vcf.gz" | sha256sum
    apptainer exec --cleanenv --bind "$PIPELINE_DIR,/courses/BINF6610.202710,/scratch/$USER" "$SIF" \
        bcftools view -H "$PIPELINE_DIR/cluster-run-container/cohort.filtered.vcf.gz" | sha256sum
} > cluster-run-container/records-sha256.txt
cat cluster-run-container/records-sha256.txt
