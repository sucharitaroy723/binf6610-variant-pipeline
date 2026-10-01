# shellcheck shell=bash
# Shared variant-pipeline stage; sourced by both entry points.
stage_qc_raw() {
    local id _cond _rep lt r1 r2 base

    while IFS=, read -r id _cond _rep lt r1 r2; do
        fastqc -q -o "$QC" "$r1" > "${LOG}/${id}.fastqc.log" 2>&1

        if [[ "$lt" == "paired" ]]; then
            fastqc -q -o "$QC" "$r2" >> "${LOG}/${id}.fastqc.log" 2>&1
        fi

        base=$(basename "$r1" .fastq.gz)
        if [[ ! -s "${QC}/${base}_fastqc.zip" ]]; then
            die "$id: FastQC produced no R1 report"
        fi

        if [[ "$lt" == "paired" ]]; then
            base=$(basename "$r2" .fastq.gz)
            if [[ ! -s "${QC}/${base}_fastqc.zip" ]]; then
                die "$id: FastQC produced no R2 report"
            fi
        fi

        log "$id: raw-read QC completed"
    done < <(cat "$ROWS_FILE")
}
