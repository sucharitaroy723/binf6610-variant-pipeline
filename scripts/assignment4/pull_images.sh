#!/usr/bin/env bash
set -euo pipefail
images=(
    community.wave.seqera.io/library/coreutils_gawk_gzip:7c58ccc2f9ca6bcc
    quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0
    community.wave.seqera.io/library/fastp:1.3.7--075357a9d5c82494
    community.wave.seqera.io/library/bwa_samtools:22527ddb3cc80fb3
    community.wave.seqera.io/library/gatk4_samtools_bcftools:1adede7d418fb46b
    quay.io/biocontainers/multiqc:1.35--pyhdfd78af_2
)
docker info > /dev/null
for image in "${images[@]}"; do
    docker pull --platform linux/amd64 "$image"
done
