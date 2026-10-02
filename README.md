# BINF6610 variant pipeline: Assignment 2

The variant-calling analysis from Assignment 1 is shared by `run_pipeline.sh`
(all samples, stages 0-9) and `run_sample.sh` (one sample, stages 0-5).
`slurm/` schedules the work on Explorer. It contains no analysis commands.

## Run the automated workflow on Explorer

Clone this repository with git, or fetch the assignment branch in an existing clone:

```bash
cd ~/binf6610-variant-pipeline
git fetch origin
git switch assignment2-slurm
git pull --ff-only
bash scripts/submit_workflow.sh
```

For a new clone, first use the repository's SSH URL:

```bash
cd ~
git clone git@github.com:sucharitaroy723/binf6610-variant-pipeline.git
cd binf6610-variant-pipeline
git switch assignment2-slurm
bash scripts/submit_workflow.sh
```

GitHub SSH authentication must already be configured. All commands above run on
Explorer after you log in, not on your Mac. The driver checks course access,
reference paths, the official eight-row samplesheet, and Slurm submission access.
It refuses tracked code changes so the manifest records committed code.

The launcher prints the coordinator job ID and its log path. Watch progress with
`tail -f slurm/logs/workflow_<jobid>.out`; Ctrl-C stops watching, not the job.
`squeue -u "$USER"` shows queued/running jobs. The coordinator has a dedicated
allocation of one CPU, 1G memory, and twelve hours, so a login-node process
cleanup cannot kill the monitor. It performs only scheduling and metadata
operations; analysis runs in separate compute jobs. It does not submit to Canvas,
commit results, merge branches, or push automatically.

The driver performs:

1. Fresh sample-1 runs at 4, 8, and 16 cores, followed by a three-sample probe.
2. Selection of cores from measured wall time, plus memory/time headroom.
3. The eight-sample array and its cohort job with an `afterok` dependency.
4. The four deliberate failures: a two-minute limit, task 2 exiting 1,
   `--array=1-9`, and cancellation during alignment followed by a rerun.
5. Real `sacct`, available `seff`, cgroup peaks, log excerpts, and disk snapshots.
6. Generation of `RESOURCES.md` and `TROUBLESHOOTING.md`, copying the production
   VCF/manifest into `cluster-run/`, and running the supplied acceptance suite.

If a job fails unexpectedly, it stops and saves the job IDs/evidence. The resume
command printed in the log reuses those submissions, rather than duplicating them.
A genuinely failed job needs its cause corrected and a new run started. For a
queue wait or interrupted monitor, submit another coordinator with
`bash scripts/submit_workflow.sh --resume <evidence-directory>`. The saved job
IDs are reused. Orchestration-only code updates are allowed on resume; analysis
changes require a new run. Default
maximum wait is twelve hours per job; it never cancels production jobs on a wait
timeout. Queues can extend the total duration substantially.

## Review and submit

After the log says all ten checks passed, review the generated resource decisions
and failure diagnoses against the pasted evidence. The driver records what
actually happened if a cancellation/time-limit experiment finishes too quickly.
The initial resource requests are deliberately generous; the reports distinguish
those starting settings from the measured requests used for the final array.

```bash
bash tests/run_acceptance.sh .
git add RESOURCES.md TROUBLESHOOTING.md cluster-run/manifest.json
git add -f cluster-run/cohort.filtered.vcf.gz
git commit -m "Record Assignment 2 Explorer run and experiment evidence"
git push -u origin assignment2-slurm
```

Merge the assignment branch into `main` after reviewing it, so the submitted
repository URL exposes the finished assignment on its default branch. Commit only
the two files in `cluster-run/` as run output; full logs, BAMs, and evidence stay
under your scratch run directory. The original Assignment 1 troubleshooting
notes are in `docs/assignment1-troubleshooting.md`.

## Manual entry points and local checks

```bash
bash run_pipeline.sh <samplesheet.csv> <outdir> [last-stage]
bash run_sample.sh <samplesheet.csv> <outdir> <sample_id> [last-stage]
bash slurm/submit.sh
python3 -m unittest discover -s tests -p 'test_cluster_support.py'
bash tests/run_acceptance.sh .
```

Manual cluster submission uses the conservative defaults in `slurm/conf/slurm.env`.
The course samplesheet and input data are read where they live; neither is copied
into the repository. Sample IDs are selected by array row, and stages read needed
CSV columns by header name. Checkpoints are written only after stage success and
invalidated when the sheet, reference, region, or stage code changes. Interrupted
stages repeat; validated BAM/VCF products are renamed from temporary names. Temporary
sort files and Java scratch use each compute job's node-local `TMPDIR`.

The former Assignment 1 acceptance script is preserved as
`tests/run_acceptance_w01.sh`; `tests/run_acceptance.sh` is now the supplied
Assignment 2 script, unchanged.
