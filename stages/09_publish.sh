# shellcheck shell=bash
# Shared variant-pipeline stage; sourced by both entry points.
stage_publish() {
    PIPELINE_NAME=variant-call bash "${HERE}/lib/write_manifest.sh" \
        "${RES}" "${SHEET}" "${REF}" "${REGION}"
}
