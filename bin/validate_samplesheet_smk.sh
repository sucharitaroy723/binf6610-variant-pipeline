#!/usr/bin/env bash
# Stage 0: validate original paths relative to the samplesheet.
set -euo pipefail
SHEET=${1:?samplesheet required}
REF=${2:?reference required}
REF_DICT=${3:-${REF%.*}.dict}
SHEET_DIR=$(cd "$(dirname "$SHEET")" && pwd)
log() { printf '[validate] %s\n' "$*" >&2; }
die() { log "$*"; exit 65; }
[[ -s "$SHEET" ]] || die "samplesheet missing or empty: $SHEET"
ROWS_FILE=$(mktemp)
trap 'rm -f "$ROWS_FILE"' EXIT
awk -F, '
    NR==1 {
        sub(/\r$/, "")
        n=split("sample_id condition replicate library_type r1_fastq r2_fastq", need, " ")
        for(i=1;i<=NF;i++) col[$i]=i
        for(i=1;i<=n;i++) if(!(need[i] in col)) {
            print "missing samplesheet column: " need[i] > "/dev/stderr"; exit 65
        }
        next
    }
    /^[[:space:]]*$/ {next}
    {
        sub(/\r$/, "")
        id=$col["sample_id"]
        if(id !~ /^[A-Za-z0-9_.-]+$/ || id=="." || id==".." || seen[id]++) {
            print "invalid or duplicate sample_id: " id > "/dev/stderr"; exit 65
        }
        print id "," $col["condition"] "," $col["replicate"] "," $col["library_type"] "," $col["r1_fastq"] "," $col["r2_fastq"]
    }
' "$SHEET" > "$ROWS_FILE"
[[ -s "$ROWS_FILE" ]] || die 'samplesheet has no samples'
problems=0
# Normalize only the paths; preserve the original validation checks.
while IFS=, read -r id _condition _replicate lt r1 r2; do
    [[ -z "$r1" || "$r1" == /* ]] || r1="$SHEET_DIR/$r1"
    [[ -z "$r2" || "$r2" == /* ]] || r2="$SHEET_DIR/$r2"
    if [[ "$lt" != single && "$lt" != paired ]]; then
        log "$id: invalid library_type: $lt"; problems=$((problems + 1))
    fi
    if [[ "$lt" == single && -n "$r2" ]]; then
        log "$id: single-end sample has R2"; problems=$((problems + 1))
    fi
    n1=0; n2=0
    if [[ ! -s "$r1" ]] || ! gzip -t "$r1" 2>/dev/null; then
        log "$id: R1 missing, empty or invalid gzip: $r1"; problems=$((problems + 1))
    else
        n1=$(gzip -dc "$r1" | wc -l)
        if ((n1 == 0 || n1 % 4 != 0)); then
            log "$id: R1 has $n1 lines, not complete nonempty FASTQ records"; problems=$((problems + 1))
        fi
    fi
    if [[ "$lt" == paired ]]; then
        if [[ -z "$r2" || ! -s "$r2" ]] || ! gzip -t "$r2" 2>/dev/null; then
            log "$id: R2 missing, empty or invalid gzip: $r2"; problems=$((problems + 1))
        else
            n2=$(gzip -dc "$r2" | wc -l)
            if ((n2 == 0 || n2 % 4 != 0 || n1 != n2)); then
                log "$id: incomplete or unequal paired FASTQs ($n1/$n2 lines)"; problems=$((problems + 1))
            fi
        fi
    fi
done < "$ROWS_FILE"
for required in "$REF" "${REF}.fai" "${REF}.amb" "${REF}.ann" "${REF}.bwt" "${REF}.pac" "${REF}.sa" "$REF_DICT"; do
    if [[ ! -s "$required" ]]; then
        log "reference or index missing/empty: $required"; problems=$((problems + 1))
    fi
done
((problems == 0)) || die "validation failed with $problems problem(s)"
log 'validation passed'
