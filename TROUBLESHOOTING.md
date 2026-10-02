# Assignment 2 deliberate failures

Actual job states, logs, and file listings from this Explorer run. Assignment 1 notes are preserved in `docs/assignment1-troubleshooting.md`.

## 1. Two-minute time limit

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728711_1|TIMEOUT|0:0|145|25:26.185||8|32G|None
10728711_1.batch|FAILED|15:0|562|25:26.184|6620084K|8||
10728711_1.extern|COMPLETED|0:0|145|00:00.001|256K|8||
```

```text
persample_10728711_1.out:
[01:36:25] validation passed
[01:36:25] ===== NA12878: qc_raw =====
[01:36:54] NA12878: raw-read QC completed
[01:36:54] ===== NA12878: trim =====
[01:37:08] NA12878: trimming completed with 1222355 reads
[01:37:08] ===== NA12878: align =====
slurmstepd: error: *** JOB 10728711 ON c3014 CANCELLED AT 2026-10-01T01:38:16 DUE TO TIME LIMIT ***
[01:39:20] NA12878: alignment produced 2447955 records
[01:39:20] ===== NA12878: postprocess =====
[01:39:53] NA12878: postprocessing completed with 2447955 records
[01:39:53] ===== NA12878: quantify =====
[01:45:13] NA12878: HaplotypeCaller produced 1575865 GVCF records
[01:45:13] NA12878: done
MEMORY_PEAK_BYTES=8475664384
```

Observed states: TIMEOUT. Slurm reported the time limit at 01:38:16 during alignment, but analysis continued through HaplotypeCaller until 01:45:13. The batch step ultimately reported FAILED with ExitCode 15:0. All six successful-stage checkpoints and the BAM/GVCF outputs were left on disk. Thus TIMEOUT describes the scheduler outcome; it did not mean analysis stopped immediately. Delayed shell signal handling is a possible contributor, but these logs do not establish the exact cause. The final log lines identify the last stage reached. Files left on disk:

```text
.state/NA12878.align.done	259 bytes
.state/NA12878.postprocess.done	259 bytes
.state/NA12878.qc_raw.done	259 bytes
.state/NA12878.quantify.done	259 bytes
.state/NA12878.trim.done	259 bytes
.state/NA12878.validate.done	259 bytes
align/NA12878.unsorted.bam	218552059 bytes
gvcf/NA12878.g.vcf.gz	22697471 bytes
gvcf/NA12878.g.vcf.gz.tbi	10144 bytes
logs/NA12878.bwa.log	5813 bytes
logs/NA12878.duplicate_metrics.txt	4082 bytes
logs/NA12878.fastp.html	485927 bytes
logs/NA12878.fastp.json	132031 bytes
logs/NA12878.fastp.log	1668 bytes
logs/NA12878.fastqc.log	208 bytes
logs/NA12878.flagstat.txt	527 bytes
logs/NA12878.haplotypecaller.log	9701 bytes
logs/NA12878.markduplicates.log	5381 bytes
logs/NA12878.samtools_sort.log	63 bytes
postprocess/NA12878.dedup.bam	132411935 bytes
postprocess/NA12878.dedup.bam.bai	1620280 bytes
postprocess/NA12878.sorted.bam	105854433 bytes
qc_raw/NA12878_R1_fastqc.html	581659 bytes
qc_raw/NA12878_R1_fastqc.zip	871775 bytes
qc_raw/NA12878_R2_fastqc.html	596171 bytes
qc_raw/NA12878_R2_fastqc.zip	897375 bytes
trim/NA12878_R1.fastq.gz	87230844 bytes
trim/NA12878_R2.fastq.gz	91236895 bytes
```

## 2. One task exits 1 under afterok

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728802_1|COMPLETED|0:0|21|00:04.089||8|32G|None
10728802_1.batch|COMPLETED|0:0|21|00:04.088|976K|8||
10728802_1.extern|COMPLETED|0:0|21|00:00.001|24K|8||
10728802_2|FAILED|1:0|8|00:03.948||8|32G|None
10728802_2.batch|FAILED|1:0|8|00:03.947|1200K|8||
10728802_2.extern|COMPLETED|0:0|8|00:00.001|0|8||
10728802_3|COMPLETED|0:0|8|00:04.038||8|32G|None
10728802_3.batch|COMPLETED|0:0|8|00:04.037|632K|8||
10728802_3.extern|COMPLETED|0:0|8|00:00.001|256K|8||
10728802_4|COMPLETED|0:0|7|00:04.138||8|32G|None
10728802_4.batch|COMPLETED|0:0|7|00:04.137|1096K|8||
10728802_4.extern|COMPLETED|0:0|7|00:00.001|256K|8||
10728802_5|COMPLETED|0:0|6|00:03.984||8|32G|None
10728802_5.batch|COMPLETED|0:0|6|00:03.983|1008K|8||
10728802_5.extern|COMPLETED|0:0|6|00:00.001|256K|8||
10728802_6|COMPLETED|0:0|6|00:04.101||8|32G|None
10728802_6.batch|COMPLETED|0:0|6|00:04.100|1364K|8||
10728802_6.extern|COMPLETED|0:0|6|00:00.001|0|8||
10728802_7|COMPLETED|0:0|6|00:04.036||8|32G|None
10728802_7.batch|COMPLETED|0:0|6|00:04.035|1256K|8||
10728802_7.extern|COMPLETED|0:0|6|00:00.001|256K|8||
10728802_8|COMPLETED|0:0|6|00:04.090||8|32G|None
10728802_8.batch|COMPLETED|0:0|6|00:04.089|1096K|8||
10728802_8.extern|COMPLETED|0:0|6|00:00.001|256K|8||
```

```text
persample_10728802_2.out:
deliberate task failure: exit 1
MEMORY_PEAK_BYTES=59752448
```

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728803|CANCELLED|0:0|0|00:00:00||0|32G|Dependency
```



Task 2 is explicitly programmed to exit 1 for this experiment. The cohort dependency requires every task to succeed; its actual State and Reason are shown above. `--kill-on-invalid-dep=yes` requests cancellation when the dependency cannot be met.

## 3. Array 1-9 against eight rows

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728815_1|COMPLETED|0:0|19|00:04.033||8|32G|None
10728815_1.batch|COMPLETED|0:0|19|00:04.032|836K|8||
10728815_1.extern|COMPLETED|0:0|19|00:00.001|256K|8||
10728815_2|COMPLETED|0:0|8|00:03.995||8|32G|None
10728815_2.batch|COMPLETED|0:0|8|00:03.994|1020K|8||
10728815_2.extern|COMPLETED|0:0|8|00:00.001|256K|8||
10728815_3|COMPLETED|0:0|8|00:04.056||8|32G|None
10728815_3.batch|COMPLETED|0:0|8|00:04.055|984K|8||
10728815_3.extern|COMPLETED|0:0|8|00:00:00|256K|8||
10728815_4|COMPLETED|0:0|8|00:03.980||8|32G|None
10728815_4.batch|COMPLETED|0:0|8|00:03.979|748K|8||
10728815_4.extern|COMPLETED|0:0|8|00:00:00|256K|8||
10728815_5|COMPLETED|0:0|8|00:04.010||8|32G|None
10728815_5.batch|COMPLETED|0:0|8|00:04.009|1148K|8||
10728815_5.extern|COMPLETED|0:0|8|00:00.001|256K|8||
10728815_6|COMPLETED|0:0|8|00:04.116||8|32G|None
10728815_6.batch|COMPLETED|0:0|8|00:04.115|1592K|8||
10728815_6.extern|COMPLETED|0:0|8|00:00.001|256K|8||
10728815_7|COMPLETED|0:0|8|00:04.051||8|32G|None
10728815_7.batch|COMPLETED|0:0|8|00:04.050|1196K|8||
10728815_7.extern|COMPLETED|0:0|8|00:00.001|256K|8||
10728815_8|COMPLETED|0:0|6|00:04.019||8|32G|None
10728815_8.batch|COMPLETED|0:0|6|00:04.018|1284K|8||
10728815_8.extern|COMPLETED|0:0|6|00:00:00|256K|8||
10728815_9|FAILED|64:0|7|00:03.962||8|32G|None
10728815_9.batch|FAILED|64:0|7|00:03.961|1040K|8||
10728815_9.extern|COMPLETED|0:0|8|00:00.001|256K|8||
```

```text
persample_10728815_2.out:
task=2 sample=NA12891 host=c0584 cpus=8 run=/scratch/roy.suc/w2-variant/20261001-003850-2228995/production
[01:46:13] NA12891: validate already completed
[01:46:13] NA12891: qc_raw already completed
[01:46:13] NA12891: trim already completed
[01:46:13] NA12891: align already completed
[01:46:13] NA12891: postprocess already completed
[01:46:13] NA12891: quantify already completed
[01:46:13] NA12891: done
MEMORY_PEAK_BYTES=59908096
```

```text
persample_10728815_9.out:
task 9: no row 9 in /courses/BINF6610.202710/data/samplesheet-variant8.csv
MEMORY_PEAK_BYTES=60141568
```

Task 9 has no samplesheet row. The guard refuses its empty sample with exit 64 before analysis starts. Without the batch guard, this implementation still rejects an empty sample in run_sample.sh; without both guards, a pipeline could select no samples or all samples and falsely report success.

## 4. scancel during alignment, then rerun

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728836_1|CANCELLED by 94327|0:0|70|24:35.130||8|32G|None
10728836_1.batch|FAILED|15:0|537|24:35.129|6526252K|8||
10728836_1.extern|COMPLETED|0:0|70|00:00.001|256K|8||
```

```text
persample_10728836_1.out:
[01:47:07] validation passed
[01:47:07] ===== NA12878: qc_raw =====
[01:47:31] NA12878: raw-read QC completed
[01:47:31] ===== NA12878: trim =====
[01:47:44] NA12878: trimming completed with 1222355 reads
[01:47:44] ===== NA12878: align =====
slurmstepd: error: *** JOB 10728836 ON c3014 CANCELLED AT 2026-10-01T01:47:49 ***
[01:49:39] NA12878: alignment produced 2447955 records
[01:49:39] ===== NA12878: postprocess =====
[01:50:11] NA12878: postprocessing completed with 2447955 records
[01:50:11] ===== NA12878: quantify =====
[01:55:35] NA12878: HaplotypeCaller produced 1575865 GVCF records
[01:55:36] NA12878: done
MEMORY_PEAK_BYTES=8423333888
```

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728905_1|COMPLETED|0:0|21|00:04.081||8|32G|None
10728905_1.batch|COMPLETED|0:0|21|00:04.080|1012K|8||
10728905_1.extern|COMPLETED|0:0|21|00:00.001|256K|8||
```

```text
persample_10728905_1.out:
task=1 sample=NA12878 host=c3014 cpus=8 run=/scratch/roy.suc/w2-variant/20261001-003850-2228995/cancel
[01:56:13] NA12878: validate already completed
[01:56:13] NA12878: qc_raw already completed
[01:56:13] NA12878: trim already completed
[01:56:13] NA12878: align already completed
[01:56:14] NA12878: postprocess already completed
[01:56:14] NA12878: quantify already completed
[01:56:14] NA12878: done
MEMORY_PEAK_BYTES=62611456
```

Cancellation was requested during alignment, and Slurm recorded CANCELLED at 01:47:49. However, the analysis continued: alignment, postprocessing, and HaplotypeCaller finished by 01:55:36. The rerun completed in 21 seconds and skipped all six stages because their successful-stage checkpoints already existed. This experiment therefore demonstrated reuse of completed outputs, but did not demonstrate recovery from an interrupted write. The implementation writes alignment to a temporary BAM, validates it before renaming, and writes a checkpoint only after stage success; a stage without that checkpoint is designed to run again.

cancel-before-rerun:

```text
.state/NA12878.align.done	259 bytes
.state/NA12878.postprocess.done	259 bytes
.state/NA12878.qc_raw.done	259 bytes
.state/NA12878.quantify.done	259 bytes
.state/NA12878.trim.done	259 bytes
.state/NA12878.validate.done	259 bytes
align/NA12878.unsorted.bam	218552058 bytes
gvcf/NA12878.g.vcf.gz	22697507 bytes
gvcf/NA12878.g.vcf.gz.tbi	10127 bytes
logs/NA12878.bwa.log	5811 bytes
logs/NA12878.duplicate_metrics.txt	4079 bytes
logs/NA12878.fastp.html	485923 bytes
logs/NA12878.fastp.json	132027 bytes
logs/NA12878.fastp.log	1662 bytes
logs/NA12878.fastqc.log	208 bytes
logs/NA12878.flagstat.txt	527 bytes
logs/NA12878.haplotypecaller.log	9706 bytes
logs/NA12878.markduplicates.log	5375 bytes
logs/NA12878.samtools_sort.log	63 bytes
postprocess/NA12878.dedup.bam	132411752 bytes
postprocess/NA12878.dedup.bam.bai	1620280 bytes
postprocess/NA12878.sorted.bam	105854433 bytes
qc_raw/NA12878_R1_fastqc.html	581659 bytes
qc_raw/NA12878_R1_fastqc.zip	871775 bytes
qc_raw/NA12878_R2_fastqc.html	596171 bytes
qc_raw/NA12878_R2_fastqc.zip	897375 bytes
trim/NA12878_R1.fastq.gz	87230844 bytes
trim/NA12878_R2.fastq.gz	91236895 bytes
```

cancel-after-rerun:

```text
.state/NA12878.align.done	259 bytes
.state/NA12878.postprocess.done	259 bytes
.state/NA12878.qc_raw.done	259 bytes
.state/NA12878.quantify.done	259 bytes
.state/NA12878.trim.done	259 bytes
.state/NA12878.validate.done	259 bytes
align/NA12878.unsorted.bam	218552058 bytes
gvcf/NA12878.g.vcf.gz	22697507 bytes
gvcf/NA12878.g.vcf.gz.tbi	10127 bytes
logs/NA12878.bwa.log	5811 bytes
logs/NA12878.duplicate_metrics.txt	4079 bytes
logs/NA12878.fastp.html	485923 bytes
logs/NA12878.fastp.json	132027 bytes
logs/NA12878.fastp.log	1662 bytes
logs/NA12878.fastqc.log	208 bytes
logs/NA12878.flagstat.txt	527 bytes
logs/NA12878.haplotypecaller.log	9706 bytes
logs/NA12878.markduplicates.log	5375 bytes
logs/NA12878.samtools_sort.log	63 bytes
postprocess/NA12878.dedup.bam	132411752 bytes
postprocess/NA12878.dedup.bam.bai	1620280 bytes
postprocess/NA12878.sorted.bam	105854433 bytes
qc_raw/NA12878_R1_fastqc.html	581659 bytes
qc_raw/NA12878_R1_fastqc.zip	871775 bytes
qc_raw/NA12878_R2_fastqc.html	596171 bytes
qc_raw/NA12878_R2_fastqc.zip	897375 bytes
trim/NA12878_R1.fastq.gz	87230844 bytes
trim/NA12878_R2.fastq.gz	91236895 bytes
```



# Assignment 3: deliberate container experiments

## 1. Timing requirement incomplete

The assignment requires its two package-comparison builds a day apart. The second build and comparison are still pending. No day-apart comparison is claimed.

Completion requires a second build at least a day after the first, with both inventories and their diff retained.

## 2. Remove --bind

Command: submit slurm/a3-no-bind.sbatch for one sample into /scratch/roy.suc/w3-probe-no-bind. All explicit --bind options were removed from the pipeline call.

~~~text
10763556_1|FAILED|65:0|16|00:00:03|None
FILE: a3-no-bind_10763556_1.out
task=1 sample=NA12878 host=c0617 cpus=16 run=/scratch/roy.suc/w3-probe-no-bind
error: samplesheet missing or empty: /courses/BINF6610.202710/data/samplesheet-variant8.csv
MEMORY_PEAK_BYTES=35504128
~~~
The requested samplesheet is /courses/BINF6610.202710/data/samplesheet-variant8.csv and the output root is /scratch/roy.suc/w3-probe-no-bind. The excerpt records the actual missing path and stopping point, or a successful run if the site supplied those mounts. Fix: restore explicit bindings for the repository, /courses/BINF6610.202710, and /scratch/$USER.

## 3. Remove --env THREADS

Command: submit slurm/a3-no-threads.sbatch for one sample, omitting only --env THREADS. Requested cores: 16.

~~~text
[main] CMD: bwa mem -t 3 -R @RG\tID:NA12878\tSM:NA12878\tPL:ILLUMINA /courses/BINF6610.202710/data/refs/grch38-1000g/GRCh38_full_analysis_set_plus_decoy_hla.fa /scratch/roy.suc/w3-probe-no-threads/trim/NA12878_R1.fastq.gz /scratch/roy.suc/w3-probe-no-threads/trim/NA12878_R2.fastq.gz
18:01:03.014 INFO  IntelPairHmm - Available threads: 16
18:01:03.014 INFO  IntelPairHmm - Requested threads: 4
~~~

The observed -t value above is the alignment thread count. lib/common.sh has a default THREADS=4. This pipeline reserves one CPU for samtools conversion, so bwa uses one fewer alignment thread. The GATK lines, when present, record its actual requested threads. With --cleanenv, the omitted --env THREADS prevents the host's allocation from reaching this setting. Fix: restore --env THREADS and pass every job variable the pipeline reads.

~~~text
10763557_1|COMPLETED|0:0|16|00:10:21|None
FILE: a3-no-threads_10763557_1.out
task=1 sample=NA12878 host=c0638 cpus=16 run=/scratch/roy.suc/w3-probe-no-threads
[13:55:35] ===== NA12878: validate =====
[13:55:50] validation passed
[13:55:50] ===== NA12878: qc_raw =====
[13:56:17] NA12878: raw-read QC completed
[13:56:18] ===== NA12878: trim =====
[13:56:34] NA12878: trimming completed with 1222355 reads
[13:56:34] ===== NA12878: align =====
[14:00:24] NA12878: alignment produced 2447955 records
[14:00:24] ===== NA12878: postprocess =====
[14:01:00] NA12878: postprocessing completed with 2447955 records
[14:01:00] ===== NA12878: quantify =====
[14:05:45] NA12878: HaplotypeCaller produced 1575869 GVCF records
[14:05:45] NA12878: done
MEMORY_PEAK_BYTES=13649547264
~~~

## 4. Run an arm64 image on Explorer

Commands: apptainer pull --arch arm64 arm.sif docker://ubuntu:24.04; then apptainer exec --cleanenv arm.sif /bin/uname -m.

~~~text
10763558|COMPLETED|0:0|2|00:03:32|None
FILE: a3-architecture_10763558.out
COMMAND: apptainer pull --arch arm64 arm.sif docker://ubuntu:24.04
INFO:    Converting OCI blobs to SIF format
INFO:    Starting build...
Getting image source signatures
Copying blob sha256:90812e242c93750dbd37ce847c7d3db62c2c53035367d1d89c61184f168f5d37
Copying config sha256:95d16dfcd4ab8b61154e2280ab9fe4afa2ef03e5eefa8a689e86571e8a1b32cf
Writing manifest to image destination
Storing signatures
2026/10/02 13:55:37  info unpack layer: sha256:90812e242c93750dbd37ce847c7d3db62c2c53035367d1d89c61184f168f5d37
2026/10/02 13:55:39  warn xattr{etc/gshadow} ignoring ENOTSUP on setxattr "user.rootlesscontainers"
2026/10/02 13:55:39  warn xattr{/home/roy.suc/rstudio_tmp/build-temp-4110216852/rootfs/etc/gshadow} destination filesystem does not support xattrs, further warnings will be suppressed
INFO:    Creating SIF file...
ARM64_PULL_EXIT=0
COMMAND: apptainer exec --cleanenv arm.sif /bin/uname -m
FATAL:   While checking container encryption: could not open image /scratch/roy.suc/containers/arm-10763558.sif: the image's architecture (arm64) could not run on the host's (amd64)
ARM64_EXEC_EXIT=255
~~~

ARM64_PULL_EXIT and ARM64_EXEC_EXIT above record the actual outcomes. If the pull failed, the run was skipped and the pull error is the observed result. If it ran successfully, the host supported execution of this arm64 image; no execution error is invented. Fix for an incompatible image: build/pull linux/amd64.
