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

4. **First Explorer run without Apptainer.** In `/home/roy.suc/binf6610-variant-pipeline`,
   removed only `software-deployment-method: apptainer` from the Explorer profile
   and submitted `sbatch slurm/snakemake.sbatch`: head job **11145002**.
   Validation succeeded without containers (job **11145015**, `COMPLETED`, `0:0`).
   Downstream fastp and FastQC jobs failed. For example, rule `fastp_paired`
   for NA12878 (job **11145118**) wrote
   `/usr/bin/bash: line 1: fastp: command not found` to its
   [rule log](evidence/assignment5/explorer-first-run/rule-logs/fastp/NA12878.log).
   Its [Slurm log](evidence/assignment5/explorer-first-run/slurm-logs/rule_fastp_paired/NA12878/11145118.log)
   reports shell exit status **127**. The actual Slurm job status is
   **FAILED, ExitCode 1:0**, not 127; see
   [accounting](evidence/assignment5/explorer-first-run/accounting.txt).
   The [first head log](evidence/assignment5/explorer-first-run/variant-call-smk-11145002.out)
   records the failures; the head also finished `FAILED`, `1:0`.
   Restored the original profile and ran `snakemake --profile profiles/explorer -n`
   with the same eight-sample samplesheet, reference, region and results directory.
   The [restored dry run](evidence/assignment5/explorer-restored-dry-run.txt)
   schedules `validate` again with the exact reason
   “Software environment definition has changed since last execution.”
   Thus restoring container deployment invalidated its prior software environment,
   even though its output was already present. Submitted the restored workflow
   as head job **11145320**. That run exposed an additional environment issue:
   `mktemp` could not use inherited `/home/roy.suc/rstudio_tmp` inside the container.
   See [validation log](evidence/assignment5/explorer-tmpdir-failure/validate.log)
   and [Slurm log](evidence/assignment5/explorer-tmpdir-failure/11145339.log).
   Updated the head script to export and create
   `TMPDIR=/scratch/${USER}/snakemake-tmp`, within the existing `/scratch` bind.
   Submitted head **11145390** with `--dependency=afterany:11145320` so the retry
   waits for the failed head to release its workflow lock. The corrected workflow
   completed **46/46 steps**, and Slurm reports `COMPLETED`, `0:0` for head 11145390.
   See [all head-job accounting](evidence/assignment5/explorer-head-accounting.txt)
   and [successful head log](cluster-run-smk/variant-call-smk-11145390.out).
   All three head logs are saved in `cluster-run-smk/`.
   The results-preservation/checksum job **11145887** also completed `0:0`.
   Both actual `bcftools view -H ... | sha256sum` record hashes are identical:
   `44f024954abc93339b3791cf7398aca936b22dc0d7578be08f527c3b7b0842fe`.
   See [comparison](cluster-run-smk/records-sha256.txt). The Nextflow source is
   Assignment 4 commit `1e06ce15873a7390c4eb74c075a181e47a094be0`;
   its actual `cluster-run-nf/` artifacts were restored from that commit and
   verified against their original manifest before comparison.

Earlier troubleshooting is preserved in
[the previous document](docs/troubleshooting-before-assignment5.md).
