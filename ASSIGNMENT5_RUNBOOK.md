# Assignment 5: run and verify

This add-on adapts your assignment4-nextflow variant commands into Snakemake. It preserves the course publish.smk and run_manifest.sh byte for byte. It includes no claimed laptop/Explorer results. Run evidence must come from your machines.

The separate bin/validate_samplesheet_smk.sh checks original FASTQ paths, preserving the Nextflow validator. The filters match Assignment 4. Java heaps are fixed at 4 GB; HaplotypeCaller/aligner use the rule's allocated threads. Keep working files until both runs and failure evidence are complete.

## Install on your Mac

Extract the ZIP into Downloads. In Terminal, enter your existing repository (adjust its path if needed):

```bash
cd ~/Desktop/binf6610-variant-pipeline
git status --short --branch
```

Start from your completed Assignment 4 branch. If clean, switch to `assignment4-nextflow`, run `git pull --ff-only`, and install:

```bash
python3 ~/Downloads/assignment5/install.py .
export PATH="/opt/homebrew/bin:$PATH"
bash --version
snakemake --version
```

Use Snakemake 9.27.0 and Bash >=4.3. If Snakemake is missing, follow the Week 5 setup page, or create its own environment using an installed conda:

```bash
conda create -y -n binf6610-smk -c conda-forge -c bioconda snakemake=9.27.0
conda activate binf6610-smk
```

Verify that `fastqc fastp bwa samtools gatk bcftools multiqc` are available in this terminal. Preserve any existing `work/`, `logs/`, or `results/` by renaming them to unique backup names before the first run; Assignment 4 may have used these directories. Do not delete old results unless their saved copies are verified.

## Failure 2 and 3: capture dry-run errors

Run these before the real laptop run. The helper temporarily changes the Snakefile and restores it even if a command fails. It records actual output in evidence/assignment5/.

```bash
python3 scripts/assignment5/dry_failures.py --config samplesheet=$HOME/smoke/samplesheet.csv ref=$HOME/smoke/smoke.fa region=smoke_1mb
```

Read the evidence. A failure behaving differently is acceptable if explained honestly.

## Failure 1: interrupt and resume on the laptop

```bash
mkdir -p evidence/assignment5
snakemake --profile profiles/laptop -n --config samplesheet=$HOME/smoke/samplesheet.csv ref=$HOME/smoke/smoke.fa region=smoke_1mb
set -o pipefail
snakemake --profile profiles/laptop --config samplesheet=$HOME/smoke/samplesheet.csv ref=$HOME/smoke/smoke.fa region=smoke_1mb 2>&1 | tee evidence/assignment5/laptop-interrupted.txt
```

Press Ctrl-C while a compute rule is running, not after completion. Then run the exact same command, saving to `laptop-resume-attempt.txt` instead. Record what it says. If it requests `--rerun-incomplete`, add that option and save the completed run to `laptop-complete.txt`. Record the number of jobs run. If interruption leaves no incomplete outputs, report that observation; do not invent an IncompleteFilesException.

After successful completion:

```bash
mkdir -p smoke-run-smk
cp -R results/. smoke-run-smk/
git add Snakefile config.yaml rules/publish.smk bin/run_manifest.sh bin/validate_samplesheet_smk.sh profiles slurm/snakemake.sbatch tests scripts/assignment5 ASSIGNMENT5_RUNBOOK.md .gitignore
git add -f smoke-run-smk evidence/assignment5
git commit -m "Add Snakemake variant pipeline and laptop run"
git push -u origin assignment5-snakemake
```

## Failure 4: first Explorer run without Apptainer

On Explorer, enter your existing repository. Preserve any local changes before switching branches. Fetch and switch to assignment5-snakemake, then pull. Preserve pre-existing work/, logs/, results/ using unique backup names before this FIRST run. Use a clean working directory for this experiment.

```bash
git fetch origin
git switch assignment5-snakemake
git pull --ff-only
mkdir -p evidence/assignment5 slurm
cp profiles/explorer/profile.yaml evidence/assignment5/explorer-profile.original.yaml
python3 - <<'PY'
from pathlib import Path
p = Path('profiles/explorer/profile.yaml')
p.write_text(''.join(line for line in p.read_text().splitlines(True) if not line.startswith('software-deployment-method:')))
PY
sbatch slurm/snakemake.sbatch
```

Wait for this head job to finish/fail. Save its job ID and inspect its head log. Identify the failed rule, inspect its log under `logs/`, and find the corresponding Slurm log:

```bash
find .snakemake/slurm_logs -type f
```

Copy the failed job's Slurm log and rule log into `evidence/assignment5/` under clear filenames BEFORE retrying. Copy the first head log there too. Record its actual exit status; do not infer it from the head job alone. If tools are available without containers and the run succeeds, record that instead.

Restore deployment and inspect why jobs will rerun:

```bash
cp evidence/assignment5/explorer-profile.original.yaml profiles/explorer/profile.yaml
module load miniconda3/25.9.1
source activate /courses/BINF6610.202710/shared/env/binf6610-workflows
set -o pipefail
snakemake --profile profiles/explorer -n --config samplesheet=/courses/BINF6610.202710/data/samplesheet-variant8.csv ref=/courses/BINF6610.202710/data/refs/grch38-1000g/GRCh38_full_analysis_set_plus_decoy_hla.fa region=chr20:1-10000000 outdir=results 2>&1 | tee evidence/assignment5/explorer-restored-dry-run.txt
sbatch slurm/snakemake.sbatch
```

Keep the work directory. Record whether validate is scheduled again and the dry-run's reason (changing container deployment can alter its software environment). If incomplete files block resubmission, use `--rerun-incomplete` on the snakemake command in the head script, following its diagnostic.

Monitor `squeue -u "$USER"` and `tail -n 60 slurm/variant-call-smk-JOBID.out`. Substitute the actual job ID. The reference run takes about 25 minutes plus queue time; this is not a guarantee.

## Save successful Explorer results and compare with Week 4

Confirm the head job succeeded before copying:

```bash
mkdir -p cluster-run-smk
cp -R results/. cluster-run-smk/
cp slurm/variant-call-smk-*.out cluster-run-smk/
module load miniconda3/25.9.1
source activate /courses/BINF6610.202710/shared/env/binf6610
set -o pipefail
{
  bcftools view -H cluster-run-nf/cohort.filtered.vcf.gz | sha256sum
  bcftools view -H cluster-run-smk/cohort.filtered.vcf.gz | sha256sum
} > cluster-run-smk/records-sha256.txt
cat cluster-run-smk/records-sha256.txt
bcftools query -l cluster-run-smk/cohort.filtered.vcf.gz
```

If checksums differ, investigate differences in tools, parameters, threads or record ordering before writing the required explanatory sentence. Do not assume a cause without evidence. Both records hashes must be computed from the actual runs.

## Troubleshooting and submission

Replace last week's TROUBLESHOOTING.md with four numbered entries using YOUR observed evidence:

1. Interrupted smoke run: exact command, output, requested resume option (if any), and jobs run after resuming.
2. Missing sample wildcard in alignment log: error and explanation.
3. Removed fastp constraints: exception, two rule names and ambiguous file (or explain another observed error).
4. No Apptainer on first Explorer run: failed rule, actual Slurm exit status, rule-log output, fix, and whether validate reran and why.

Reference the saved evidence files. Keep first and subsequent head logs; all count toward the submission evidence.

```bash
git add -f cluster-run-smk evidence/assignment5
git add TROUBLESHOOTING.md profiles/explorer/profile.yaml slurm/snakemake.sbatch
git commit -m "Record Explorer Snakemake run and failure evidence"
git push
```

On the Mac, pull the same branch and run the official acceptance tests:

```bash
git pull --ff-only
/opt/homebrew/bin/bash tests/run_acceptance.sh .
git status --short --branch
git rev-parse HEAD
git ls-remote origin refs/heads/assignment5-snakemake
```

Target: all nine tests, 70/70 points. They check layout (10), profiles/head job (10), smoke SNV recall >=80% per sample (10), eight Explorer samples (10), >=40 Slurm submissions in saved head logs (5), tables (5), both manifests with correct checksums and containers (10), records comparison (5), and four evidenced failures (5). Passing a text check does not replace actually performing the failures.

Submit the same repository link, identifying the assignment5-snakemake branch if the submission field permits. The separate CWL quiz is 30 points and must also be completed.
