#!/bin/bash
#SBATCH --job-name=variant-cohort
#SBATCH --output=logs/cohort_%j.out
#SBATCH --export=NONE
set -euo pipefail
source "${SLURM_SUBMIT_DIR}/conf/slurm.env"
RUN_ROOT=${1:-$RUN_ROOT}
module purge
module load "$MINICONDA_MODULE"
source activate "$CONDA_ENV"
export THREADS="${SLURM_CPUS_PER_TASK}"
export REF REGION
export TMPDIR="/tmp/${SLURM_JOB_ID}"
mkdir -p "$TMPDIR"
cleanup() {
    local status=$? cg
    trap - EXIT
    cg="/sys/fs/cgroup$(awk -F: '/^0::/{print $3}' /proc/self/cgroup)"
    if [[ -r "$cg/memory.peak" ]]; then echo "MEMORY_PEAK_BYTES=$(cat "$cg/memory.peak")"; fi
    rm -rf -- "$TMPDIR"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 143' TERM
export JAVA_TOOL_OPTIONS="-Djava.io.tmpdir=${TMPDIR} -XX:ActiveProcessorCount=${THREADS}"
echo "cohort host=$(hostname) cpus=$THREADS run=$RUN_ROOT"
bash "${PIPELINE_DIR}/run_pipeline.sh" "$SAMPLESHEET" "$RUN_ROOT" publish
