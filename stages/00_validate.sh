# shellcheck shell=bash
# Shared variant-pipeline stage; sourced by both entry points.
stage_validate() {
    local id _cond _rep lt r1 r2
    local problems=0
    local n1 n2 dupes

    if [[ ! -s "$SHEET" ]]; then
        die "samplesheet missing or empty: $SHEET"
    fi

    while IFS=, read -r id _cond _rep lt r1 r2; do
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
    done < <(cat "$ROWS_FILE")

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

    if [[ ! -s "$REF_DICT" ]]; then
        log "ERROR: GATK sequence dictionary missing for reference: $REF_DICT"
        problems=$(( problems + 1 ))
    fi

    if (( problems > 0 )); then
        die "validation failed with ${problems} problem(s)"
    fi

    log "validation passed"
}
