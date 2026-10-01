# shellcheck shell=bash
# Shared variant-pipeline stage; sourced by both entry points.
stage_analyze() {
    local raw_vcf filtered_vcf
    local total_records pass_records filtered_records
    local sample_names expected_samples observed_samples

    raw_vcf="${COHORT}/cohort.raw.vcf.gz"
    filtered_vcf="${RES}/cohort.filtered.tmp.vcf.gz"

    if [[ ! -s "$raw_vcf" ]]; then
        die "raw cohort VCF is missing or empty"
    fi

    if [[ ! -s "${raw_vcf}.tbi" ]]; then
        die "raw cohort VCF index is missing"
    fi

    if ! bcftools view -h "$raw_vcf" >/dev/null; then
        die "raw cohort VCF is not readable"
    fi

    gatk VariantFiltration \
        -R "$REF" \
        -V "$raw_vcf" \
        -O "$filtered_vcf" \
        --filter-name "QD2" \
        --filter-expression "QD < 2.0" \
        --filter-name "QUAL30" \
        --filter-expression "QUAL < 30.0" \
        --filter-name "FS60" \
        --filter-expression "FS > 60.0" \
        --filter-name "SOR3" \
        --filter-expression "SOR > 3.0" \
        --filter-name "MQ40" \
        --filter-expression "MQ < 40.0" \
        --filter-name "MQRankSum-12.5" \
        --filter-expression "MQRankSum < -12.5" \
        --filter-name "ReadPosRankSum-8" \
        --filter-expression "ReadPosRankSum < -8.0" \
        > "${LOG}/cohort.variantfiltration.log" 2>&1

    if [[ ! -s "$filtered_vcf" ]]; then
        die "VariantFiltration produced no filtered VCF"
    fi

    if ! gzip -t "$filtered_vcf" 2>/dev/null; then
        die "filtered cohort VCF is not a valid compressed file"
    fi

    if ! bcftools view -h "$filtered_vcf" >/dev/null; then
        die "filtered cohort VCF is not readable"
    fi

    if [[ ! -s "${filtered_vcf}.tbi" ]]; then
        die "filtered cohort VCF index is missing"
    fi

    sample_names=$(bcftools query -l "$filtered_vcf")
    expected_samples=$(cat "$ROWS_FILE" |
        awk 'NF {n++} END {print n+0}')
    observed_samples=$(printf '%s\n' "$sample_names" |
        awk 'NF {n++} END {print n+0}')

    if (( observed_samples != expected_samples )); then
        die "filtered VCF contains ${observed_samples} samples; expected ${expected_samples}"
    fi

    total_records=$(bcftools view -H "$filtered_vcf" |
        wc -l | tr -d ' ')
    pass_records=$(bcftools view -H -f PASS "$filtered_vcf" |
        wc -l | tr -d ' ')
    filtered_records=$(( total_records - pass_records ))

    if (( total_records == 0 )); then
        die "filtered cohort VCF contains no variant records"
    fi

    mv "$filtered_vcf" "${RES}/cohort.filtered.vcf.gz"
    mv "${filtered_vcf}.tbi" "${RES}/cohort.filtered.vcf.gz.tbi"
    log "hard filtering completed: ${total_records} total, ${pass_records} PASS, ${filtered_records} flagged"
}
