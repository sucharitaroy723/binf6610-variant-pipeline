include { VALIDATE }        from './modules/validate'
include { FASTQC }          from './modules/fastqc'
include { FASTP }           from './modules/fastp'
include { BWA_MEM }         from './modules/bwa_mem'
include { MARKDUPLICATES }  from './modules/markduplicates'
include { HAPLOTYPECALLER } from './modules/haplotypecaller'
include { JOINT_GENOTYPE }  from './modules/joint_genotype'
include { FILTER }         from './modules/filter'
include { MULTIQC }        from './modules/multiqc'
include { PUBLISH }        from './modules/publish'

workflow {
    main:
    if (!params.samplesheet || !params.ref || !params.region)
        error 'Supply --samplesheet, --ref and --region (see ASSIGNMENT4.md).'

    sheet     = file(params.samplesheet, checkIfExists: true)
    ref       = file(params.ref, checkIfExists: true)
    ref_index = files("${params.ref}.*", checkIfExists: true)
    ref_dict  = ref.resolveSibling("${ref.baseName}.dict")

    ch_samples = channel.fromPath(sheet)
        .splitCsv(header: true)
        .map { row ->
            def meta = [id: row.sample_id, single_end: row.library_type == 'single']
            def r1 = sheet.parent.resolve(row.r1_fastq)
            def reads = meta.single_end ? [r1] : [r1, sheet.parent.resolve(row.r2_fastq)]
            [meta, reads]
        }

    VALIDATE(sheet, ch_samples.map { _meta, reads -> reads }.collect(),
             ref, ref_index, ref_dict)
    ch_checked = ch_samples
        .combine(VALIDATE.out.sheet)
        .map { meta, reads, _validated -> [meta, reads] }

    FASTQC(ch_checked)
    FASTP(ch_checked)
    BWA_MEM(FASTP.out.reads, ref, ref_index)
    MARKDUPLICATES(BWA_MEM.out.bam)
    HAPLOTYPECALLER(MARKDUPLICATES.out.bam, ref, ref_index, ref_dict, params.region)
    JOINT_GENOTYPE(HAPLOTYPECALLER.out.gvcf.collect(), HAPLOTYPECALLER.out.tbi.collect(),
                   ref, ref_index, ref_dict, params.region, VALIDATE.out.sheet)
    FILTER(JOINT_GENOTYPE.out.vcf, JOINT_GENOTYPE.out.tbi, ref, ref_index, ref_dict)

    ch_qc = FASTQC.out.zip
        .mix(FASTP.out.json, BWA_MEM.out.log, MARKDUPLICATES.out.qc)
        .collect()
    MULTIQC(ch_qc)
    PUBLISH(VALIDATE.out.sheet, FILTER.out.vcf.mix(FILTER.out.index, FILTER.out.table, MULTIQC.out).collect())

    publish:
    vcf      = FILTER.out.vcf
    index    = FILTER.out.index
    variants = FILTER.out.table
    multiqc  = MULTIQC.out
    manifest = PUBLISH.out.manifest
    samples  = PUBLISH.out.samples
}

output {
    vcf      { path '.' }
    index    { path '.' }
    variants { path '.' }
    multiqc  { path '.' }
    manifest { path '.' }
    samples  { path '.' }
}
