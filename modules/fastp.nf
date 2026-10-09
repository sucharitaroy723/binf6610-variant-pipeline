process FASTP {
    tag "${meta.id}"
    container params.containers.fastp
    input:
    tuple val(meta), path(reads)
    output:
    tuple val(meta), path('*.trim.fastq.gz'), emit: reads
    path "${meta.id}.fastp.json", emit: json
    script:
    def inputArgs = meta.single_end ? "-i ${reads[0]}" : "-i ${reads[0]} -I ${reads[1]}"
    def outputArgs = meta.single_end ? "-o ${meta.id}_R1.trim.fastq.gz" :
        "-o ${meta.id}_R1.trim.fastq.gz -O ${meta.id}_R2.trim.fastq.gz"
    """
    fastp --thread ${task.cpus} ${inputArgs} ${outputArgs} \\
        -j ${meta.id}.fastp.json -h ${meta.id}.fastp.html
    check_trimmed_reads.sh ${meta.id}_*.trim.fastq.gz
    """
}
