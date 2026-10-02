#!/bin/bash
#SBATCH -A binf6610.202710
#SBATCH -p courses
#SBATCH -c 1 --mem=4G -t 06:00:00
#SBATCH -J a3-monitor
#SBATCH -o assignment3-monitor-%j.log
#SBATCH --export=NONE
set -euo pipefail
cd "$SLURM_SUBMIT_DIR"
source slurm/conf/slurm.env
module purge
module load "$MINICONDA_MODULE"
source activate "$CONDA_ENV"
echo "Assignment 3 monitor host=$(hostname) job=$SLURM_JOB_ID"
bash scripts/run_assignment3.sh --max-wait-hours 5 "$@"
