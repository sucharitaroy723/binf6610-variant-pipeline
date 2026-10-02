#!/bin/bash
#SBATCH --job-name=variant-persample
#SBATCH --array=1-8
#SBATCH --output=logs/persample_%A_%a.out
#SBATCH --export=NONE
set -euo pipefail
source "${SLURM_SUBMIT_DIR}/conf/slurm.env"
RUN_ROOT=${1:-$RUN_ROOT}
FAIL_TASK=${2:-0}
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
SAMPLE=$(awk -F, -v n="${SLURM_ARRAY_TASK_ID}" 'NR == n + 1 {sub(/\r$/, ""); print $1}' "$SAMPLESHEET")
[[ -n "${SAMPLE}" ]] || { echo "task ${SLURM_ARRAY_TASK_ID}: no row ${SLURM_ARRAY_TASK_ID} in ${SAMPLESHEET}" >&2; exit 64; }
[[ $SLURM_ARRAY_TASK_ID != "$FAIL_TASK" ]] || { echo 'deliberate task failure: exit 1' >&2; exit 1; }
echo "task=$SLURM_ARRAY_TASK_ID sample=$SAMPLE host=$(hostname) cpus=$THREADS run=$RUN_ROOT"
bash "${PIPELINE_DIR}/run_sample.sh" "$SAMPLESHEET" "$RUN_ROOT" "$SAMPLE" quantify
