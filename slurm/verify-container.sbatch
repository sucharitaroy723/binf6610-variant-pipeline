#!/bin/bash
#SBATCH -A binf6610.202710
#SBATCH -p courses
#SBATCH -c 2 --mem=4G -t 00:30:00
#SBATCH -J variant-image-verify
#SBATCH -o logs/a3-verify-%j.out
#SBATCH --export=NONE
set -euo pipefail
source "$SLURM_SUBMIT_DIR/conf/slurm.env"
cd "$PIPELINE_DIR"
module load "$MINICONDA_MODULE"
source activate "$CONDA_ENV"
mkdir -p cluster-run-container
bash tests/print_versions.sh > cluster-run-container/versions-conda.txt
apptainer exec --cleanenv --bind "$PIPELINE_DIR,/courses/BINF6610.202710,/scratch/$USER" "$SIF" \
    bash "$PIPELINE_DIR/tests/print_versions.sh" > cluster-run-container/versions-image.txt
python3 scripts/assignment3/support.py check-versions cluster-run-container/versions-image.txt
diff -u cluster-run-container/versions-conda.txt cluster-run-container/versions-image.txt
