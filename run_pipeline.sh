#!/usr/bin/env bash
set -euo pipefail

SHEET=${1:?usage: run_pipeline.sh <samplesheet.csv> <outdir> [last-stage]}
OUT=${2:?usage: run_pipeline.sh <samplesheet.csv> <outdir> [last-stage]}
LAST=${3:-publish}

REF_DIR=${REF_DIR:-data/refs/grch38}
REF=${REF:-${REF_DIR}/GRCh38.fa}
THREADS=${THREADS:-4}
REGION=${REGION:-chr20:1-10000000}

QC="${OUT}/qc_raw"
TRIM="${OUT}/trim"
ALN="${OUT}/align"
POST="${OUT}/postprocess"
GVCF="${OUT}/gvcf"
COHORT="${OUT}/cohort"
RES="${OUT}/results"
LOG="${OUT}/logs"

mkdir -p "$QC" "$TRIM" "$ALN" "$POST" "$GVCF" "$COHORT" "$RES" "$LOG"

log() {
    printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 65
}

STAGES=(
    validate
    qc_raw
    trim
    align
    postprocess
    quantify
    merge
    analyze
    qc_report
    publish
)

known=0
for stage in "${STAGES[@]}"; do
    [[ "$stage" == "$LAST" ]] && known=1
done
(( known )) || die "unknown stage: ${LAST}"

stage_validate() {
    local id cond rep lt r1 r2
    local problems=0
    local n1 n2 dupes

    if [[ ! -s "$SHEET" ]]; then
        die "samplesheet missing or empty: $SHEET"
    fi

    while IFS=, read -r id cond rep lt r1 r2; do
        if [[ -z "$id" ]]; then
            log "ERROR: a samplesheet row has no sample_id"
            problems=$(( problems + 1 ))
            continue
        fi

        if [[ "$lt" != "single" && "$lt" != "paired" ]]; then
            log "ERROR: $id: invalid library_type: $lt"
            problems=$(( problems + 1 ))
        fi

        if [[ ! -s "$r1" ]]; then
            log "ERROR: $id: R1 missing or empty: $r1"
            problems=$(( problems + 1 ))
        else
            if ! gzip -t "$r1" 2>/dev/null; then
                log "ERROR: $id: R1 is not a valid complete gzip file: $r1"
                problems=$(( problems + 1 ))
            else
                n1=$(gzip -dc "$r1" | wc -l)
                if (( n1 % 4 != 0 )); then
                    log "ERROR: $id: R1 has $n1 lines, not complete FASTQ records"
                    problems=$(( problems + 1 ))
                fi
            fi
        fi

        if [[ "$lt" == "paired" ]]; then
            if [[ -z "$r2" ]]; then
                log "ERROR: $id: paired library has an empty r2_fastq"
                problems=$(( problems + 1 ))
            elif [[ ! -s "$r2" ]]; then
                log "ERROR: $id: R2 missing or empty: $r2"
                problems=$(( problems + 1 ))
            elif ! gzip -t "$r2" 2>/dev/null; then
                log "ERROR: $id: R2 is not a valid complete gzip file: $r2"
                problems=$(( problems + 1 ))
            elif [[ -s "$r1" ]] && gzip -t "$r1" 2>/dev/null; then
                n1=$(gzip -dc "$r1" | wc -l)
                n2=$(gzip -dc "$r2" | wc -l)

                if (( n2 % 4 != 0 )); then
                    log "ERROR: $id: R2 has $n2 lines, not complete FASTQ records"
                    problems=$(( problems + 1 ))
                fi

                if (( n1 != n2 )); then
                    log "ERROR: $id: R1 has $(( n1 / 4 )) reads but R2 has $(( n2 / 4 ))"
                    problems=$(( problems + 1 ))
                fi
            fi
        elif [[ "$lt" == "single" && -n "$r2" ]]; then
            log "ERROR: $id: single-end library has an unexpected r2_fastq"
            problems=$(( problems + 1 ))
        fi
    done < <(tail -n +2 "$SHEET")

    dupes=$(awk -F, 'NR > 1 {print $1}' "$SHEET" | sort | uniq -d)
    if [[ -n "$dupes" ]]; then
        while IFS= read -r duplicate; do
            log "ERROR: duplicate sample_id: $duplicate"
            problems=$(( problems + 1 ))
        done <<< "$dupes"
    fi

    if [[ ! -s "$REF" ]]; then
        log "ERROR: reference FASTA missing or empty: $REF"
        problems=$(( problems + 1 ))
    fi

    if [[ ! -s "${REF}.bwt" ]]; then
        log "ERROR: BWA reference index missing for: $REF"
        problems=$(( problems + 1 ))
    fi

    if [[ ! -s "${REF}.fai" ]]; then
        log "ERROR: FASTA index missing for reference: $REF"
        problems=$(( problems + 1 ))
    fi

    if (( problems > 0 )); then
        die "validation failed with ${problems} problem(s)"
    fi

    log "validation passed"
}

stage_qc_raw() {
    die "stage qc_raw has not been implemented yet"
}

stage_trim() {
    die "stage trim has not been implemented yet"
}

stage_align() {
    die "stage align has not been implemented yet"
}

stage_postprocess() {
    die "stage postprocess has not been implemented yet"
}

stage_quantify() {
    die "stage quantify has not been implemented yet"
}

stage_merge() {
    die "stage merge has not been implemented yet"
}

stage_analyze() {
    die "stage analyze has not been implemented yet"
}

stage_qc_report() {
    die "stage qc_report has not been implemented yet"
}

stage_publish() {
    die "stage publish has not been implemented yet"
}

n=0
for stage in "${STAGES[@]}"; do
    log "===== stage ${n}: ${stage} ====="
    "stage_${stage}"

    [[ "$stage" == "$LAST" ]] && break
    n=$(( n + 1 ))
done

log "done"
