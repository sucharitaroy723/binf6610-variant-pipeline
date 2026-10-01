# shellcheck shell=bash
# Shared variant-pipeline stage; sourced by both entry points.
stage_merge() {
    local id _cond _rep _lt _r1 _r2
    local sample_gvcf combined_gvcf raw_vcf
    local sample_names expected_samples observed_samples n_variants
    local -a gvcf_args=()

    combined_gvcf="${COHORT}/cohort.tmp.g.vcf.gz"
    raw_vcf="${COHORT}/cohort.raw.tmp.vcf.gz"

    while IFS=, read -r id _cond _rep _lt _r1 _r2; do
        sample_gvcf="${GVCF}/${id}.g.vcf.gz"

        if [[ ! -s "$sample_gvcf" ]]; then
            die "$id: sample GVCF is missing or empty"
        fi

        if [[ ! -s "${sample_gvcf}.tbi" ]]; then
            die "$id: sample GVCF index is missing"
        fi

        if ! bcftools view -h "$sample_gvcf" >/dev/null; then
            die "$id: sample GVCF is not readable"
        fi

        gvcf_args+=( -V "$sample_gvcf" )
    done < <(cat "$ROWS_FILE")

    if (( ${#gvcf_args[@]} == 0 )); then
        die "no sample GVCFs were found for joint genotyping"
    fi

    gatk CombineGVCFs \
        -R "$REF" \
        "${gvcf_args[@]}" \
        -O "$combined_gvcf" \
        -L "$REGION" \
        > "${LOG}/cohort.combinegvcfs.log" 2>&1

    if [[ ! -s "$combined_gvcf" ]]; then
        die "CombineGVCFs produced no combined GVCF"
    fi

    if ! gzip -t "$combined_gvcf" 2>/dev/null; then
        die "combined GVCF is not a valid compressed file"
    fi

    if [[ ! -s "${combined_gvcf}.tbi" ]]; then
        die "combined GVCF index is missing"
    fi

    log "individual GVCFs combined successfully"

    gatk GenotypeGVCFs \
        -R "$REF" \
        -V "$combined_gvcf" \
        -O "$raw_vcf" \
        -L "$REGION" \
        > "${LOG}/cohort.genotypegvcfs.log" 2>&1

    if [[ ! -s "$raw_vcf" ]]; then
        die "GenotypeGVCFs produced no cohort VCF"
    fi

    if ! gzip -t "$raw_vcf" 2>/dev/null; then
        die "raw cohort VCF is not a valid compressed file"
    fi

    if ! bcftools view -h "$raw_vcf" >/dev/null; then
        die "raw cohort VCF is not readable"
    fi

    if [[ ! -s "${raw_vcf}.tbi" ]]; then
        die "raw cohort VCF index is missing"
    fi

    sample_names=$(bcftools query -l "$raw_vcf")
    expected_samples=$(cat "$ROWS_FILE" | awk 'NF {n++} END {print n+0}')
    observed_samples=$(printf '%s\n' "$sample_names" |
        awk 'NF {n++} END {print n+0}')

    if (( observed_samples != expected_samples )); then
        die "cohort VCF contains ${observed_samples} samples; expected ${expected_samples}"
    fi

    while IFS=, read -r id _cond _rep _lt _r1 _r2; do
        if ! grep -Fqx -- "$id" <<< "$sample_names"; then
            die "$id: sample is missing from the cohort VCF"
        fi
    done < <(cat "$ROWS_FILE")

    n_variants=$(bcftools view -H "$raw_vcf" | wc -l | tr -d ' ')

    if (( n_variants == 0 )); then
        die "raw cohort VCF contains no variant records"
    fi

    mv "$combined_gvcf" "${COHORT}/cohort.g.vcf.gz"
    mv "${combined_gvcf}.tbi" "${COHORT}/cohort.g.vcf.gz.tbi"
    mv "$raw_vcf" "${COHORT}/cohort.raw.vcf.gz"
    mv "${raw_vcf}.tbi" "${COHORT}/cohort.raw.vcf.gz.tbi"
    log "joint genotyping completed with ${observed_samples} samples and ${n_variants} variant records"
}
