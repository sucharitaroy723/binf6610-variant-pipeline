#!/usr/bin/env bash
set -euo pipefail
sheet=${1:?samplesheet required}
vcf=${2:?VCF required}
expected=$(awk -F, 'NR==1 {for(i=1;i<=NF;i++) if($i=="sample_id") c=i; next} NF {print $c}' "$sheet" | LC_ALL=C sort)
observed=$(bcftools query -l "$vcf" | LC_ALL=C sort)
[[ "$expected" == "$observed" ]] || { echo 'cohort sample names do not match the validated samplesheet' >&2; exit 65; }
records=$(bcftools view -H "$vcf" | wc -l)
((records > 0)) || { echo 'cohort contains no variants' >&2; exit 65; }
