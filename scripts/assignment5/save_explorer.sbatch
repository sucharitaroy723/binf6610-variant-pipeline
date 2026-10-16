#!/bin/bash
#SBATCH --job-name=a5-preserve
#SBATCH --partition=courses
#SBATCH --account=binf6610.202710
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --output=slurm/%x-%j.out
# Submit from the repository with --dependency=afterok:<successful-head-job>.
set -euo pipefail
cd "${SLURM_SUBMIT_DIR}"
module load miniconda3/25.9.1
source activate /courses/BINF6610.202710/shared/env/binf6610
export TMPDIR=/scratch/${USER}/snakemake-tmp
mkdir -p "$TMPDIR"
test -s results/manifest.json
test -s cluster-run-nf/cohort.filtered.vcf.gz
mkdir -p cluster-run-smk evidence/assignment5
cp -a results/. cluster-run-smk/
cp slurm/variant-call-smk-*.out cluster-run-smk/
{
    bcftools view -H cluster-run-nf/cohort.filtered.vcf.gz | sha256sum
    bcftools view -H cluster-run-smk/cohort.filtered.vcf.gz | sha256sum
} > cluster-run-smk/records-sha256.txt
cat cluster-run-smk/records-sha256.txt
bcftools query -l cluster-run-smk/cohort.filtered.vcf.gz \
    | tee evidence/assignment5/explorer-vcf-samples.txt
bcftools --version > evidence/assignment5/records-bcftools-version.txt
