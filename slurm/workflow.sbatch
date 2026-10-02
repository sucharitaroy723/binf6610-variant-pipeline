#!/bin/bash
#SBATCH --job-name=variant-workflow
#SBATCH --output=logs/workflow_%j.out
#SBATCH --export=NONE
set -euo pipefail
source "${SLURM_SUBMIT_DIR}/conf/slurm.env"
module purge
module load "$MINICONDA_MODULE"
source activate "$CONDA_ENV"
echo "workflow coordinator host=$(hostname) job=$SLURM_JOB_ID"
bash "${PIPELINE_DIR}/scripts/run_assignment2.sh" --coordinator "$@"
