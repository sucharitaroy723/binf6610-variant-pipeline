# Code checks before the real Assignment 4 runs

Prepared from main at e1686118303ff06c4430953ffaf62fc26f7a2821.

- Nextflow 26.04.6 executed the complete workflow using temporary stand-in tools
  and a tiny fixture containing two paired-end samples and one single-end sample.
  All 20 tasks completed; all three samples reached the cohort output.
- The fixture's published tables and every checksum in the manifest agreed
  with the corresponding output files.
- After adjusting GATK's JVM heap to 70% of task.memory, the workflow completed
  again. Unchanged tasks were cached, while changed tasks and PUBLISH reran.
- Stage 0 accepted valid reads and rejected truncated gzip input, incomplete
  paired FASTQ records and duplicate sample IDs.
- The unchanged course acceptance tests passed for layout and head-job settings.
- Config inspection confirmed the Explorer profile uses Slurm and Apptainer;
  the first-run override selects time = '2m' for HAPLOTYPECALLER.
- The exercise helper restored both modified files byte for byte. The two
  course publishing/manifest files remain byte for byte identical to the uploads.
- Shell syntax checks and git diff --check passed.
- In a separate copy using stand-in tools, the dollar-sign exercise produced
  a malformed BWA_MEM .command.sh and Bash exit status 2. This confirms the
  helper targets a real task-script failure; repeat it with Docker for graded evidence.

These are code checks, not biological or container validation. No fixture
results, fabricated Docker traces, invented Slurm IDs or simulated failures
were added as assignment evidence. The real smoke and eight-sample runs,
record comparison and all four observed exercises remain to be completed.
