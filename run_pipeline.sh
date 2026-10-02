#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
RUN_STARTED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
export RUN_STARTED

usage() {
    printf 'usage: run_pipeline.sh <samplesheet.csv> <outdir> [last-stage]\n' >&2
    printf '   or: run_pipeline.sh --samplesheet FILE --outdir DIR [--to STAGE]\n' >&2
}

SHEET=''
OUT=''
LAST='publish'

if [[ ${1:-} == --* ]]; then
    while (( $# > 0 )); do
        case "$1" in
            --samplesheet)
                (( $# >= 2 )) || { usage; exit 64; }
                SHEET=$2
                shift 2
                ;;
            --samplesheet=*)
                SHEET=${1#*=}
                shift
                ;;
            --outdir)
                (( $# >= 2 )) || { usage; exit 64; }
                OUT=$2
                shift 2
                ;;
            --outdir=*)
                OUT=${1#*=}
                shift
                ;;
            --to)
                (( $# >= 2 )) || { usage; exit 64; }
                LAST=$2
                shift 2
                ;;
            --to=*)
                LAST=${1#*=}
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                printf 'error: unknown argument: %s\n' "$1" >&2
                usage
                exit 64
                ;;
        esac
    done
else
    if (( $# < 2 || $# > 3 )); then
        usage
        exit 64
    fi

    SHEET=$1
    OUT=$2
    LAST=${3:-publish}
fi

if [[ -z "$SHEET" || -z "$OUT" ]]; then
    usage
    exit 64
fi

SAMPLE=""
source "${HERE}/lib/common.sh"
setup_dirs
for f in "${HERE}"/stages/*.sh; do source "$f"; done
STAGES=(validate qc_raw trim align postprocess quantify merge analyze qc_report publish)
known=0
for stage in "${STAGES[@]}"; do [[ "$stage" == "$LAST" ]] && known=1; done
(( known )) || die "unknown stage: ${LAST}"
for stage in "${STAGES[@]}"; do
    run_stage "$stage"
    [[ "$stage" == "$LAST" ]] && break
done
log "done"
