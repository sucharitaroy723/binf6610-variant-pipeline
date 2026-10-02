# shellcheck shell=bash
# Shared variant-pipeline stage; sourced by both entry points.
stage_postprocess() {
    local id _cond _rep _lt _r1 _r2
    local sorted_bam final_bam metrics index_file n_records

    while IFS=, read -r id _cond _rep _lt _r1 _r2; do
        sorted_bam="${POST}/${id}.sorted.tmp.bam"
        final_bam="${POST}/${id}.dedup.tmp.bam"
        metrics="${LOG}/${id}.duplicate_metrics.txt"
        index_file="${final_bam}.bai"

        samtools sort \
            -T "${TMPDIR}/sort.${id}" \
            -@ "$SORT_THREADS" \
            -o "$sorted_bam" \
            "${ALN}/${id}.unsorted.bam" \
            2> "${LOG}/${id}.samtools_sort.log"

        if [[ ! -s "$sorted_bam" ]]; then
            die "$id: sorting produced no BAM file"
        fi

        if ! samtools quickcheck "$sorted_bam"; then
            die "$id: sorted BAM is invalid or truncated"
        fi

        gatk MarkDuplicates \
            -I "$sorted_bam" \
            -O "$final_bam" \
            -M "$metrics" \
            --CREATE_INDEX false \
            > "${LOG}/${id}.markduplicates.log" 2>&1

        if [[ ! -s "$final_bam" ]]; then
            die "$id: duplicate marking produced no BAM file"
        fi

        if ! samtools quickcheck "$final_bam"; then
            die "$id: duplicate-marked BAM is invalid or truncated"
        fi

        if [[ ! -s "$metrics" ]]; then
            die "$id: duplicate marking produced no metrics"
        fi

        samtools index "$final_bam"

        if [[ ! -s "$index_file" ]]; then
            die "$id: BAM indexing produced no index"
        fi

        samtools flagstat "$final_bam" > "${LOG}/${id}.flagstat.txt"

        if [[ ! -s "${LOG}/${id}.flagstat.txt" ]]; then
            die "$id: samtools flagstat produced no report"
        fi

        n_records=$(samtools view -c "$final_bam")

        if (( n_records == 0 )); then
            die "$id: duplicate-marked BAM contains no records"
        fi

        mv "$sorted_bam" "${POST}/${id}.sorted.bam"
        mv "$final_bam" "${POST}/${id}.dedup.bam"
        mv "$index_file" "${POST}/${id}.dedup.bam.bai"
        log "$id: postprocessing completed with ${n_records} records"
    done < <(cat "$ROWS_FILE")
}
