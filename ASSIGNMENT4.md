# Assignment 4: variant calling with Nextflow

This adds a second implementation alongside stages/ and the shell entry points.
It uses the course's pinned images and the same fastp, BWA, MarkDuplicates,
CombineGVCFs, GenotypeGVCFs and hard-filter commands as the original pipeline.
modules/publish.nf and bin/run_manifest.sh are the unchanged course files.

The code is prepared; the Docker smoke run, Explorer run and four exercises must
still be executed on the actual machines. Do not submit until their evidence is committed.

## 1. Mac setup

Open Docker Desktop, then run these commands in this repository:

```bash
brew install nextflow
nextflow -version
bash scripts/assignment4/pull_images.sh
```

The course uses Nextflow 26.04.6; check the printed version. If a different version
is installed, use `NXF_VER=26.04.6 nextflow ...` for the commands below.
The image download is about 1.9 GB. Use your existing week-1 smoke dataset.
Confirm its location, then set the absolute path (example):

```bash
SMOKE="$HOME/smoke"
ls "$SMOKE/samplesheet.csv" "$SMOKE/smoke.fa" "$SMOKE/smoke.dict"
```

## 2. Laptop exercise 1 and successful smoke run

Start the smoke run; interrupt with Ctrl-C after some tasks finish, while later tasks are running:

```bash
mkdir -p evidence/assignment4
nextflow run main.nf -profile docker -ansi-log false \
    --samplesheet "$SMOKE/samplesheet.csv" --ref "$SMOKE/smoke.fa" \
    --region smoke_1mb --outdir results-smoke
```

Keep the printed progress and `.nextflow.log` as evidence before rerunning:

```bash
cp .nextflow.log evidence/assignment4/interrupted.nextflow.log
set -o pipefail
nextflow run main.nf -profile docker -resume -ansi-log false \
    --samplesheet "$SMOKE/samplesheet.csv" --ref "$SMOKE/smoke.fa" \
    --region smoke_1mb --outdir results-smoke \
    2>&1 | tee evidence/assignment4/resume.log
```

Only after the command succeeds, preserve the successful results:

```bash
mkdir -p smoke-run-nf
cp -R results-smoke/. smoke-run-nf/
/opt/homebrew/bin/bash tests/assignment4/run_acceptance.sh . smoke
```

## 3. Laptop exercises 2 and 3

Use separate output directories, and keep the successful smoke-run-nf intact.
Exercise 2 changes only BWA_MEM's reference argument:

```bash
python3 scripts/assignment4/exercise.py queue
nextflow run main.nf -profile docker -ansi-log false \
    --samplesheet "$SMOKE/samplesheet.csv" --ref "$SMOKE/smoke.fa" \
    --region smoke_1mb --outdir results-queue \
    2>&1 | tee evidence/assignment4/queue.log
cp .nextflow.log evidence/assignment4/queue.nextflow.log
python3 scripts/assignment4/exercise.py restore
```

Do not use -resume for the broken queue run; observe how many BWA_MEM tasks run.
It may fail at the cohort sample check after one sample proceeds.
Exercise 3 removes the escape before command substitution in BWA_MEM:

```bash
python3 scripts/assignment4/exercise.py dollar
nextflow run main.nf -profile docker -ansi-log false \
    --samplesheet "$SMOKE/samplesheet.csv" --ref "$SMOKE/smoke.fa" \
    --region smoke_1mb --outdir results-dollar \
    2>&1 | tee evidence/assignment4/dollar.log
cp .nextflow.log evidence/assignment4/dollar.nextflow.log
python3 scripts/assignment4/exercise.py restore
```

Read the actual error. If it creates a task, use the reported work directory:

```bash
cd work/XX/FULL_TASK_HASH
cat .command.sh .command.err
bash .command.run
echo "$?"
```

If Nextflow stops during parsing, there is no failed task directory. Record this
honestly; the assignment explicitly accepts an unexpected outcome with evidence.
After restoring, inspect and manually rerun a BWA_MEM task from the corrected
run, identifying it as the corrected task, not the failed attempt.
Return to the repository before proceeding. Restore both exercise edits, then commit
the source, the successful smoke run and the actual logs and push this branch.

## 4. Explorer: do the time-limit exercise FIRST

Pull the same branch on Explorer, in the existing repository. Submit the two-minute override:

```bash
sbatch slurm/nextflow.sbatch docs/assignment4/failure4.config
squeue -u "$USER"
```

The first run converts images. Monitor nf-head-JOBID.out, and preserve the log
and results/pipeline_info/trace.txt before resubmitting. Identify a HAPLOTYPECALLER
job ID in the trace's native_id column or the head log, then query its actual state:

```bash
sacct -j HAPLOTYPECALLER_JOBID --format=JobID,JobName,State,ExitCode,Elapsed,Timelimit
```

Record the exit status from Nextflow too. The job may receive a warning before
the limit; use observed accounting, not an assumed TIMEOUT.
Resubmit without the override to restore the one-hour HaplotypeCaller limit:

```bash
sbatch slurm/nextflow.sbatch
```

The script already uses -resume. Once the successful head job has finished:

```bash
mkdir -p cluster-run-nf
cp -R results/. cluster-run-nf/
module load miniconda3/25.9.1
source activate /courses/BINF6610.202710/shared/env/binf6610
{ bcftools view -H cluster-run-container/cohort.filtered.vcf.gz | sha256sum
  bcftools view -H cluster-run-nf/cohort.filtered.vcf.gz | sha256sum
} > cluster-run-nf/records-sha256.txt
cat cluster-run-nf/records-sha256.txt
```

If the hashes differ, investigate the real parameters and add a sentence based
on them. In particular, the original common.sh reserved one CPU for samtools;
the new BWA_MEM follows the assignment's `bwa mem -t ${task.cpus}`. The new Explorer
profile allocates 8 CPUs. Different BWA thread counts may affect alignments.
Do not invent an explanation or claim the hashes match before comparing them.

## 5. Evidence and final checks

Fill docs/assignment4/TROUBLESHOOTING-template.md with all four observed outcomes,
then replace the root TROUBLESHOOTING.md with the completed write-up.
Commit and push the results and evidence from Explorer, then pull them on your Mac:

```bash
git add main.nf modules bin nextflow.config slurm/nextflow.sbatch .gitignore \
    scripts/assignment4 docs/assignment4 tests/assignment4 ASSIGNMENT4.md TROUBLESHOOTING.md
git add -f smoke-run-nf cluster-run-nf evidence/assignment4
git commit -m "Complete Assignment 4 Nextflow runs and troubleshooting evidence"
git push -u origin assignment4-nextflow
```

Before submission, on the Mac with all committed results:

```bash
/opt/homebrew/bin/bash tests/assignment4/run_acceptance.sh .
git status
```

The tests were copied unchanged into tests/assignment4 to preserve the older
assignments' tests. All ten must pass at full points. The troubleshooting test
looks for keywords; manually check that the write-up includes real logs for all four.
Submit the repository/branch URL containing the code AND both new result folders.
Do not commit work/, .nextflow/ or the temporary results-* directories.
