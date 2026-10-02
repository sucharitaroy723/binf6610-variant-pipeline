#!/usr/bin/env python3
"""Run compute jobs and collect genuine Assignment 3 evidence on Explorer."""
import argparse
import csv
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
from support import recipe_pins, sha, write_image_doc

ROOT = Path(__file__).resolve().parents[2]
SLURM = ROOT / "slurm"
EVIDENCE = ROOT / "evidence/assignment3"
STATE = EVIDENCE / "workflow.json"
TERMINAL = {"COMPLETED", "FAILED", "CANCELLED", "TIMEOUT", "OUT_OF_MEMORY",
            "NODE_FAIL", "PREEMPTED", "BOOT_FAIL", "DEADLINE", "REVOKED"}
KEYS = ["PARTITION", "ACCOUNT", "SAMPLESHEET", "CONDA_ENV", "RUN_ROOT", "REF", "REGION", "SIF",
        "PER_SAMPLE_CPUS", "PER_SAMPLE_MEM", "PER_SAMPLE_TIME", "COHORT_CPUS", "COHORT_MEM", "COHORT_TIME"]


def command(args, cwd=ROOT, check=True):
    result = subprocess.run(list(map(str, args)), cwd=cwd, text=True, capture_output=True)
    if check and result.returncode:
        raise RuntimeError(" ".join(map(str, args)) + "\n" + result.stdout + result.stderr)
    return result


def config():
    script = 'source "$1"; printf "%s\\0" ' + " ".join('"$' + key + '"' for key in KEYS)
    values = command(["bash", "-c", script, "config", SLURM / "conf/slurm.env"]).stdout.split("\0")
    return dict(zip(KEYS, values))


def log(text):
    print(time.strftime("[%H:%M:%S] ") + text, flush=True)


def tail(text, lines=50):
    return "\n".join(text.splitlines()[-lines:])


class Workflow:
    def __init__(self, cfg, route, max_wait):
        self.cfg, self.route, self.max_wait = cfg, route, max_wait
        EVIDENCE.mkdir(parents=True, exist_ok=True)
        self.state = json.loads(STATE.read_text()) if STATE.exists() else {"jobs": {}, "route": route}
        if self.state["route"] != route:
            raise RuntimeError("Saved run used a different image route. Resume with that route.")
        self.run = Path(cfg["RUN_ROOT"])
        self.baseline = json.loads((ROOT / "docs/assignment3/baseline.json").read_text())

    def save(self):
        temp = STATE.with_suffix(".tmp")
        temp.write_text(json.dumps(self.state, indent=2) + "\n")
        temp.replace(STATE)

    def preflight(self):
        for tool in ["sbatch", "squeue", "sacct", "apptainer", "git", "bash"]:
            if not shutil.which(tool):
                raise RuntimeError("Run on Explorer after login; missing " + tool)
        for name, digest in self.baseline["code_sha256"].items():
            if sha(ROOT / name) != digest:
                raise RuntimeError("Analysis code changed since the baseline: " + name)
        for name, digest in [("cohort.filtered.vcf.gz", self.baseline["vcf_sha256"]),
                             ("manifest.json", self.baseline["manifest_sha256"])]:
            if sha(ROOT / "cluster-run" / name) != digest:
                raise RuntimeError("Assignment 2 baseline was modified: " + name)
        if int(self.cfg["PER_SAMPLE_CPUS"]) != self.baseline["sample_cpus"]:
            raise RuntimeError("Container array CPU count differs from the conda baseline.")
        manifest = self.baseline["manifest"]
        if manifest.get("reference", {}).get("genome") != self.cfg["REF"]:
            raise RuntimeError("Reference differs from the conda baseline.")
        if manifest.get("platform", {}).get("region", "") != self.cfg["REGION"]:
            raise RuntimeError("Region differs from the conda baseline.")
        old_cohort_cpus = manifest.get("platform", {}).get("slurm_cpus")
        if old_cohort_cpus and str(old_cohort_cpus) != self.cfg["COHORT_CPUS"]:
            raise RuntimeError("Cohort CPU count differs from the conda baseline.")
        with Path(self.cfg["SAMPLESHEET"]).open(newline="") as stream:
            rows = list(csv.DictReader(stream))
        if sorted(row["sample_id"] for row in rows) != sorted(row["sample_id"] for row in manifest["samples"]):
            raise RuntimeError("Samples differ from the conda baseline.")
        self.samples = len(rows)
        status = command(["git", "status", "--porcelain", "--untracked-files=no"]).stdout
        allowed = {"IMAGE.md", "TROUBLESHOOTING.md"}
        for line in status.splitlines():
            path = line[3:]
            if path not in allowed and not path.startswith(("cluster-run-container/", "evidence/assignment3/")):
                raise RuntimeError("Commit the prepared source before running. Modified tracked file: " + path)
        # Detect source edits during a resumable workflow, including wrappers and configuration.
        source_paths = [*SLURM.glob("*.sbatch"), SLURM / "conf/slurm.env",
                        ROOT / "containers/env.yml", ROOT / "containers/Dockerfile",
                        ROOT / "containers/variant-call.def"]
        hashes = {str(path.relative_to(ROOT)): sha(path) for path in source_paths}
        if "source_hashes" in self.state and self.state["source_hashes"] != hashes:
            raise RuntimeError("Prepared job/config/container source changed; inspect the saved jobs before restarting.")
        self.state["source_hashes"] = hashes
        self.state["git_sha"] = command(["git", "rev-parse", "HEAD"]).stdout.strip()
        if self.route == "docker":
            data = json.loads((EVIDENCE / "image.json").read_text())
            if data["env_sha256"] != sha(ROOT / "containers/env.yml") or data["dockerfile_sha256"] != sha(ROOT / "containers/Dockerfile"):
                raise RuntimeError("The pushed image was built from another recipe; rebuild and push.")
            reference = (ROOT / "containers/image-ref.txt").read_text().strip()
            if reference != data["pushed_image"]:
                raise RuntimeError("image-ref.txt differs from the observed push digest.")
        (SLURM / "logs").mkdir(exist_ok=True)
        self.save()

    def submit(self, label, script, cpus, mem, limit, args=(), array=None, dependency=None, run=None):
        if label in self.state["jobs"]:
            return self.state["jobs"][label]["id"]
        output = SLURM / "logs" / ("a3-" + label + ("_%A_%a" if array else "_%j") + ".out")
        call = ["sbatch", "--parsable", "-p", self.cfg["PARTITION"], "-A", self.cfg["ACCOUNT"],
                f"--cpus-per-task={cpus}", f"--mem={mem}", f"--time={limit}", f"--output={output}"]
        if array:
            call.append("--array=" + array)
        if dependency:
            call += ["--dependency=afterok:" + dependency, "--kill-on-invalid-dep=yes"]
        call += [script, *args]
        job = command(call, cwd=SLURM).stdout.strip().split(";")[0]
        if not re.fullmatch(r"\d+", job):
            raise RuntimeError("Unexpected sbatch response: " + job)
        self.state["jobs"][label] = {"id": job, "script": script, "cpus": int(cpus), "mem": mem,
                                     "time": limit, "run": str(run or ""), "array": array,
                                     "command": list(map(str, call))}
        self.save()
        log(f"{label}: submitted {job}")
        return job

    def accounting(self, label):
        job = self.state["jobs"][label]["id"]
        result = command(["sacct", "-X", "-j", job, "--parsable2", "--noheader",
                          "--format=JobID,State,ExitCode,AllocCPUS,Elapsed,Reason"], check=False)
        (EVIDENCE / (label + ".sacct.txt")).write_text(result.stdout + result.stderr)
        return [line.split("|") for line in result.stdout.splitlines() if "|" in line]

    def collect_logs(self, label):
        job = self.state["jobs"][label]["id"]
        parts = []
        for path in sorted((SLURM / "logs").glob("a3-" + label + "_" + job + "*.out")):
            parts.append("FILE: " + path.name + "\n" + path.read_text(errors="replace"))
        (EVIDENCE / (label + ".stdout.txt")).write_text("\n\n".join(parts))

    def wait(self, label, allow_failure=False):
        job = self.state["jobs"][label]["id"]
        deadline = time.monotonic() + self.max_wait
        last = None
        while time.monotonic() < deadline:
            queue = command(["squeue", "-h", "-j", job, "-o", "%i %T %R"], check=False)
            if queue.stdout.strip() and queue.stdout.strip() != last:
                last = queue.stdout.strip()
                log(label + ": " + last.replace("\n", "; "))
            rows = self.accounting(label)
            states = [row[1].split()[0].rstrip("+") for row in rows if len(row) >= 3]
            if not queue.stdout.strip() and states and all(state in TERMINAL for state in states):
                self.collect_logs(label)
                failed = [row for row in rows if row[1].split()[0].rstrip("+") != "COMPLETED" or row[2] != "0:0"]
                if failed and not allow_failure:
                    raise RuntimeError(f"{label} did not succeed. See evidence/assignment3/{label}.stdout.txt and .sacct.txt.")
                self.state["jobs"][label]["finished"] = rows
                self.save()
                log(label + ": " + ", ".join(states))
                return rows
            time.sleep(30)
        raise RuntimeError(f"Wait limit reached for {label}, job {job}. Existing jobs were not cancelled; rerun the same command to resume.")

    def cluster(self):
        if self.state.get("cluster_complete"):
            log("The saved cluster workflow is complete; collecting final reports.")
            return
        if "image" not in self.state["jobs"] and Path(self.cfg["SIF"]).exists():
            raise RuntimeError("An existing SIF has no provenance in this workflow. Use a new SIF path in slurm/conf/slurm.env.")
        image_script = "pull.sbatch" if self.route == "docker" else "build-container.sbatch"
        self.submit("image", image_script, 4 if self.route == "docker" else 8,
                    "16G" if self.route == "docker" else "24G", "03:00:00")
        self.wait("image")
        self.submit("versions", "verify-container.sbatch", 2, "4G", "00:30:00")
        self.wait("versions")
        if "array" not in self.state["jobs"] and self.run.exists() and any(self.run.iterdir()):
            raise RuntimeError("RUN_ROOT is not empty; choose a fresh container run directory.")
        array = self.submit("array", "01_persample.sbatch", self.cfg["PER_SAMPLE_CPUS"],
                            self.cfg["PER_SAMPLE_MEM"], self.cfg["PER_SAMPLE_TIME"],
                            args=[self.run], array=f"1-{self.samples}", run=self.run)
        self.submit("cohort", "02_cohort.sbatch", self.cfg["COHORT_CPUS"],
                    self.cfg["COHORT_MEM"], self.cfg["COHORT_TIME"],
                    args=[self.run], dependency=array, run=self.run)
        self.wait("array")
        self.wait("cohort")
        target = ROOT / "cluster-run-container"
        for name in ["cohort.filtered.vcf.gz", "manifest.json"]:
            source = self.run / "results" / name
            if not source.is_file() or not source.stat().st_size:
                raise RuntimeError("Missing container run output: " + str(source))
            shutil.copy2(source, target / name)
        manifest = json.loads((target / "manifest.json").read_text())
        if manifest.get("platform", {}).get("container") != self.cfg["SIF"]:
            raise RuntimeError("Run manifest does not identify the expected SIF.")
        if not re.fullmatch(r"[0-9a-f]{40}(?:-dirty)?", manifest.get("pipeline", {}).get("git_sha", "")):
            raise RuntimeError("Manifest has no valid code commit; inspect git inside the image.")
        self.submit("records", "compare-container.sbatch", 2, "4G", "00:30:00")
        self.wait("records")
        for label in ["no-bind", "no-threads"]:
            out = self.run.parent / ("w3-probe-" + label)
            if label not in self.state["jobs"] and out.exists() and any(out.iterdir()):
                raise RuntimeError("Probe output is not fresh: " + str(out))
            self.submit(label, "a3-" + label + ".sbatch", max(8, int(self.cfg["PER_SAMPLE_CPUS"])),
                        self.cfg["PER_SAMPLE_MEM"], self.cfg["PER_SAMPLE_TIME"],
                        args=[out], array="1", run=out)
        self.submit("architecture", "architecture-probe.sbatch", 2, "8G", "00:30:00")
        for label in ["no-bind", "no-threads", "architecture"]:
            self.wait(label, allow_failure=True)
        self.state["cluster_complete"] = True
        self.save()

    def finalize(self, records_note=None):
        target = ROOT / "cluster-run-container"
        hashes = re.findall(r"\b[0-9a-f]{64}\b", (target / "records-sha256.txt").read_text())[:2]
        if len(hashes) != 2:
            raise RuntimeError("Both observed record checksums are required.")
        if hashes[0] != hashes[1]:
            if records_note:
                self.state["records_note"] = records_note
                self.save()
            note = self.state.get("records_note")
            if not note:
                log("Record hashes differ. Inspect the evidence, then rerun with --records-note 'the actual explanation'.")
                return False
            (target / "records-sha256.txt").write_text(hashes[0] + "  -\n" + hashes[1] + "  -\n" + note + "\n")
        if self.route == "docker":
            write_image_doc(ROOT, data=json.loads((EVIDENCE / "image.json").read_text()))
        else:
            write_image_doc(ROOT, build_job=self.state["jobs"]["image"]["id"])
        drift = EVIDENCE / "docker-drift"
        if not (drift / "day1.json").exists() or not (drift / "day2.json").exists():
            log("Cluster work is complete. Docker breakage 1 is still pending; copy both days' evidence here and rerun to finalize.")
            return False
        day1, day2 = [json.loads((drift / name).read_text()) for name in ["day1.json", "day2.json"]]
        if day2["completed_epoch"] - day1["completed_epoch"] < 86400:
            raise RuntimeError("Docker builds were not a full day apart.")
        for name in ["day1-packages.txt", "day2-packages.txt", "packages.diff"]:
            if not (drift / name).is_file():
                raise RuntimeError("Missing Docker evidence: " + name)
        packages = (drift / "packages.diff").read_text()
        checked_diff = command(["diff", "-u", drift / "day1-packages.txt", drift / "day2-packages.txt"], check=False)
        # Inventory content must agree. diff's path/time headers change on transfer.
        def body(text):
            return "\n".join(line for line in text.splitlines() if not line.startswith(("--- ", "+++ ")))
        if checked_diff.returncode not in {0, 1} or body(checked_diff.stdout) != body(packages):
            raise RuntimeError("Saved package diff does not match the actual lists.")
        no_bind = self.state["jobs"]["no-bind"]
        no_threads = self.state["jobs"]["no-threads"]
        architecture = (EVIDENCE / "architecture.stdout.txt").read_text()
        pull_status = re.search(r"ARM64_PULL_EXIT=(\d+)", architecture)
        if not pull_status:
            raise RuntimeError("Architecture probe has no observed pull status; inspect its Slurm failure before reporting.")
        if pull_status.group(1) == "0" and not re.search(r"ARM64_EXEC_EXIT=\d+", architecture):
            raise RuntimeError("Architecture image pulled, but its execution outcome was not captured.")
        bwa, gatk = [], []
        logs = Path(no_threads["run"]) / "logs"
        for path in logs.glob("*.bwa.log"):
            text = path.read_text(errors="replace")
            for line in text.splitlines():
                if "[main] CMD:" in line:
                    bwa.append(line)
        for path in logs.glob("*haplotypecaller.log"):
            gatk += [line for line in path.read_text(errors="replace").splitlines()
                     if "Available threads" in line or "Requested threads" in line]
        if not bwa:
            raise RuntimeError("No observed bwa thread command in the missing-THREADS probe. Inspect the probe failure before reporting.")
        (EVIDENCE / "no-threads.tool-excerpts.txt").write_text("\n".join(bwa + gatk) + "\n")
        old_notes = (ROOT / "docs/assignment2-troubleshooting.md").read_text()
        def evidence(label):
            account = (EVIDENCE / (label + ".sacct.txt")).read_text()
            output = (EVIDENCE / (label + ".stdout.txt")).read_text()
            return "~~~text\n" + account + tail(output) + "\n~~~\n"
        report = "\n\n# Assignment 3: deliberate container experiments\n\n"
        report += "## 1. Unpinned image and packages, two builds a day apart\n\n"
        report += ("Commands: docker build -t binf6610-drift:day1 with FROM ubuntu and apt-get install -y curl; "
                   "then docker build --pull --no-cache -t binf6610-drift:day2. "
                   "Both images were inspected with docker run --rm IMAGE dpkg -l.\n\n")
        report += "Observed build completion times (Unix seconds): " + str(day1["completed_epoch"]) + ", " + str(day2["completed_epoch"]) + ".\n\n"
        report += ("Complete inventories: [day 1](evidence/assignment3/docker-drift/day1-packages.txt) and "
                   "[day 2](evidence/assignment3/docker-drift/day2-packages.txt). Every differing line:\n\n")
        report += "~~~diff\n" + (packages if packages else "No package-list lines differed in the two observed builds.\n") + "~~~\n\n"
        report += "Fix: pin the base image and package versions, and preserve the pushed image digest. Unchanged packages during one day do not guarantee later reproducibility.\n\n"
        report += "## 2. Remove --bind\n\n"
        report += f"Command: submit slurm/a3-no-bind.sbatch for one sample into {no_bind['run']}. All explicit --bind options were removed from the pipeline call.\n\n"
        report += evidence("no-bind")
        report += ("The requested samplesheet is " + self.cfg["SAMPLESHEET"] + " and the output root is " + no_bind["run"] +
                   ". The excerpt records the actual missing path and stopping point, or a successful run if the site supplied those mounts. "
                   "Fix: restore explicit bindings for the repository, /courses/BINF6610.202710, and /scratch/$USER.\n\n")
        report += "## 3. Remove --env THREADS\n\n"
        report += f"Command: submit slurm/a3-no-threads.sbatch for one sample, omitting only --env THREADS. Requested cores: {no_threads['cpus']}.\n\n"
        report += "~~~text\n" + "\n".join(bwa + gatk) + "\n~~~\n\n"
        common = (ROOT / "lib/common.sh").read_text()
        default = re.search(r"(?m)^THREADS=\$\{THREADS:-([0-9]+)\}", common)
        report += "The observed -t value above is the alignment thread count. "
        if default:
            report += "lib/common.sh has a default THREADS=" + default.group(1) + ". "
        if "THREADS - 1" in common:
            report += "This pipeline reserves one CPU for samtools conversion, so bwa uses one fewer alignment thread. "
        report += ("The GATK lines, when present, record its actual requested threads. With --cleanenv, "
                   "the omitted --env THREADS prevents the host's allocation from reaching this setting. "
                   "Fix: restore --env THREADS and pass every job variable the pipeline reads.\n\n")
        report += evidence("no-threads") + "\n"
        report += "## 4. Run an arm64 image on Explorer\n\n"
        report += "Commands: apptainer pull --arch arm64 arm.sif docker://ubuntu:24.04; then apptainer exec --cleanenv arm.sif /bin/uname -m.\n\n"
        report += evidence("architecture")
        report += ("\nARM64_PULL_EXIT and ARM64_EXEC_EXIT above record the actual outcomes. If the pull failed, the run was "
                   "skipped and the pull error is the observed result. If it ran successfully, the host supported execution "
                   "of this arm64 image; no execution error is invented. Fix for an incompatible image: build/pull linux/amd64.\n")
        (ROOT / "TROUBLESHOOTING.md").write_text(old_notes + report)
        result = command(["bash", ROOT / "tests/run_acceptance.sh", ROOT], check=False)
        (EVIDENCE / "acceptance.txt").write_text(result.stdout + result.stderr)
        print(result.stdout, flush=True)
        if result.returncode or "100/100 points" not in result.stdout:
            raise RuntimeError("Assignment 3 checks are not complete; inspect evidence/assignment3/acceptance.txt.")
        self.state["complete"] = True
        self.save()
        log("All eight acceptance checks passed, 100/100. Review and commit the actual deliverables.")
        return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--route", choices=["docker", "apptainer"], default="docker")
    parser.add_argument("--max-wait-hours", type=float, default=12)
    parser.add_argument("--records-note", help="evidence-backed explanation if the two record hashes differ")
    args = parser.parse_args()
    if args.max_wait_hours <= 0:
        parser.error("--max-wait-hours must be positive")
    cfg = config()
    flow = Workflow(cfg, args.route, args.max_wait_hours * 3600)
    flow.preflight()
    if not (EVIDENCE / "course-pins.txt").exists():
        raise RuntimeError("First run on Explorer: bash scripts/assignment3/export_pins.sh")
    flow.cluster()
    flow.finalize(args.records_note)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        log("STOPPED: " + str(error))
        raise SystemExit(1)
