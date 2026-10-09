#!/bin/bash -euo pipefail
bwa mem -t 1 -R '@RG\tID:smoke_03\tSM:smoke_03\tPL:ILLUMINA' \
    smoke.fa smoke_03_R1.trim.fastq.gz 2> smoke_03.bwa.log \
    | samtools view -b -o smoke_03.unsorted.bam -
samtools quickcheck smoke_03.unsorted.bam
n_records=smoke_03samtools view -c smoke_03.unsorted.bam)
test $n_records -gt 0
echo ": $n_records alignment records"
