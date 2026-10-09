# Assignment 4 — observed troubleshooting

These observations come from the Docker smoke runs and Explorer runs on 9 October 2026. Paths below refer to saved evidence in this repository. Earlier assignments remain available in Git history.

## 1. Interrupt a laptop run, then use -resume

Command: `python3 scripts/assignment4/interrupt_smoke.py`. The helper ran Nextflow 26.04.6 with the Docker profile, the samplesheet and reference under `/Users/sucharita/Desktop/smoke`, region `smoke_1mb`, and output directory `results-interrupt-auto`.

Observed: run `gloomy_cuvier` was interrupted with SIGINT at the first submitted BWA_MEM task. Nextflow reported `WARN: Killing running tasks (5)` and returned 1. The interruption receipt records `interrupted: true`.

The recovery used the same inputs and output directory with `-resume gloomy_cuvier`. It completed successfully and reused 19 tasks:

| Process | Cached tasks |
|---|---:|
| VALIDATE | 1 |
| FASTQC, FASTP, BWA_MEM, MARKDUPLICATES, HAPLOTYPECALLER | 3 each; smoke_01, smoke_02, smoke_03 |
| JOINT_GENOTYPE, FILTER, MULTIQC | 1 each |

PUBLISH was submitted again. It has `cache false`, so publishing and manifest generation run again even when upstream tasks are cached. Some matching task results already existed from earlier complete smoke attempts; the extensive reuse does not mean all these tasks finished during the interrupted attempt.

Fix: resume the named run while keeping the work directory and `.nextflow` metadata. Evidence: `evidence/assignment4/interruption.json`, `interrupted.log`, `interrupted.nextflow.log`, `resume.log`, `resume.nextflow.log`, and `resume.trace.txt`.

## 2. Replace the reference value input with a queue channel

`python3 scripts/assignment4/exercise.py queue` changed only the BWA_MEM reference argument from `ref` to `channel.fromPath(params.ref)`. The smoke run used the Docker profile and output directory `results-queue`, without `-resume`.

Observed:

```text
[1c/a9f0f7] Submitted process > BWA_MEM (smoke_01)
cohort sample names do not match the validated samplesheet
```

Only one BWA_MEM task was submitted, for smoke_01. Joint genotyping ran on the reduced set and failed its cohort sample-name check. The Nextflow command returned 1.

Explanation: `channel.fromPath(params.ref)` emits the reference as a queue item. That item is consumed by one alignment invocation. The original `file(params.ref, checkIfExists: true)` value is reusable for every sample when supplied as a process input. The final cohort guard catches the resulting loss of samples.

Fix: `python3 scripts/assignment4/exercise.py restore` restored the original reference argument. Evidence: `evidence/assignment4/queue.log`, `queue.nextflow.log`, and `queue.exit-code.txt`.

## 3. Remove the escape before Bash command substitution

`python3 scripts/assignment4/exercise.py dollar` removed the escape before `$(` in the BWA script. The Docker smoke run used output directory `results-dollar`, without `-resume`.

Observed: BWA_MEM for smoke_03 terminated with task exit status 2. Groovy interpolation produced this malformed generated command:

```bash
n_records=smoke_03samtools view -c smoke_03.unsorted.bam)
```

Bash reported:

```text
.command.sh: line 6: syntax error near unexpected token `)'
```

The affected task directory was `/Users/sucharita/Desktop/binf6610-variant-pipeline/work/a3/7c732dfc02ad1e367c5787fb36e1fa`. Running `bash .command.run` manually in that directory reproduced the same syntax error and exit status 2.

Fix: the helper restored the escaped dollar sign so command substitution is evaluated by Bash after Nextflow renders the task. `git diff -- main.nf modules/bwa_mem.nf` then printed nothing. Evidence: `evidence/assignment4/dollar.command.sh`, `dollar.command.err`, `dollar.command.run`, `dollar.log`, `dollar.nextflow.log`, `dollar.manual.log`, and `dollar.manual.exit-code.txt`.

## 4. Set HaplotypeCaller time to two minutes on Explorer

Command: `sbatch slurm/nextflow.sbatch docs/assignment4/failure4.config`. The override sets only HAPLOTYPECALLER to `time = '2m'`. Image preparation required recovery before this exercise could reach HaplotypeCaller; those setup failures are recorded separately below.

Observed exercise head job: 10946301. It reused completed preprocessing and submitted all eight HaplotypeCaller tasks. The failed NA07357 task used `/scratch/roy.suc/binf6610-assignment4-work/91/832da850165f220d10e6616444a0ed`. Its wrapper contains:

```text
#SBATCH --signal B:USR2@30
trap on_term TERM INT USR2
```

Slurm accounting recorded the following parent task jobs. The saved trace associates native job IDs with sample names; NA12813 is job 10946455.

| Job ID | State | ExitCode | Elapsed | Timelimit |
|---|---|---|---|---|
| 10946362 | FAILED | 12:0 | 00:01:16 | 00:02:00 |
| 10946363 | FAILED | 12:0 | 00:01:10 | 00:02:00 |
| 10946364 | FAILED | 12:0 | 00:01:02 | 00:02:00 |
| 10946377 | FAILED | 12:0 | 00:01:29 | 00:02:00 |
| 10946378 | FAILED | 12:0 | 00:01:26 | 00:02:00 |
| 10946381 | FAILED | 12:0 | 00:01:10 | 00:02:00 |
| 10946384 | FAILED | 12:0 | 00:01:10 | 00:02:00 |
| 10946455 (NA12813) | CANCELLED | 0:0 | 00:01:03 | 00:02:00 |

The cancelled task's batch step recorded FAILED, 15:0, elapsed 00:01:04. The head recorded FAILED, 1:0, elapsed 00:03:43, with its unchanged four-hour limit. Nextflow also reported that it was killing running tasks.

Explanation: this attempt did not produce a Slurm TIMEOUT state. The wrapper requests an advance USR2 signal 30 seconds before the time limit and traps that signal. Exit 12 and the early failures are consistent with that warning-signal handling. Slurm documents that warning delivery can occur up to 60 seconds earlier than requested: https://slurm.schedmd.com/sbatch.html . This accounts for termination before two minutes without claiming a TIMEOUT that was not observed.

Fix: resubmit `sbatch slurm/nextflow.sbatch` without the override. The normal HaplotypeCaller setting is one hour, and the head script already uses `-resume`. Recovery head job 10948007 was submitted; its queue output confirmed a HaplotypeCaller time limit of 1:00:00, and its log showed all eight HaplotypeCaller tasks submitted. The final recovery outcome must be checked against that head log and final trace before submission.

Evidence: `evidence/assignment4/time-limit.head.log`, `time-limit.nextflow.log`, `time-limit.trace.txt`, `time-limit.tasks.sacct.txt`, `time-limit.head.sacct.txt`, `time-limit.command.run`, `time-limit.command.sh`, `time-limit.command.err`, and `time-limit.task.exit-code.txt`.

## Additional Explorer setup and recovery observations

- Head 10944962 failed before VALIDATE: the tools image was unpacking under `/home/roy.suc/rstudio_tmp` when the 20-minute image-pull limit was reached. The reported pull status was 143. The head now sets `TMPDIR` and `APPTAINER_TMPDIR` to node-local `/tmp`, uses `/scratch/roy.suc/binf6610-assignment4-work` for task files, and permits one hour for image pulls. In the next attempt the tools image completed and VALIDATE was submitted.
- Head 10945475 failed while preparing FastQC with status 255 and `no descriptor found for reference`. The head now sets `APPTAINER_DISABLE_CACHE=true` to bypass Apptainer's mutable download/OCI cache. Nextflow's separate completed-image cache remains under `/scratch/roy.suc/nxf-apptainer`. The next attempt successfully prepared FastQC and fastp and launched their tasks.
- Head 10945567 ended with FAILED, 0:9 after 00:06:34. Slurm sampled batch MaxRSS at 5433268K against a 16G request. These observations do not establish the cause of signal 9, so this is not labelled as a proven out-of-memory failure. Image compression was subsequently limited to the head's allocated CPUs and a 1 GB compression cache using `APPTAINER_MKSQUASHFS_ARGS`. The following attempt reached all eight HaplotypeCaller tasks.

These setup failures are distinct from the four deliberate exercises. Their saved logs are `explorer-first.*`, `explorer-cache.*`, and `explorer-killed.*` under `evidence/assignment4`.
