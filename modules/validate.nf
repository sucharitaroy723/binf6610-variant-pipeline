// Stage 0: all FASTQs and reference sidecars are staged before validation.
process VALIDATE {
    container params.containers.tools
    input:
    path samplesheet
    path reads
    path ref
    path ref_index
    path ref_dict
    output:
    path samplesheet, emit: sheet
    script:
    """
    validate_samplesheet.sh ${samplesheet} ${ref} ${ref_dict}
    """
}
