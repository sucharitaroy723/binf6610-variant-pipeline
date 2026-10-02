# shellcheck shell=bash
# Shared variant-pipeline stage; sourced by both entry points.
stage_quantify() {
    local id _cond _rep _lt _r1 _r2
    local input_bam sample_gvcf gvcf_index n_records

    while IFS=, read -r id _cond _rep _lt _r1 _r2; do
        input_bam="${POST}/${id}.dedup.bam"
        sample_gvcf="${GVCF}/${id}.tmp.g.vcf.gz"
        gvcf_index="${sample_gvcf}.tbi"

        gatk HaplotypeCaller \
            -R "$REF" \
            -I "$input_bam" \
            -O "$sample_gvcf" \
            -ERC GVCF \
            -L "$REGION" \
            --native-pair-hmm-threads "$THREADS" \
            > "${LOG}/${id}.haplotypecaller.log" 2>&1

        if [[ ! -s "$sample_gvcf" ]]; then
            die "$id: HaplotypeCaller produced no GVCF"
        fi

        if ! gzip -t "$sample_gvcf" 2>/dev/null; then
            die "$id: HaplotypeCaller produced an invalid compressed GVCF"
        fi

        if ! bcftools view -h "$sample_gvcf" >/dev/null; then
            die "$id: HaplotypeCaller output is not a readable variant file"
        fi

        if [[ ! -s "$gvcf_index" ]]; then
            die "$id: HaplotypeCaller produced no GVCF index"
        fi

        n_records=$(bcftools view -H "$sample_gvcf" | wc -l)

        if (( n_records == 0 )); then
            die "$id: GVCF contains no records"
        fi

        mv "$sample_gvcf" "${GVCF}/${id}.g.vcf.gz"
        mv "$gvcf_index" "${GVCF}/${id}.g.vcf.gz.tbi"
        log "$id: HaplotypeCaller produced ${n_records} GVCF records"
    done < <(cat "$ROWS_FILE")
}
