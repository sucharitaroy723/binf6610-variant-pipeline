# shellcheck shell=bash
# Shared variant-pipeline stage; sourced by both entry points.
stage_trim() {
    local id _cond _rep lt r1 r2
    local n1 n2

    while IFS=, read -r id _cond _rep lt r1 r2; do
        if [[ "$lt" == "paired" ]]; then
            fastp \
                -i "$r1" \
                -I "$r2" \
                -o "${TRIM}/${id}_R1.fastq.gz" \
                -O "${TRIM}/${id}_R2.fastq.gz" \
                -j "${LOG}/${id}.fastp.json" \
                -h "${LOG}/${id}.fastp.html" \
                --thread "$THREADS" \
                2> "${LOG}/${id}.fastp.log"
        else
            fastp \
                -i "$r1" \
                -o "${TRIM}/${id}_R1.fastq.gz" \
                -j "${LOG}/${id}.fastp.json" \
                -h "${LOG}/${id}.fastp.html" \
                --thread "$THREADS" \
                2> "${LOG}/${id}.fastp.log"
        fi

        if [[ ! -s "${TRIM}/${id}_R1.fastq.gz" ]]; then
            die "$id: fastp produced no R1 output"
        fi

        if ! gzip -t "${TRIM}/${id}_R1.fastq.gz" 2>/dev/null; then
            die "$id: trimmed R1 is not a valid gzip file"
        fi

        n1=$(gzip -dc "${TRIM}/${id}_R1.fastq.gz" | wc -l)

        if (( n1 == 0 || n1 % 4 != 0 )); then
            die "$id: trimmed R1 does not contain complete FASTQ records"
        fi

        if [[ "$lt" == "paired" ]]; then
            if [[ ! -s "${TRIM}/${id}_R2.fastq.gz" ]]; then
                die "$id: fastp produced no R2 output"
            fi

            if ! gzip -t "${TRIM}/${id}_R2.fastq.gz" 2>/dev/null; then
                die "$id: trimmed R2 is not a valid gzip file"
            fi

            n2=$(gzip -dc "${TRIM}/${id}_R2.fastq.gz" | wc -l)

            if (( n2 == 0 || n2 % 4 != 0 )); then
                die "$id: trimmed R2 does not contain complete FASTQ records"
            fi

            if (( n1 != n2 )); then
                die "$id: trimmed R1 and R2 contain different read counts"
            fi
        fi

        log "$id: trimming completed with $(( n1 / 4 )) reads"
    done < <(cat "$ROWS_FILE")
}
