# Assignment 2 resource measurements

Recorded from Explorer jobs; no demo measurements were reused.

| Run / task | Cores requested | Memory requested | Time limit | Wall (s) | CPU (s) | Cores busy | MaxRSS (GiB) | Largest observed peak (GiB) |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| cores-4 / 10728098_1 | 4 | 32G | 02:00:00 | 772 | 1587.7 | 2.06 | 7.49 | 7.51 |
| cores-8 / 10728229_1 | 8 | 32G | 02:00:00 | 537 | 1495.3 | 2.78 | 6.30 | 7.95 |
| cores-16 / 10728323_1 | 16 | 32G | 02:00:00 | 420 | 1584.7 | 3.77 | 6.78 | 13.32 |
| probe-three / 10728417_1 | 16 | 32G | 02:00:00 | 420 | 1604.9 | 3.82 | 6.78 | 13.30 |
| probe-three / 10728417_2 | 16 | 32G | 02:00:00 | 435 | 1693.5 | 3.89 | 6.79 | 13.46 |
| probe-three / 10728417_3 | 16 | 32G | 02:00:00 | 324 | 1162.4 | 3.59 | 5.65 | 10.87 |
| full-array / 10728510_1 | 16 | 24G | 00:30:00 | 420 | 1596.8 | 3.80 | 6.77 | 12.63 |
| full-array / 10728510_2 | 16 | 24G | 00:30:00 | 436 | 1701.2 | 3.90 | 6.79 | 13.19 |
| full-array / 10728510_3 | 16 | 24G | 00:30:00 | 331 | 1170.6 | 3.54 | 5.87 | 10.94 |
| full-array / 10728510_4 | 16 | 24G | 00:30:00 | 388 | 1503.8 | 3.88 | 12.46 | 13.35 |
| full-array / 10728510_5 | 16 | 24G | 00:30:00 | 331 | 1120.0 | 3.38 | 4.39 | 11.59 |
| full-array / 10728510_6 | 16 | 24G | 00:30:00 | 422 | 1571.6 | 3.72 | 6.84 | 12.89 |
| full-array / 10728510_7 | 16 | 24G | 00:30:00 | 643 | 2325.8 | 3.62 | 7.45 | 14.16 |
| full-array / 10728510_8 | 16 | 24G | 00:30:00 | 509 | 1879.7 | 3.69 | 7.20 | 14.64 |
| full-cohort / 10728518 | 2 | 32G | 01:00:00 | 524 | 510.4 | 0.97 | 1.37 | 1.37 |

The initial probes requested 32G and 02:00:00. I chose 16 cores: the smallest measured request within 15% of the fastest wall time. I reduced the per-sample request from 32G and 02:00:00 to --mem=24G and --time=00:30:00, allowing at least 75% headroom over the largest probe memory peak (13.46 GiB) and twice the longest probe runtime (at least 30 minutes). The largest observed peak is the greater of sampled MaxRSS and the cgroup high-water mark when available; The two memory measurements can differ, so I used the larger value. The cohort ran with a separate generous request of 2 cores, 32G, and 01:00:00; its measurement is shown above. These decisions were passed to sbatch by the driver; the configuration file retains the conservative manual-submission defaults.

## cores-4

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728098_1|COMPLETED|0:0|772|26:27.692||4|32G|None
10728098_1.batch|COMPLETED|0:0|772|26:27.691|7856416K|4||
10728098_1.extern|COMPLETED|0:0|773|00:00.001|256K|4||
```

```text
persample_10728098_1.out:
[00:39:06] ===== NA12878: validate =====
[00:39:18] validation passed
[00:39:18] ===== NA12878: qc_raw =====
[00:39:49] NA12878: raw-read QC completed
[00:39:49] ===== NA12878: trim =====
[00:40:06] NA12878: trimming completed with 1222355 reads
[00:40:06] ===== NA12878: align =====
[00:45:26] NA12878: alignment produced 2447955 records
[00:45:26] ===== NA12878: postprocess =====
[00:46:03] NA12878: postprocessing completed with 2447955 records
[00:46:03] ===== NA12878: quantify =====
[00:51:42] NA12878: HaplotypeCaller produced 1575869 GVCF records
[00:51:42] NA12878: done
MEMORY_PEAK_BYTES=8060174336
```

```text
Job ID: 10728098
Array Job ID: 10728098_1
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 4
CPU Utilized: 00:26:28
CPU Efficiency: 51.42% of 00:51:28 core-walltime
Job Wall-clock time: 00:12:52
Memory Utilized: 7.49 GB
Memory Efficiency: 23.41% of 32.00 GB
```

## cores-8

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728229_1|COMPLETED|0:0|537|24:55.262||8|32G|None
10728229_1.batch|COMPLETED|0:0|537|24:55.261|6610292K|8||
10728229_1.extern|COMPLETED|0:0|537|00:00.001|256K|8||
```

```text
persample_10728229_1.out:
[00:52:11] ===== NA12878: validate =====
[00:52:24] validation passed
[00:52:24] ===== NA12878: qc_raw =====
[00:52:49] NA12878: raw-read QC completed
[00:52:49] ===== NA12878: trim =====
[00:53:03] NA12878: trimming completed with 1222355 reads
[00:53:03] ===== NA12878: align =====
[00:54:56] NA12878: alignment produced 2447955 records
[00:54:56] ===== NA12878: postprocess =====
[00:55:26] NA12878: postprocessing completed with 2447955 records
[00:55:26] ===== NA12878: quantify =====
[01:00:58] NA12878: HaplotypeCaller produced 1575865 GVCF records
[01:00:58] NA12878: done
MEMORY_PEAK_BYTES=8538505216
```

```text
Job ID: 10728229
Array Job ID: 10728229_1
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 8
CPU Utilized: 00:24:55
CPU Efficiency: 34.80% of 01:11:36 core-walltime
Job Wall-clock time: 00:08:57
Memory Utilized: 6.30 GB
Memory Efficiency: 19.70% of 32.00 GB
```

## cores-16

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728323_1|COMPLETED|0:0|420|26:24.701||16|32G|None
10728323_1.batch|COMPLETED|0:0|420|26:24.699|7110288K|16||
10728323_1.extern|COMPLETED|0:0|420|00:00.001|256K|16||
```

```text
persample_10728323_1.out:
[01:01:28] ===== NA12878: validate =====
[01:01:42] validation passed
[01:01:42] ===== NA12878: qc_raw =====
[01:02:11] NA12878: raw-read QC completed
[01:02:11] ===== NA12878: trim =====
[01:02:23] NA12878: trimming completed with 1222355 reads
[01:02:23] ===== NA12878: align =====
[01:03:15] NA12878: alignment produced 2447955 records
[01:03:15] ===== NA12878: postprocess =====
[01:03:40] NA12878: postprocessing completed with 2447955 records
[01:03:40] ===== NA12878: quantify =====
[01:08:17] NA12878: HaplotypeCaller produced 1575865 GVCF records
[01:08:17] NA12878: done
MEMORY_PEAK_BYTES=14301278208
```

```text
Job ID: 10728323
Array Job ID: 10728323_1
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:26:25
CPU Efficiency: 23.59% of 01:52:00 core-walltime
Job Wall-clock time: 00:07:00
Memory Utilized: 6.78 GB
Memory Efficiency: 21.19% of 32.00 GB
```

## probe-three

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728417_1|COMPLETED|0:0|420|26:44.888||16|32G|None
10728417_1.batch|COMPLETED|0:0|420|26:44.886|7112948K|16||
10728417_1.extern|COMPLETED|0:0|420|00:00.001|256K|16||
10728417_2|COMPLETED|0:0|435|28:13.502||16|32G|None
10728417_2.batch|COMPLETED|0:0|435|28:13.501|7122216K|16||
10728417_2.extern|COMPLETED|0:0|435|00:00.001|256K|16||
10728417_3|COMPLETED|0:0|324|19:22.422||16|32G|None
10728417_3.batch|COMPLETED|0:0|324|19:22.421|5923540K|16||
10728417_3.extern|COMPLETED|0:0|324|00:00.001|256K|16||
```

```text
persample_10728417_1.out:
[01:08:41] ===== NA12878: validate =====
[01:08:55] validation passed
[01:08:55] ===== NA12878: qc_raw =====
[01:09:27] NA12878: raw-read QC completed
[01:09:27] ===== NA12878: trim =====
[01:09:39] NA12878: trimming completed with 1222355 reads
[01:09:39] ===== NA12878: align =====
[01:10:32] NA12878: alignment produced 2447955 records
[01:10:32] ===== NA12878: postprocess =====
[01:10:57] NA12878: postprocessing completed with 2447955 records
[01:10:57] ===== NA12878: quantify =====
[01:15:34] NA12878: HaplotypeCaller produced 1575865 GVCF records
[01:15:34] NA12878: done
MEMORY_PEAK_BYTES=14281478144
```

```text
persample_10728417_2.out:
[01:08:40] ===== NA12891: validate =====
[01:08:55] validation passed
[01:08:55] ===== NA12891: qc_raw =====
[01:09:21] NA12891: raw-read QC completed
[01:09:21] ===== NA12891: trim =====
[01:09:34] NA12891: trimming completed with 1247760 reads
[01:09:34] ===== NA12891: align =====
[01:10:30] NA12891: alignment produced 2499007 records
[01:10:30] ===== NA12891: postprocess =====
[01:10:56] NA12891: postprocessing completed with 2499007 records
[01:10:56] ===== NA12891: quantify =====
[01:15:47] NA12891: HaplotypeCaller produced 1635411 GVCF records
[01:15:47] NA12891: done
MEMORY_PEAK_BYTES=14448250880
```

```text
persample_10728417_3.out:
[01:08:40] ===== NA12892: validate =====
[01:08:45] validation passed
[01:08:45] ===== NA12892: qc_raw =====
[01:08:59] NA12892: raw-read QC completed
[01:09:00] ===== NA12892: trim =====
[01:09:31] NA12892: trimming completed with 1257860 reads
[01:09:32] ===== NA12892: align =====
[01:10:05] NA12892: alignment produced 1259481 records
[01:10:05] ===== NA12892: postprocess =====
[01:10:24] NA12892: postprocessing completed with 1259481 records
[01:10:24] ===== NA12892: quantify =====
[01:13:57] NA12892: HaplotypeCaller produced 1919601 GVCF records
[01:13:57] NA12892: done
MEMORY_PEAK_BYTES=11670413312
```

```text
Job ID: 10728419
Array Job ID: 10728417_1
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:26:45
CPU Efficiency: 23.88% of 01:52:00 core-walltime
Job Wall-clock time: 00:07:00
Memory Utilized: 6.78 GB
Memory Efficiency: 21.20% of 32.00 GB
```

```text
Job ID: 10728420
Array Job ID: 10728417_2
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:28:14
CPU Efficiency: 24.34% of 01:56:00 core-walltime
Job Wall-clock time: 00:07:15
Memory Utilized: 6.79 GB
Memory Efficiency: 21.23% of 32.00 GB
```

```text
Job ID: 10728417
Array Job ID: 10728417_3
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:19:22
CPU Efficiency: 22.42% of 01:26:24 core-walltime
Job Wall-clock time: 00:05:24
Memory Utilized: 5.65 GB
Memory Efficiency: 17.65% of 32.00 GB
```

## full-array

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728510_1|COMPLETED|0:0|420|26:36.761||16|24G|None
10728510_1.batch|COMPLETED|0:0|420|26:36.760|7095936K|16||
10728510_1.extern|COMPLETED|0:0|420|00:00.001|256K|16||
10728510_2|COMPLETED|0:0|436|28:21.186||16|24G|None
10728510_2.batch|COMPLETED|0:0|436|28:21.184|7118060K|16||
10728510_2.extern|COMPLETED|0:0|436|00:00.001|256K|16||
10728510_3|COMPLETED|0:0|331|19:30.605||16|24G|None
10728510_3.batch|COMPLETED|0:0|331|19:30.604|6153484K|16||
10728510_3.extern|COMPLETED|0:0|331|00:00.001|256K|16||
10728510_4|COMPLETED|0:0|388|25:03.848||16|24G|None
10728510_4.batch|COMPLETED|0:0|388|25:03.847|13067692K|16||
10728510_4.extern|COMPLETED|0:0|388|00:00.001|256K|16||
10728510_5|COMPLETED|0:0|331|18:39.981||16|24G|None
10728510_5.batch|COMPLETED|0:0|331|18:39.979|4599564K|16||
10728510_5.extern|COMPLETED|0:0|331|00:00.001|256K|16||
10728510_6|COMPLETED|0:0|422|26:11.595||16|24G|None
10728510_6.batch|COMPLETED|0:0|422|26:11.594|7173496K|16||
10728510_6.extern|COMPLETED|0:0|422|00:00.001|256K|16||
10728510_7|COMPLETED|0:0|643|38:45.777||16|24G|None
10728510_7.batch|COMPLETED|0:0|643|38:45.776|7816036K|16||
10728510_7.extern|COMPLETED|0:0|643|00:00.001|256K|16||
10728510_8|COMPLETED|0:0|509|31:19.720||16|24G|None
10728510_8.batch|COMPLETED|0:0|509|31:19.719|7551844K|16||
10728510_8.extern|COMPLETED|0:0|510|00:00.001|256K|16||
```

```text
persample_10728510_1.out:
[01:16:17] ===== NA12878: validate =====
[01:16:31] validation passed
[01:16:31] ===== NA12878: qc_raw =====
[01:17:02] NA12878: raw-read QC completed
[01:17:02] ===== NA12878: trim =====
[01:17:14] NA12878: trimming completed with 1222355 reads
[01:17:14] ===== NA12878: align =====
[01:18:06] NA12878: alignment produced 2447955 records
[01:18:07] ===== NA12878: postprocess =====
[01:18:32] NA12878: postprocessing completed with 2447955 records
[01:18:32] ===== NA12878: quantify =====
[01:23:09] NA12878: HaplotypeCaller produced 1575865 GVCF records
[01:23:09] NA12878: done
MEMORY_PEAK_BYTES=13566709760
```

```text
persample_10728510_2.out:
[01:16:16] ===== NA12891: validate =====
[01:16:30] validation passed
[01:16:30] ===== NA12891: qc_raw =====
[01:16:57] NA12891: raw-read QC completed
[01:16:57] ===== NA12891: trim =====
[01:17:10] NA12891: trimming completed with 1247760 reads
[01:17:10] ===== NA12891: align =====
[01:18:07] NA12891: alignment produced 2499007 records
[01:18:07] ===== NA12891: postprocess =====
[01:18:35] NA12891: postprocessing completed with 2499007 records
[01:18:35] ===== NA12891: quantify =====
[01:23:25] NA12891: HaplotypeCaller produced 1635411 GVCF records
[01:23:25] NA12891: done
MEMORY_PEAK_BYTES=14159360000
```

```text
persample_10728510_3.out:
[01:16:15] ===== NA12892: validate =====
[01:16:20] validation passed
[01:16:20] ===== NA12892: qc_raw =====
[01:16:33] NA12892: raw-read QC completed
[01:16:33] ===== NA12892: trim =====
[01:17:05] NA12892: trimming completed with 1257860 reads
[01:17:05] ===== NA12892: align =====
[01:17:39] NA12892: alignment produced 1259481 records
[01:17:39] ===== NA12892: postprocess =====
[01:17:55] NA12892: postprocessing completed with 1259481 records
[01:17:55] ===== NA12892: quantify =====
[01:21:31] NA12892: HaplotypeCaller produced 1919601 GVCF records
[01:21:31] NA12892: done
MEMORY_PEAK_BYTES=11748929536
```

```text
persample_10728510_4.out:
[01:16:15] ===== NA07357: validate =====
[01:16:28] validation passed
[01:16:28] ===== NA07357: qc_raw =====
[01:16:54] NA07357: raw-read QC completed
[01:16:54] ===== NA07357: trim =====
[01:17:05] NA07357: trimming completed with 1120318 reads
[01:17:05] ===== NA07357: align =====
[01:17:56] NA07357: alignment produced 2243602 records
[01:17:56] ===== NA07357: postprocess =====
[01:18:19] NA07357: postprocessing completed with 2243602 records
[01:18:20] ===== NA07357: quantify =====
[01:22:36] NA07357: HaplotypeCaller produced 1746762 GVCF records
[01:22:36] NA07357: done
MEMORY_PEAK_BYTES=14331269120
```

```text
persample_10728510_5.out:
[01:16:24] ===== NA12003: validate =====
[01:16:29] validation passed
[01:16:29] ===== NA12003: qc_raw =====
[01:16:47] NA12003: raw-read QC completed
[01:16:47] ===== NA12003: trim =====
[01:17:14] NA12003: trimming completed with 1355375 reads
[01:17:14] ===== NA12003: align =====
[01:17:44] NA12003: alignment produced 1357438 records
[01:17:44] ===== NA12003: postprocess =====
[01:18:00] NA12003: postprocessing completed with 1357438 records
[01:18:00] ===== NA12003: quantify =====
[01:21:29] NA12003: HaplotypeCaller produced 2035587 GVCF records
[01:21:29] NA12003: done
MEMORY_PEAK_BYTES=12442726400
```

```text
persample_10728510_6.out:
[01:16:33] ===== NA10851: validate =====
[01:16:47] validation passed
[01:16:47] ===== NA10851: qc_raw =====
[01:17:17] NA10851: raw-read QC completed
[01:17:17] ===== NA10851: trim =====
[01:17:30] NA10851: trimming completed with 1239530 reads
[01:17:30] ===== NA10851: align =====
[01:18:23] NA10851: alignment produced 2482843 records
[01:18:23] ===== NA10851: postprocess =====
[01:18:48] NA10851: postprocessing completed with 2482843 records
[01:18:49] ===== NA10851: quantify =====
[01:23:11] NA10851: HaplotypeCaller produced 1526602 GVCF records
[01:23:11] NA10851: done
MEMORY_PEAK_BYTES=13840404480
```

```text
persample_10728510_7.out:
[01:16:25] ===== NA12813: validate =====
[01:16:49] validation passed
[01:16:49] ===== NA12813: qc_raw =====
[01:17:34] NA12813: raw-read QC completed
[01:17:34] ===== NA12813: trim =====
[01:17:57] NA12813: trimming completed with 2065252 reads
[01:17:57] ===== NA12813: align =====
[01:19:28] NA12813: alignment produced 4135722 records
[01:19:28] ===== NA12813: postprocess =====
[01:20:15] NA12813: postprocessing completed with 4135722 records
[01:20:15] ===== NA12813: quantify =====
[01:26:51] NA12813: HaplotypeCaller produced 223676 GVCF records
[01:26:51] NA12813: done
MEMORY_PEAK_BYTES=15206690816
```

```text
persample_10728510_8.out:
[01:16:24] ===== NA12873: validate =====
[01:16:42] validation passed
[01:16:42] ===== NA12873: qc_raw =====
[01:17:14] NA12873: raw-read QC completed
[01:17:14] ===== NA12873: trim =====
[01:17:30] NA12873: trimming completed with 1490067 reads
[01:17:30] ===== NA12873: align =====
[01:18:39] NA12873: alignment produced 2983854 records
[01:18:39] ===== NA12873: postprocess =====
[01:19:11] NA12873: postprocessing completed with 2983854 records
[01:19:11] ===== NA12873: quantify =====
[01:24:31] NA12873: HaplotypeCaller produced 1203636 GVCF records
[01:24:31] NA12873: done
MEMORY_PEAK_BYTES=15718957056
```

```text
Job ID: 10728511
Array Job ID: 10728510_1
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:26:37
CPU Efficiency: 23.76% of 01:52:00 core-walltime
Job Wall-clock time: 00:07:00
Memory Utilized: 6.77 GB
Memory Efficiency: 28.20% of 24.00 GB
```

```text
Job ID: 10728512
Array Job ID: 10728510_2
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:28:21
CPU Efficiency: 24.38% of 01:56:16 core-walltime
Job Wall-clock time: 00:07:16
Memory Utilized: 6.79 GB
Memory Efficiency: 28.28% of 24.00 GB
```

```text
Job ID: 10728513
Array Job ID: 10728510_3
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:19:31
CPU Efficiency: 22.11% of 01:28:16 core-walltime
Job Wall-clock time: 00:05:31
Memory Utilized: 5.87 GB
Memory Efficiency: 24.45% of 24.00 GB
```

```text
Job ID: 10728514
Array Job ID: 10728510_4
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:25:04
CPU Efficiency: 24.23% of 01:43:28 core-walltime
Job Wall-clock time: 00:06:28
Memory Utilized: 12.46 GB
Memory Efficiency: 51.93% of 24.00 GB
```

```text
Job ID: 10728515
Array Job ID: 10728510_5
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:18:40
CPU Efficiency: 21.15% of 01:28:16 core-walltime
Job Wall-clock time: 00:05:31
Memory Utilized: 4.39 GB
Memory Efficiency: 18.28% of 24.00 GB
```

```text
Job ID: 10728516
Array Job ID: 10728510_6
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:26:12
CPU Efficiency: 23.28% of 01:52:32 core-walltime
Job Wall-clock time: 00:07:02
Memory Utilized: 6.84 GB
Memory Efficiency: 28.50% of 24.00 GB
```

```text
Job ID: 10728517
Array Job ID: 10728510_7
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:38:46
CPU Efficiency: 22.61% of 02:51:28 core-walltime
Job Wall-clock time: 00:10:43
Memory Utilized: 7.45 GB
Memory Efficiency: 31.06% of 24.00 GB
```

```text
Job ID: 10728510
Array Job ID: 10728510_8
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:31:20
CPU Efficiency: 23.08% of 02:15:44 core-walltime
Job Wall-clock time: 00:08:29
Memory Utilized: 7.20 GB
Memory Efficiency: 30.01% of 24.00 GB
```

## full-cohort

```text
JobID|State|ExitCode|ElapsedRaw|TotalCPU|MaxRSS|AllocCPUS|ReqMem|Reason
10728518|COMPLETED|0:0|524|08:30.417||2|32G|Dependency
10728518.batch|COMPLETED|0:0|524|08:30.416|1434232K|2||
10728518.extern|COMPLETED|0:0|524|00:00.001|256K|2||
```

```text
cohort_10728518.out:
[01:27:10] trim: every sample already completed
[01:27:11] align: every sample already completed
[01:27:11] postprocess: every sample already completed
[01:27:11] quantify: every sample already completed
[01:27:11] ===== cohort: merge =====
[01:32:22] individual GVCFs combined successfully
[01:34:55] joint genotyping completed with 8 samples and 36853 variant records
[01:34:55] ===== cohort: analyze =====
[01:35:02] hard filtering completed: 36853 total, 36077 PASS, 776 flagged
[01:35:02] ===== cohort: qc_report =====
[01:35:27] MultiQC report created at /scratch/roy.suc/w2-variant/20261001-003850-2228995/production/results/multiqc_report.html
[01:35:27] ===== cohort: publish =====
[01:35:36] done
MEMORY_PEAK_BYTES=1469722624
```

```text
Job ID: 10728518
Cluster: explorer
User/Group: roy.suc/users
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 2
CPU Utilized: 00:08:30
CPU Efficiency: 48.66% of 00:17:28 core-walltime
Job Wall-clock time: 00:08:44
Memory Utilized: 1.37 GB
Memory Efficiency: 4.27% of 32.00 GB
```

