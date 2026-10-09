process FILTER {
    container params.containers.gatk
    input:
    path vcf
    path tbi
    path ref
    path ref_index
    path ref_dict
    output:
    path 'cohort.filtered.vcf.gz', emit: vcf
    path 'cohort.filtered.vcf.gz.tbi', emit: index
    path 'variants.tsv', emit: table
    script:
    def heapMb = (task.memory.toMega() * 0.7).intValue()
    """
    mkdir -p tmp
    gatk --java-options '-Xmx${heapMb}m -Djava.io.tmpdir=tmp' VariantFiltration \\
        -R ${ref} -V ${vcf} -O cohort.filtered.vcf.gz \\
        --filter-name QD2 --filter-expression 'QD < 2.0' \\
        --filter-name QUAL30 --filter-expression 'QUAL < 30.0' \\
        --filter-name FS60 --filter-expression 'FS > 60.0' \\
        --filter-name SOR3 --filter-expression 'SOR > 3.0' \\
        --filter-name MQ40 --filter-expression 'MQ < 40.0' \\
        --filter-name MQRankSum-12.5 --filter-expression 'MQRankSum < -12.5' \\
        --filter-name ReadPosRankSum-8 --filter-expression 'ReadPosRankSum < -8.0'
    gzip -t cohort.filtered.vcf.gz
    test -s cohort.filtered.vcf.gz.tbi
    printf 'chrom\\tpos\\tref\\talt\\tqual\\tfilter\\n' > variants.tsv
    bcftools query -f '%CHROM\\t%POS\\t%REF\\t%ALT\\t%QUAL\\t%FILTER\\n' \\
        cohort.filtered.vcf.gz >> variants.tsv
    """
}
