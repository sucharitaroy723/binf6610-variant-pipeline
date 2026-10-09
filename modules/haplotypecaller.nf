process HAPLOTYPECALLER {
    tag "${meta.id}"
    container params.containers.gatk
    input:
    tuple val(meta), path(bam), path(bai)
    path ref
    path ref_index
    path ref_dict
    val region
    output:
    path "${meta.id}.g.vcf.gz", emit: gvcf
    path "${meta.id}.g.vcf.gz.tbi", emit: tbi
    script:
    def heapMb = (task.memory.toMega() * 0.7).intValue()
    """
    mkdir -p tmp
    gatk --java-options '-Xmx${heapMb}m -Djava.io.tmpdir=tmp' HaplotypeCaller \\
        -R ${ref} -I ${bam} -O ${meta.id}.g.vcf.gz -ERC GVCF -L '${region}' \\
        --native-pair-hmm-threads ${task.cpus}
    gzip -t ${meta.id}.g.vcf.gz
    bcftools view -h ${meta.id}.g.vcf.gz > /dev/null
    test -s ${meta.id}.g.vcf.gz.tbi
    """
}
