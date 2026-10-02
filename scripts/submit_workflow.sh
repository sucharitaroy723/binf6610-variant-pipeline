#!/usr/bin/env bash
# Submit the lightweight workflow coordinator; analysis has separate allocations.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "${HERE}/slurm"
source conf/slurm.env
mkdir -p logs
JOB=$(sbatch --parsable -p "$PARTITION" -A "$ACCOUNT" --cpus-per-task=1 \
    --mem=1G --time=12:00:00 workflow.sbatch "$@")
JOB=${JOB%%;*}
echo "Workflow coordinator submitted: $JOB"
echo "Progress log: ${HERE}/slurm/logs/workflow_${JOB}.out"
echo "Queue: squeue -u \$USER"
