# Assignment 4 troubleshooting — worksheet, not completed evidence

Replace the bracketed fields with what actually happened. After all four exercises,
copy this document to the root TROUBLESHOOTING.md. Keep the older write-up in Git history.

## 1. Interrupted laptop run and -resume

Command: [exact command, interruption point, rerun with -resume]
Observed output: [cached tasks and tasks that ran again; include sample IDs]
Evidence: [log path or short actual output]
Fix: rerun the same command with -resume, keeping work/ and .nextflow/.
PUBLISH uses cache false, so it always runs again to write a fresh manifest.

## 2. Reference passed as a queue channel

Command: [exercise.py queue, then the Docker smoke command]
Observed output: [number of BWA_MEM tasks, sample that consumed the reference, exit status]
Evidence: [progress or trace; any actual downstream error]
Explanation: channel.fromPath(params.ref) is a queue channel consumed once. file(params.ref)
provides a reusable value channel for all samples. This pipeline also checks the final
cohort against the validated samplesheet, so record whether that check catches the loss.
Fix: exercise.py restore; rerun the correct workflow.

## 3. Unescaped command substitution

Command: [exercise.py dollar, then the Docker smoke command]
Observed output: [exact Nextflow or task error]
Task files: [.command.sh and .command.err contents, or explain if no task was created]
Manual rerun: [cd into the affected work folder; bash .command.run; actual output/status]
If parsing stops before a task exists, record that and inspect the corresponding task
from a corrected run instead. Clearly label it as the corrected task.
Fix: exercise.py restore so Bash's dollar sign is escaped in the Groovy script.

## 4. Two-minute HaplotypeCaller limit on the first Explorer run

Command: sbatch slurm/nextflow.sbatch docs/assignment4/failure4.config
Head job ID: [ID]
HaplotypeCaller job ID and sample: [from the trace or head log]
Nextflow reported exit status: [actual status]
sacct evidence (State, Elapsed, Timelimit): [actual output]
Explanation: Nextflow may stop the task on Slurm's advance warning; do not assume TIMEOUT.
Fix: sbatch slurm/nextflow.sbatch, without the override, restores the one-hour limit.
-resume reuses completed tasks and retries unfinished ones.
