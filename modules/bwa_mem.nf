process BWA_MEM {
    tag "${meta.id}"
    container params.containers.bwa
    input:
    tuple val(meta), path(reads)
    path ref
    path ref_index
    output:
    tuple val(meta), path("${meta.id}.unsorted.bam"), emit: bam
    path "${meta.id}.bwa.log", emit: log
    script:
    """
    bwa mem -t ${task.cpus} -R '@RG\\tID:${meta.id}\\tSM:${meta.id}\\tPL:ILLUMINA' \\
        ${ref} ${reads} 2> ${meta.id}.bwa.log \\
        | samtools view -b -o ${meta.id}.unsorted.bam -
    samtools quickcheck ${meta.id}.unsorted.bam
    n_records=\$(samtools view -c ${meta.id}.unsorted.bam)
    test \$n_records -gt 0
    echo "${meta.id}: \$n_records alignment records"
    """
}
