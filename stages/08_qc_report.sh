# shellcheck shell=bash
# Shared variant-pipeline stage; sourced by both entry points.
stage_qc_report() {
    local report data_directory

    report="${RES}/multiqc_report.html"
    data_directory="${RES}/multiqc_report_data"

    if [[ ! -d "$QC" ]]; then
        die "raw-QC directory is missing"
    fi

    if [[ ! -d "$LOG" ]]; then
        die "pipeline log directory is missing"
    fi

    multiqc \
        --force \
        --outdir "$RES" \
        --filename "multiqc_report.html" \
        "$QC" "$LOG" "$POST" \
        > "${LOG}/multiqc.log" 2>&1

    if [[ ! -s "$report" ]]; then
        die "MultiQC produced no HTML report"
    fi

    if [[ ! -d "$data_directory" ]]; then
        die "MultiQC produced no data directory"
    fi

    if [[ -z $(find "$data_directory" -type f -print -quit) ]]; then
        die "MultiQC data directory is empty"
    fi

    log "MultiQC report created at ${report}"
}
