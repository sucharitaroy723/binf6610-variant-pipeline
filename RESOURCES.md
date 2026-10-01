# Assignment 2 resource measurements

Pending: the Explorer automation has not run yet. No measurements are claimed.

Run `bash scripts/run_assignment2.sh`. It benchmarks sample 1 at 4, 8, and 16
cores in separate fresh directories and probes samples 1-3 at 16 cores, 32 GiB,
and a two-hour limit. It records real `seff`, `sacct`, and available cgroup peaks.
It then chooses the smallest core count within 15% of the fastest measured time,
adds memory/time headroom, and runs the full cohort.

The automation replaces this pending section with a measured table and the
decisions it made. Review the evidence before committing. The initial settings
in `slurm/conf/slurm.env` are generous starting requests, not measured choices.
