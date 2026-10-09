process MARKDUPLICATES {
    tag "${meta.id}"
    container params.containers.gatk
    input:
    tuple val(meta), path(bam)
    output:
    tuple val(meta), path("${meta.id}.dedup.bam"), path("${meta.id}.dedup.bam.bai"), emit: bam
    path "${meta.id}*.txt", emit: qc
    script:
    def heapMb = (task.memory.toMega() * 0.7).intValue()
    """
    mkdir -p tmp
    samtools sort -@ ${task.cpus - 1} -T tmp/sort -o ${meta.id}.sorted.bam ${bam}
    samtools quickcheck ${meta.id}.sorted.bam
    gatk --java-options '-Xmx${heapMb}m -Djava.io.tmpdir=tmp' MarkDuplicates \\
        -I ${meta.id}.sorted.bam -O ${meta.id}.dedup.bam \\
        -M ${meta.id}.duplicate_metrics.txt --CREATE_INDEX false
    samtools quickcheck ${meta.id}.dedup.bam
    samtools index ${meta.id}.dedup.bam
    samtools flagstat ${meta.id}.dedup.bam > ${meta.id}.flagstat.txt
    test -s ${meta.id}.dedup.bam.bai
    test -s ${meta.id}.duplicate_metrics.txt
    """
}
