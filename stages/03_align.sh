# shellcheck shell=bash
# Shared variant-pipeline stage; sourced by both entry points.
stage_align() {
    local id _cond _rep lt _r1 _r2
    local read_group n_records

    while IFS=, read -r id _cond _rep lt _r1 _r2; do
        read_group="@RG\tID:${id}\tSM:${id}\tPL:ILLUMINA"

        if [[ "$lt" == "paired" ]]; then
            bwa mem \
                -t "$ALIGN_THREADS" \
                -R "$read_group" \
                "$REF" \
                "${TRIM}/${id}_R1.fastq.gz" \
                "${TRIM}/${id}_R2.fastq.gz" \
                2> "${LOG}/${id}.bwa.log"
        else
            bwa mem \
                -t "$ALIGN_THREADS" \
                -R "$read_group" \
                "$REF" \
                "${TRIM}/${id}_R1.fastq.gz" \
                2> "${LOG}/${id}.bwa.log"
        fi | samtools view \
                -@ "$VIEW_THREADS" \
                -b \
                -o "${ALN}/${id}.unsorted.tmp.bam" \
                - \
                2>> "${LOG}/${id}.bwa.log"

        if [[ ! -s "${ALN}/${id}.unsorted.tmp.bam" ]]; then
            die "$id: alignment produced no BAM file"
        fi

        if ! samtools quickcheck "${ALN}/${id}.unsorted.tmp.bam"; then
            die "$id: alignment produced an invalid or truncated BAM"
        fi

        n_records=$(samtools view -c "${ALN}/${id}.unsorted.tmp.bam")

        if (( n_records == 0 )); then
            die "$id: BAM contains no alignment records"
        fi

        mv "${ALN}/${id}.unsorted.tmp.bam" "${ALN}/${id}.unsorted.bam"
        log "$id: alignment produced ${n_records} records"
    done < <(cat "$ROWS_FILE")
}
