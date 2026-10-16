# Assignment 5: observed troubleshooting

1. **Interrupted laptop run and recovery.** The command was
   `~/.venvs/binf6610-smk/bin/snakemake --profile profiles/laptop --config samplesheet=/Users/sucharita/Desktop/smoke/samplesheet.csv ref=/Users/sucharita/Desktop/smoke/smoke.fa region=smoke_1mb`.
   Automated SIGINT interrupted HaplotypeCaller after 7/21 steps; see
   [interrupted log](evidence/assignment5/laptop-interrupted.txt).
   The same command then raised `IncompleteFilesException` for
   `work/gvcf/smoke_03.g.vcf.gz` and requested `--rerun-incomplete`; see
   [retry diagnostic](evidence/assignment5/laptop-resume-attempt.txt).
   Adding `--rerun-incomplete` completed 14/14 steps (including publish and all),
   as recorded in [recovery log](evidence/assignment5/laptop-resumed-complete.txt).
   The original successful smoke run remains in `smoke-run-smk/` with its matching
   manifest. Recovered outputs and their own manifest are separately saved in
   `evidence/assignment5/laptop-recovered-results/`.

2. **Missing sample wildcard in the alignment log.** The deliberate dry run
   raised `RuleException`: “Not all output, log and benchmark files of rule
   bwa_mem contain the same wildcards.” See
   [actual diagnostic and command](evidence/assignment5/failure2-log-wildcard.txt).
   Each sample writes different alignment outputs, so its log must also contain
   `{sample}` to prevent multiple jobs writing the same log. The helper restored
   `logs/bwa_mem/{sample}.log` in the Snakefile.

3. **Removed fastp wildcard constraints.** The deliberate dry run raised
   `AmbiguousRuleException`: rules `fastp_paired` and `fastp_single` both matched
   `work/trim/smoke_01_R1.trim.fastq.gz`. See
   [actual diagnostic and command](evidence/assignment5/failure3-fastp-ambiguity.txt).
   Both rules share an R1 output pattern; constraints restrict them to their
   respective paired and single sample sets. The helper restored both constraints.

4. **Explorer run without Apptainer: pending actual execution.** SSH authentication
   and the first Explorer experiment have not yet been completed in this session.
   No failed rule, Slurm exit status, tool error, or validation rerun is claimed.
   Record these from the actual job and restored-profile dry run before submission.

Earlier troubleshooting is preserved in
[the previous document](docs/troubleshooting-before-assignment5.md).
