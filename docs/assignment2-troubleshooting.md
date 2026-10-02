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

