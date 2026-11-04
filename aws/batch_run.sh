#!/usr/bin/env bash
set -euo pipefail

: "${DATA:?Set DATA to the input S3 prefix}"
: "${RESULTS:?Set RESULTS to the output S3 prefix}"
REF_NAME=${REF_NAME:-smoke.fa}
job=${AWS_BATCH_JOB_ID:-local}
work=$(mktemp -d /tmp/run.XXXXXX)

mkdir -p "${work}/data"
printf 'Downloading inputs from %s/ to %s/data/\n' "${DATA%/}" "${work}"
aws s3 cp --recursive --no-progress "${DATA%/}/" "${work}/data/"

cd "${work}/data"
printf 'Executing pipeline with reference %s\n' "${work}/data/${REF_NAME}"
REF="${work}/data/${REF_NAME}" bash /pipeline/run_pipeline.sh \
    samplesheet.csv "${work}/out"

printf 'Uploading results from %s/out/results/ to %s/%s/\n' "${work}" "${RESULTS%/}" "${job}"
aws s3 cp --recursive --no-progress "${work}/out/results/" "${RESULTS%/}/${job}/"
