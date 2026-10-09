#!/bin/bash
#SBATCH --job-name=nf-head
#SBATCH --account=binf6610.202710
#SBATCH --partition=courses
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=nf-head-%j.out
#SBATCH --export=NONE
set -euo pipefail

module load miniconda3/25.9.1
source activate /courses/BINF6610.202710/shared/env/binf6610
export NXF_APPTAINER_CACHEDIR=/scratch/${USER}/nxf-apptainer
export APPTAINER_CACHEDIR=/scratch/${USER}/apptainer-cache
# The head job submits additional jobs; export its activated environment to them.
export SLURM_EXPORT_ENV=ALL
# Build OCI images on node-local storage rather than an inherited home TMPDIR.
# /tmp exists on both the head node and every submitted task node.
export TMPDIR=/tmp
export APPTAINER_TMPDIR=/tmp
export NXF_WORK="/scratch/${USER}/binf6610-assignment4-work"
mkdir -p "$NXF_APPTAINER_CACHEDIR" "$APPTAINER_CACHEDIR" "$NXF_WORK"
echo "Container build temporary directory: $APPTAINER_TMPDIR"
echo "Nextflow work directory: $NXF_WORK"
df -h "$APPTAINER_TMPDIR" "$NXF_WORK"
cd "${SLURM_SUBMIT_DIR}"
# Optional first-run configuration: sbatch slurm/nextflow.sbatch docs/assignment4/failure4.config
config_args=()
if (($#)); then
    [[ $# == 1 && -f "$1" ]] || { echo 'expected one existing Nextflow config file' >&2; exit 64; }
    config_args=(-c "$1")
fi
nextflow run main.nf -profile explorer "${config_args[@]}" -resume -ansi-log false \
    --samplesheet /courses/BINF6610.202710/data/samplesheet-variant8.csv \
    --ref /courses/BINF6610.202710/data/refs/grch38-1000g/GRCh38_full_analysis_set_plus_decoy_hla.fa \
    --region chr20:1-10000000 --outdir results
