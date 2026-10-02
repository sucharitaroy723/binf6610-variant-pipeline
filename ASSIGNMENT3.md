# Assignment 3: prepared automation and remaining real runs

Due Friday, October 2, 2026, at 11:59 PM course local time. Submit the same
GitHub repository link used for Assignments 1 and 2.

The recipes and automation are prepared. No image has been built or pushed by
this kit yet, and no Explorer run or deliberate failure has been claimed.
The supplied official tests are unchanged.

## Start this today on your Mac

Download and unzip assignment3-kit.zip. In Terminal:

~~~bash
cd ~/Downloads/assignment3-kit
bash scripts/assignment3/mac.sh drift-start
~~~

Docker Desktop must be installed and running. This builds the deliberately
unpinned Ubuntu/curl image, saves the complete package inventory and build log,
and prints the earliest time for the second build. It is independent of
Assignment 2 and does not need a Docker Hub account.

At least 24 hours later, run:

~~~bash
cd ~/Downloads/assignment3-kit
bash scripts/assignment3/mac.sh drift-finish
~~~

The helper uses both --pull and --no-cache, saves the second inventory and every
changed line, and accepts an empty diff as an observed result. It refuses to
overwrite completed evidence or to count two immediate builds as a day apart.

## Install after Assignment 2 finishes

Finish Assignment 2's automated workflow and commit its results first. Its
cluster-run/ must contain the real conda VCF and manifest. RESOURCES.md must
contain the measured production array CPU count.

Transfer the kit from your Mac, replacing NETID with your Explorer username:

~~~bash
scp -r ~/Downloads/assignment3-kit NETID@login.explorer.northeastern.edu:~/
~~~

On Explorer, after SSH login:

~~~bash
cd ~/binf6610-variant-pipeline
git switch -c assignment3-container
python3 ~/assignment3-kit/scripts/assignment3/install.py "$PWD"
bash scripts/assignment3/export_pins.sh
~~~

The installer adapts your finished Assignment 2 job scripts. It preserves their
arguments and scheduling logic, replaces conda activation with apptainer exec,
passes THREADS, TMPDIR, REF, REGION, JAVA_TOOL_OPTIONS and both Slurm manifest
variables, and binds the repository, course directory and user scratch.
It saves the old scripts/configuration under docs/assignment3/week2/,
preserves the previous troubleshooting notes, and keeps the Assignment 2
acceptance suite as tests/run_acceptance_w02.sh. No analysis stage changes.

The container array uses the actual production CPU count from RESOURCES.md;
it does not substitute the original conservative default. If that report is
unavailable, provide --sample-cpus with the actual Assignment 2 count.
The installer refuses to run before the conda baseline exists.

The pin export reads the actual course environment and writes containers/env.yml
from it. If the course versions differ from the supplied rubric, it stops so the
discrepancy can be resolved before a build.

## Standard Docker route

On your Mac, copy the exported recipe and build/push the amd64 image:

~~~bash
scp NETID@login.explorer.northeastern.edu:~/binf6610-variant-pipeline/containers/env.yml ~/Downloads/assignment3-kit/containers/env.yml
cd ~/Downloads/assignment3-kit
bash scripts/assignment3/mac.sh build YOUR_DOCKERHUB_USERNAME
~~~

The helper checks all seven versions before pushing, captures the actual base
and pushed-image digests, and writes image-ref.txt and IMAGE.md from those
observations. Docker login is interactive on your Mac. Your Docker Hub account
must be verified, and variant-call must be public so Explorer can fetch it.

Copy the small metadata/evidence files to the repository on Explorer:

~~~bash
scp ~/Downloads/assignment3-kit/containers/image-ref.txt NETID@login.explorer.northeastern.edu:~/binf6610-variant-pipeline/containers/
scp -r ~/Downloads/assignment3-kit/evidence/assignment3/. NETID@login.explorer.northeastern.edu:~/binf6610-variant-pipeline/evidence/assignment3/
~~~

On Explorer, commit the prepared code before running:

~~~bash
cd ~/binf6610-variant-pipeline
git add containers scripts/assignment3 scripts/run_assignment3.sh slurm docs/assignment3 docs/assignment2-troubleshooting.md tests ASSIGNMENT3.md ASSIGNMENT3-REQUIREMENTS.md .gitignore
git commit -m "Containerize the variant pipeline for Assignment 3"
nohup bash scripts/run_assignment3.sh > assignment3-workflow.log 2>&1 &
~~~

Watch with tail -f assignment3-workflow.log. Ctrl-C stops watching. The
background workflow pulls by the pushed digest in a compute job, checks the
image against the real course environment, runs a fresh cohort, compares record
checksums, and submits the no-bind, missing-THREADS and arm64 experiments.
Sequencing analysis and image conversion run on compute nodes.

The driver saves job IDs and resumes them automatically when the same command
is launched again. It stops on unexpected production failures. A queue wait
timeout does not cancel the jobs. Correct a failed job before deliberately
starting a new workflow; repeated monitoring does not resubmit failed jobs.

If the record checksums differ, it preserves the observation and waits for an
evidence-backed explanation through --records-note. Do not invent a cause.
If the second Docker build is still pending, the cluster work remains saved.
Copy the complete two-day evidence from your Mac again, then rerun the driver
to generate the final reports and acceptance result.

## Instructor-permitted route without a main Docker image

The same package recipe is provided as containers/variant-call.def.
After installation and the course pin export, commit the prepared code and run:

~~~bash
nohup bash scripts/run_assignment3.sh --route apptainer > assignment3-workflow.log 2>&1 &
~~~

This builds the image on a compute node and documents the real build job ID
instead of inventing a pushed-image digest. The assignment permits this route
for the main image. The separate unpinned Docker exercise still calls for real
two-day Docker evidence; the fallback does not claim that exercise is waived.

## Final review and submission

After both days' Docker evidence and all Explorer jobs are complete:

~~~bash
cd ~/binf6610-variant-pipeline
bash scripts/run_assignment3.sh
bash tests/run_acceptance.sh .
git add IMAGE.md TROUBLESHOOTING.md cluster-run-container evidence/assignment3
git add -f cluster-run-container/cohort.filtered.vcf.gz
git commit -m "Record container cohort, versions and deliberate failure evidence"
git push -u origin assignment3-container
~~~

Use --route apptainer consistently if that was the selected route.
On macOS use /opt/homebrew/bin/bash for the official acceptance script; it needs
Bash 4.3 or newer.

Check for 100/100 and review the generated prose against its pasted evidence.
The five required files are cohort.filtered.vcf.gz, manifest.json,
versions-conda.txt, versions-image.txt and records-sha256.txt under
cluster-run-container/. IMAGE.md uses the three required headings.
TROUBLESHOOTING.md includes the four actual experiments and their evidence.
Full package inventories and selected job logs are included as supporting
evidence. SIFs, caches, BAMs and intermediate sequencing outputs stay outside
the repository. Keep cluster-run/ as the Assignment 2 baseline.

After reviewing and merging the assignment branch into main, submit:
https://github.com/sucharitaroy723/binf6610-variant-pipeline

Reference documentation:
https://docs.docker.com/reference/cli/docker/image/pull/
https://docs.docker.com/reference/cli/docker/image/ls/
https://apptainer.org/user-docs/master/environment_and_metadata.html
https://apptainer.org/docs/user/main/bind_paths_and_mounts.html
