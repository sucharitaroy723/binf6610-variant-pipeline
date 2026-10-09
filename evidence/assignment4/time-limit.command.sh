#!/bin/bash -euo pipefail
mkdir -p tmp
gatk --java-options '-Xmx11468m -Djava.io.tmpdir=tmp' HaplotypeCaller \
    -R GRCh38_full_analysis_set_plus_decoy_hla.fa -I NA07357.dedup.bam -O NA07357.g.vcf.gz -ERC GVCF -L 'chr20:1-10000000' \
    --native-pair-hmm-threads 8
gzip -t NA07357.g.vcf.gz
bcftools view -h NA07357.g.vcf.gz > /dev/null
test -s NA07357.g.vcf.gz.tbi
