#!/bin/bash
#SBATCH -A binf6610.202710
#SBATCH -p courses
#SBATCH -c 2 --mem=8G -t 00:30:00
#SBATCH -J variant-arm64-probe
#SBATCH -o logs/a3-architecture-%j.out
#SBATCH --export=NONE
set -euo pipefail
source "$SLURM_SUBMIT_DIR/conf/slurm.env"
export APPTAINER_CACHEDIR=/scratch/$USER/apptainer-cache
ARM="/scratch/$USER/containers/arm-$SLURM_JOB_ID.sif"
mkdir -p "$APPTAINER_CACHEDIR" "$(dirname -- "$ARM")"
echo 'COMMAND: apptainer pull --arch arm64 arm.sif docker://ubuntu:24.04'
set +e
apptainer pull --arch arm64 "$ARM" docker://ubuntu:24.04
PULL_STATUS=$?
echo "ARM64_PULL_EXIT=$PULL_STATUS"
if (( PULL_STATUS == 0 )); then
    echo 'COMMAND: apptainer exec --cleanenv arm.sif /bin/uname -m'
    apptainer exec --cleanenv "$ARM" /bin/uname -m
    echo "ARM64_EXEC_EXIT=$?"
else
    echo 'ARM64_EXEC_SKIPPED=pull did not create an image'
fi
set -e
