# Troubleshooting Log
# Troubleshooting

## BWA read-group failure during alignment

The pipeline initially stopped during Stage 3 without printing a clear error to the terminal because the program output had been redirected to log files. I inspected the BWA and samtools logs and found two related messages: BWA reported that the read-group line contained literal tab characters, and samtools reported that it could not read the alignment header from standard input.

The read-group string had been created with `printf`, which converted `\t` into real tab characters before passing it to `bwa mem`. BWA expects the read-group argument to contain escaped `\t` sequences. I fixed this by assigning the string directly:

`read_group="@RG\tID:${id}\tSM:${id}\tPL:ILLUMINA"`

I then passed the quoted variable to BWA. After rerunning Stage 3, `samtools quickcheck` confirmed that all three BAM files were valid. I also inspected their headers and confirmed that each `@RG` line contained the correct sample ID in the `SM` field.

## MultiQC output-directory check

Stage 8 initially generated its HTML report successfully, but my pipeline stopped because its sanity check expected a directory named `multiqc_data`. Supplying a custom report filename caused MultiQC to create `multiqc_report_data` instead. I confirmed the actual files with `ls`, then removed the unnecessary custom filename option so MultiQC used its standard names: `multiqc_report.html` and `multiqc_data`. This also matches the directory naming expected by the course manifest writer.
