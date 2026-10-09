process MULTIQC {
    container params.containers.multiqc
    input:
    path reports
    output:
    path 'multiqc_report.html'
    script:
    """
    multiqc --force --outdir . .
    test -s multiqc_report.html
    """
}
