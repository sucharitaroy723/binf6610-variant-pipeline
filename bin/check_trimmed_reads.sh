#!/usr/bin/env bash
set -euo pipefail
previous=-1
for fastq in "$@"; do
    test -s "$fastq"
    gzip -t "$fastq"
    lines=$(gzip -dc "$fastq" | wc -l)
    ((lines > 0 && lines % 4 == 0)) || { echo "invalid trimmed FASTQ: $fastq" >&2; exit 65; }
    ((previous < 0 || previous == lines)) || { echo 'unequal trimmed read counts' >&2; exit 65; }
    previous=$lines
done
