#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$HERE"
source conf/slurm.env
mkdir -p logs
N=$(awk 'NR>1 && NF {n++} END {print n+0}' "$SAMPLESHEET")
(( N > 0 )) || { echo 'empty samplesheet' >&2; exit 64; }
RANGE=${1:-1-$N}
ARRAY_ID=$(sbatch --parsable -p "$PARTITION" -A "$ACCOUNT" \
    --cpus-per-task="$PER_SAMPLE_CPUS" --mem="$PER_SAMPLE_MEM" --time="$PER_SAMPLE_TIME" \
    --array="$RANGE" 01_persample.sbatch "$RUN_ROOT")
ARRAY_ID=${ARRAY_ID%%;*}
echo "array $ARRAY_ID"
# Probes submit the sample job directly; a partial range must not run the cohort.
[[ $RANGE == "1-$N" ]] || { echo 'partial array: no cohort submitted'; exit 0; }
COHORT_ID=$(sbatch --parsable -p "$PARTITION" -A "$ACCOUNT" \
    --cpus-per-task="$COHORT_CPUS" --mem="$COHORT_MEM" --time="$COHORT_TIME" \
    --dependency=afterok:"$ARRAY_ID" --kill-on-invalid-dep=yes \
    02_cohort.sbatch "$RUN_ROOT")
echo "cohort ${COHORT_ID%%;*} (afterok:$ARRAY_ID)"
