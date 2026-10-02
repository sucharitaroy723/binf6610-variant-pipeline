#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
RUN_STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
export RUN_STARTED
[[ $# -ge 3 && $# -le 4 ]] || { echo 'usage: run_sample.sh <samplesheet> <outdir> <sample_id> [last-stage]' >&2; exit 64; }
SHEET=$1 OUT=$2 SAMPLE=$3 LAST=${4:-quantify}
[[ -n "$SAMPLE" ]] || { echo 'sample_id must not be empty' >&2; exit 64; }
# An array task refuses merge/analyze/qc_report/publish: these need the cohort.
PER_SAMPLE=(validate qc_raw trim align postprocess quantify)
known=0
for stage in "${PER_SAMPLE[@]}"; do [[ $stage == "$LAST" ]] && known=1; done
(( known )) || { echo "run_sample.sh stops at quantify; '$LAST' needs the whole cohort" >&2; exit 64; }
source "${HERE}/lib/common.sh"
setup_dirs
for f in "${HERE}"/stages/*.sh; do source "$f"; done
for stage in "${PER_SAMPLE[@]}"; do
    run_stage "$stage"
    [[ $stage == "$LAST" ]] && break
done
log "$SAMPLE: done"
