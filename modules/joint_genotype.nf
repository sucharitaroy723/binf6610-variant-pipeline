process JOINT_GENOTYPE {
    container params.containers.gatk
    input:
    path gvcfs
    path tbis
    path ref
    path ref_index
    path ref_dict
    val region
    path samplesheet
    output:
    path 'cohort.raw.vcf.gz', emit: vcf
    path 'cohort.raw.vcf.gz.tbi', emit: tbi
    script:
    def heapMb = (task.memory.toMega() * 0.7).intValue()
    def variants = gvcfs.collect { "-V ${it}" }.join(' ')
    """
    mkdir -p tmp
    gatk --java-options '-Xmx${heapMb}m -Djava.io.tmpdir=tmp' CombineGVCFs \\
        -R ${ref} ${variants} -O cohort.g.vcf.gz -L '${region}'
    gatk --java-options '-Xmx${heapMb}m -Djava.io.tmpdir=tmp' GenotypeGVCFs \\
        -R ${ref} -V cohort.g.vcf.gz -O cohort.raw.vcf.gz -L '${region}'
    gzip -t cohort.raw.vcf.gz
    test -s cohort.raw.vcf.gz.tbi
    check_cohort_samples.sh ${samplesheet} cohort.raw.vcf.gz
    """
}
