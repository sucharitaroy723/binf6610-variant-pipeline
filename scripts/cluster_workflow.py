#!/usr/bin/env python3
"""Submit cluster jobs, collect genuine evidence, and prepare Assignment 2 reports.

Only orchestration and small metadata reads happen on the login node.
Every sequencing-data operation happens in a submitted compute job.
"""
import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

REPO = Path(__file__).resolve().parents[1]
SLURM = REPO / "slurm"
IDS = {"NA12878", "NA12891", "NA12892", "NA07357", "NA12003", "NA10851", "NA12813", "NA12873"}
TERMINAL = {"COMPLETED", "FAILED", "CANCELLED", "TIMEOUT", "OUT_OF_MEMORY", "NODE_FAIL", "PREEMPTED", "BOOT_FAIL", "DEADLINE", "REVOKED"}
FIELDS = "JobID,State,ExitCode,ElapsedRaw,TotalCPU,MaxRSS,AllocCPUS,ReqMem,Reason"


def command(args, cwd=REPO, check=True):
    result = subprocess.run([str(a) for a in args], cwd=cwd, text=True, capture_output=True)
    if check and result.returncode:
        raise RuntimeError(f"{' '.join(map(str, args))}\n{result.stdout}{result.stderr}")
    return result


def config():
    keys = ["PARTITION", "ACCOUNT", "SAMPLESHEET", "CONDA_ENV", "RUN_ROOT", "REF", "REGION"]
    shell = 'source "$1"; printf "%s\\0" ' + " ".join('"$' + k + '"' for k in keys)
    values = command(["bash", "-c", shell, "config", SLURM / "conf/slurm.env"]).stdout.split("\0")
    return dict(zip(keys, values))


def seconds(value):
    if not value or value in {"Unknown", "N/A"}:
        return 0.0
    days, _, value = value.rpartition("-") if "-" in value else ("0", "", value)
    total = 0.0
    for part in value.split(":"):
        total = total * 60 + float(part)
    return int(days) * 86400 + total


def memory_bytes(value):
    match = re.fullmatch(r"([0-9.]+)([KMGTP]?)(?:[cn])?", value or "")
    if not match:
        return 0
    return float(match[1]) * 1024 ** ("KMGTP".find(match[2]) + 1 if match[2] else 0)


def state_name(value):
    return value.split()[0].rstrip("+") if value else ""


def choose_resources(measurements):
    """Favor the smallest request near the fastest observed sample runtime."""
    timed = [m for m in measurements if m["elapsed"] > 0]
    if len(timed) < 3:
        raise RuntimeError("Three positive benchmark runtimes are required before choosing resources")
    fastest = min(m["elapsed"] for m in timed)
    chosen = min((m for m in timed if m["elapsed"] <= fastest * 1.15), key=lambda m: m["cpus"])
    peak = max(m["peak"] for m in measurements)
    if not peak:
        raise RuntimeError("No memory measurements available; inspect the saved logs before choosing --mem")
    mem_gib = max(16, math.ceil(peak / 1024 ** 3 * 1.75))
    minutes = max(30, math.ceil(max(m["elapsed"] for m in measurements) * 2 / 60))
    return {"cpus": chosen["cpus"], "mem": f"{mem_gib}G", "time": f"{minutes // 60:02d}:{minutes % 60:02d}:00"}


class Workflow:
    def __init__(self, cfg, evidence, max_wait):
        self.cfg, self.evidence, self.max_wait = cfg, evidence, max_wait
        self.evidence.mkdir(parents=True, exist_ok=True)
        self.state_path = self.evidence / "state.json"
        self.state = json.loads(self.state_path.read_text()) if self.state_path.exists() else {"jobs": {}}
        self.run_root = self.evidence.parent
        self.production = self.run_root / "production"

    def save(self):
        temp = self.state_path.with_suffix(".tmp")
        temp.write_text(json.dumps(self.state, indent=2) + "\n")
        temp.replace(self.state_path)

    def log(self, text):
        print(time.strftime("[%H:%M:%S] ") + text, flush=True)

    def submit(self, label, run_root, cpus=8, mem="32G", limit="02:00:00", array=None, fail=0, dependency=None):
        if label in self.state["jobs"]:
            return self.state["jobs"][label]["id"]
        args = ["sbatch", "--parsable", "-p", self.cfg["PARTITION"], "-A", self.cfg["ACCOUNT"],
                f"--cpus-per-task={cpus}", f"--mem={mem}", f"--time={limit}"]
        if array:
            args += [f"--array={array}", "01_persample.sbatch", str(run_root), str(fail)]
        else:
            if dependency:
                args += [f"--dependency=afterok:{dependency}", "--kill-on-invalid-dep=yes"]
            args += ["02_cohort.sbatch", str(run_root)]
        job_id = command(args, cwd=SLURM).stdout.strip().split(";")[0]
        if not re.fullmatch(r"\d+", job_id):
            raise RuntimeError(f"Unexpected sbatch response: {job_id!r}")
        self.state["jobs"][label] = {"id": job_id, "run": str(run_root), "cpus": cpus, "mem": mem, "time": limit, "array": array}
        self.save()
        self.log(f"{label}: submitted {job_id}; outputs in {run_root}")
        return job_id

    def accounting(self, job):
        result = command(["sacct", "-j", job, "--parsable2", "--noheader", f"--format={FIELDS}"], check=False)
        if result.returncode:
            return []
        rows = []
        for line in result.stdout.splitlines():
            parts = line.split("|")
            if len(parts) >= 9:
                rows.append(dict(zip(FIELDS.split(","), parts)))
        return rows

    def wait(self, label, allow_failure=False):
        job = self.state["jobs"][label]["id"]
        array = self.state["jobs"][label]["array"]
        expected = int(array.split("-")[1]) - int(array.split("-")[0]) + 1 if array and "-" in array else 1
        deadline = time.monotonic() + self.max_wait
        next_message = 0
        while time.monotonic() < deadline:
            queued = command(["squeue", "-h", "-j", job, "-o", "%i %T %R"], check=False)
            rows = self.accounting(job)
            parents = [r for r in rows if "." not in r["JobID"] and not re.search(r"\[", r["JobID"])]
            # Completed job IDs can make squeue return "invalid job id". Trust
            # complete accounting once every expected array element is present.
            if not queued.stdout.strip() and len(parents) >= expected and all(state_name(r["State"]) in TERMINAL for r in parents):
                self.collect(label, rows)
                bad = [r for r in parents if state_name(r["State"]) != "COMPLETED"]
                if bad and not allow_failure:
                    raise RuntimeError(f"{label} failed: {bad}. Evidence saved in {self.evidence}. Fix the cause and resume.")
                self.log(f"{label}: " + ", ".join(f'{r["JobID"]} {r["State"]}' for r in parents))
                return rows
            if time.monotonic() >= next_message:
                self.log(f"waiting for {label} ({job}): {queued.stdout.strip() or 'accounting settling'}")
                next_message = time.monotonic() + 60
            time.sleep(15)
        raise RuntimeError(f"Wait limit reached for {label} ({job}); the job was not cancelled. Resume later.")

    def collect(self, label, rows=None):
        job = self.state["jobs"][label]["id"]
        rows = rows if rows is not None else self.accounting(job)
        text = FIELDS.replace(",", "|") + "\n" + "\n".join("|".join(r[k] for k in FIELDS.split(",")) for r in rows) + "\n"
        (self.evidence / f"{label}.sacct.txt").write_text(text)
        for log in (SLURM / "logs").glob("*.out"):
            if re.fullmatch(rf"(?:persample_{job}_\d+|cohort_{job})\.out", log.name):
                shutil.copy2(log, self.evidence / log.name)
        targets = sorted({r["JobID"] for r in rows if "." not in r["JobID"] and "[" not in r["JobID"]})
        if shutil.which("seff"):
            for target in targets:
                result = command(["seff", target], check=False)
                (self.evidence / f"{label}.{target}.seff.txt").write_text(result.stdout + result.stderr)
        self.state["jobs"][label]["collected"] = True
        self.save()

    def measurements(self, label):
        job = self.state["jobs"][label]
        rows = self.accounting(job["id"])
        parents = [r for r in rows if "." not in r["JobID"] and "[" not in r["JobID"]]
        values = []
        for parent in parents:
            jid = parent["JobID"]
            family = [r for r in rows if r["JobID"] == jid or r["JobID"].startswith(jid + ".")]
            rss = max((memory_bytes(r["MaxRSS"]) for r in family), default=0)
            logs = list((SLURM / "logs").glob(f"*_{jid}.out"))
            peaks = [int(x) for p in logs for x in re.findall(r"MEMORY_PEAK_BYTES=(\d+)", p.read_text(errors="replace"))]
            cpu = max((seconds(r["TotalCPU"]) for r in family), default=0)
            values.append({"label": label, "id": jid, "cpus": job["cpus"], "mem": job["mem"], "limit": job["time"],
                           "elapsed": int(parent["ElapsedRaw"] or 0), "cpu": cpu, "rss": rss, "peak": max([rss] + peaks)})
        return values

    def snapshots(self, label, run):
        lines = []
        if run.exists():
            for path in sorted(run.rglob("*")):
                if path.is_file():
                    lines.append(f"{path.relative_to(run)}\t{path.stat().st_size} bytes")
        (self.evidence / f"{label}.files.txt").write_text("\n".join(lines) + "\n")

    def benchmark(self):
        for count in [4, 8, 16]:
            label = f"cores-{count}"
            self.submit(label, self.run_root / label, cpus=count, array="1")
            self.wait(label)
        self.submit("probe-three", self.run_root / "probe-three", cpus=16, array="1-3")
        self.wait("probe-three")
        comparison = [self.measurements(f"cores-{c}")[0] for c in [4, 8, 16]]
        all_values = comparison + self.measurements("probe-three")
        choice = choose_resources(comparison)
        # Cover the largest observed sample, including the paired/single probe.
        peak = max(m["peak"] for m in all_values)
        choice["mem"] = f"{max(16, math.ceil(peak / 1024 ** 3 * 1.75))}G"
        minutes = max(30, math.ceil(max(m["elapsed"] for m in all_values) * 2 / 60))
        choice["time"] = f"{minutes // 60:02d}:{minutes % 60:02d}:00"
        self.state["choice"] = choice
        self.state["measurements"] = all_values
        self.save()
        self.log(f"measured per-sample request: {choice}")

    def full_run(self):
        choice = self.state["choice"]
        array = self.submit("full-array", self.production, cpus=choice["cpus"], mem=choice["mem"], limit=choice["time"], array="1-8")
        self.submit("full-cohort", self.production, cpus=2, mem="32G", limit="01:00:00", dependency=array)
        self.wait("full-array")
        self.wait("full-cohort")

    def failures(self):
        # Each fresh run is isolated; existing successful production data is reused
        # only for dependency/index experiments where the analysis need not repeat.
        root = self.run_root / "timeout"
        self.submit("timeout", root, array="1", limit="00:02:00")
        self.wait("timeout", allow_failure=True)
        self.snapshots("timeout", root)
        array = self.submit("dependency-array", self.production, array="1-8", fail=2)
        self.submit("dependency-cohort", self.production, cpus=2, mem="32G", limit="01:00:00", dependency=array)
        self.wait("dependency-array", allow_failure=True)
        self.wait("dependency-cohort", allow_failure=True)
        self.submit("out-of-range", self.production, array="1-9")
        self.wait("out-of-range", allow_failure=True)

        root = self.run_root / "cancel"
        job = self.submit("cancel", root, array="1")
        log = SLURM / "logs" / f"persample_{job}_1.out"
        if not self.state.get("cancel_attempted"):
            deadline = time.monotonic() + self.max_wait
            observed = False
            while time.monotonic() < deadline:
                text = log.read_text(errors="replace") if log.exists() else ""
                # The header is printed immediately before the longer alignment write.
                if re.search(r"===== .*: align =====", text):
                    time.sleep(3)
                    result = command(["scancel", job], check=False)
                    (self.evidence / "cancel.request.txt").write_text(result.stdout + result.stderr)
                    observed = True
                    break
                parents = [r for r in self.accounting(job) if "." not in r["JobID"] and "[" not in r["JobID"]]
                if parents and all(state_name(r["State"]) in TERMINAL for r in parents):
                    break
                time.sleep(5)
            if not observed and time.monotonic() >= deadline:
                raise RuntimeError("Cancellation probe wait limit reached; resume when the queued job starts")
            self.state["cancel_attempted"] = True
            self.state["cancel_header_observed"] = observed
            self.save()
        self.wait("cancel", allow_failure=True)
        self.snapshots("cancel-before-rerun", root)
        self.submit("cancel-rerun", root, array="1")
        self.wait("cancel-rerun")
        self.snapshots("cancel-after-rerun", root)

    def evidence_block(self, label):
        path = self.evidence / f"{label}.sacct.txt"
        job = self.state["jobs"][label]["id"]
        logs = sorted(self.evidence.glob(f"*_{job}*.out"))
        excerpts = []
        for log in logs:
            if label in {"out-of-range", "dependency-array"} and not log.name.endswith(("_9.out", "_2.out")):
                continue
            excerpts.append(f"{log.name}:\n" + "\n".join(log.read_text(errors="replace").splitlines()[-14:]))
        return "```text\n" + path.read_text() + "```\n\n" + "\n\n".join("```text\n" + x + "\n```" for x in excerpts)

    def reports(self):
        table = ["| Run / task | Cores requested | Memory requested | Time limit | Wall (s) | CPU (s) | Cores busy | MaxRSS (GiB) | Largest observed peak (GiB) |",
                 "|---|---:|---:|---|---:|---:|---:|---:|---:|"]
        values = self.state["measurements"] + self.measurements("full-array") + self.measurements("full-cohort")
        for m in values:
            busy = m["cpu"] / m["elapsed"] if m["elapsed"] else 0
            table.append(f'| {m["label"]} / {m["id"]} | {m["cpus"]} | {m["mem"]} | {m["limit"]} | {m["elapsed"]} | {m["cpu"]:.1f} | {busy:.2f} | {m["rss"]/1024**3:.2f} | {m["peak"]/1024**3:.2f} |')
        c = self.state["choice"]
        text = "# Assignment 2 resource measurements\n\nRecorded from Explorer jobs; no demo measurements were reused.\n\n" + "\n".join(table)
        text += f'\n\nThe initial probes requested 32G and 02:00:00. I chose {c["cpus"]} cores: the smallest measured request within 15% of the fastest wall time. '
        text += f'I set the per-sample request to --mem={c["mem"]} and --time={c["time"]}, allowing at least 75% headroom over the largest observed memory peak and twice the longest probe runtime (at least 30 minutes). '
        text += 'The largest observed peak is the greater of sampled MaxRSS and the cgroup high-water mark when available; MaxRSS alone can miss brief peaks or include file cache. '
        text += 'The cohort ran with a separate generous request of 2 cores, 32G, and 01:00:00; its measurement is shown above. '
        text += 'These decisions were passed to sbatch by the driver; the configuration file retains the conservative manual-submission defaults.\n\n'
        for label in ["cores-4", "cores-8", "cores-16", "probe-three", "full-array", "full-cohort"]:
            text += f"## {label}\n\n" + self.evidence_block(label) + "\n\n"
            for path in sorted(self.evidence.glob(f"{label}.*.seff.txt")):
                text += "```text\n" + path.read_text() + "```\n\n"
        (REPO / "RESOURCES.md").write_text(text)

        text = "# Assignment 2 deliberate failures\n\nActual job states, logs, and file listings from this Explorer run. Assignment 1 notes are preserved in `docs/assignment1-troubleshooting.md`.\n\n"
        timeout = self.accounting(self.state["jobs"]["timeout"]["id"])
        states = sorted({state_name(r["State"]) for r in timeout if "." not in r["JobID"]})
        text += "## 1. Two-minute time limit\n\n" + self.evidence_block("timeout")
        text += f"\n\nObserved states: {', '.join(states)}. A TIMEOUT means Slurm stopped the job, rather than the pipeline voluntarily returning an error. "
        if "TIMEOUT" not in states:
            text += "This submission did not reach the anticipated timeout; the observed states above are the evidence, and a COMPLETED task finished within the imposed limit. "
        text += "The final log lines identify the last stage reached. Files left on disk:\n\n```text\n" + (self.evidence / "timeout.files.txt").read_text() + "```\n\n"
        text += "## 2. One task exits 1 under afterok\n\n" + self.evidence_block("dependency-array") + "\n\n" + self.evidence_block("dependency-cohort")
        text += "\n\nTask 2 is explicitly programmed to exit 1 for this experiment. The cohort dependency requires every task to succeed; its actual State and Reason are shown above. `--kill-on-invalid-dep=yes` requests cancellation when the dependency cannot be met.\n\n"
        text += "## 3. Array 1-9 against eight rows\n\n" + self.evidence_block("out-of-range")
        text += "\n\nTask 9 has no samplesheet row. The guard refuses its empty sample with exit 64 before analysis starts. Without the batch guard, this implementation still rejects an empty sample in run_sample.sh; without both guards, a pipeline could select no samples or all samples and falsely report success.\n\n"
        text += "## 4. scancel during alignment, then rerun\n\n" + self.evidence_block("cancel") + "\n\n" + self.evidence_block("cancel-rerun")
        attempted = self.state["cancel_header_observed"]
        text += f"\n\nAlignment header observed before cancellation request: {attempted}. "
        text += "The logs above show whether the cancellation actually interrupted the write or arrived after completion. A successful-stage checkpoint is written only after validation; alignment writes to a temporary BAM and renames it after quickcheck. A cancelled stage without a checkpoint is rerun even if a partial file exists. Compare the rerun log's skipped/computed stages with these disk snapshots.\n\n"
        for label in ["cancel-before-rerun", "cancel-after-rerun"]:
            text += f"{label}:\n\n```text\n" + (self.evidence / f"{label}.files.txt").read_text() + "```\n\n"
        (REPO / "TROUBLESHOOTING.md").write_text(text)
        self.log(f"reports generated; complete raw evidence remains in {self.evidence}")

    def deliver(self):
        source = self.production / "results"
        target = REPO / "cluster-run"
        target.mkdir(exist_ok=True)
        for name in ["cohort.filtered.vcf.gz", "manifest.json"]:
            path = source / name
            if not path.is_file() or not path.stat().st_size:
                raise RuntimeError(f"Missing production output: {path}")
            shutil.copy2(path, target / name)
        result = command(["bash", "tests/run_acceptance.sh", "."], check=False)
        (self.evidence / "acceptance.txt").write_text(result.stdout + result.stderr)
        print(result.stdout, flush=True)
        if result.returncode:
            raise RuntimeError("Acceptance checks failed; see the output above and saved evidence")
        self.state["complete"] = True
        self.save()
        self.log("All ten acceptance checks passed. Review the reports, then commit and push the four deliverables.")


def preflight(cfg, resume=False):
    import csv
    for tool in ["sbatch", "squeue", "sacct", "scancel", "git"]:
        if not shutil.which(tool):
            raise RuntimeError(f"{tool} is unavailable; run this driver on Explorer's login node")
    if os.environ.get("SLURM_JOB_ID"):
        raise RuntimeError("Run the orchestration driver on the login node, outside a compute allocation")
    dirty = command(["git", "status", "--porcelain", "--untracked-files=no"]).stdout.splitlines()
    allowed = {"RESOURCES.md", "TROUBLESHOOTING.md", "cluster-run/cohort.filtered.vcf.gz", "cluster-run/manifest.json"} if resume else set()
    if any(line[3:] not in allowed for line in dirty):
        raise RuntimeError("Commit or stash tracked code changes before running; the manifest needs a clean committed implementation")
    sheet = Path(cfg["SAMPLESHEET"])
    with sheet.open(newline="") as stream:
        rows = list(csv.DictReader(stream))
    if len(rows) != 8 or {r["sample_id"] for r in rows} != IDS:
        raise RuntimeError("The official course samplesheet must contain exactly the eight assigned samples")
    for row in rows:
        for key in ["r1_fastq", "r2_fastq"]:
            if row[key] and not os.access(row[key], os.R_OK):
                raise RuntimeError(f"Cannot read {row[key]}")
    ref = Path(cfg["REF"])
    for path in [ref, Path(str(ref) + ".bwt"), Path(str(ref) + ".fai"), ref.with_suffix(".dict"), Path(cfg["CONDA_ENV"])]:
        if not os.access(path, os.R_OK):
            raise RuntimeError(f"Cannot access {path}")
    (SLURM / "logs").mkdir(exist_ok=True)
    command(["sbatch", "--test-only", "-p", cfg["PARTITION"], "-A", cfg["ACCOUNT"],
             "--cpus-per-task=1", "--mem=1G", "--time=00:01:00", "--wrap=true"], cwd=SLURM)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--resume", type=Path, help="resume using the evidence directory printed by an earlier run")
    parser.add_argument("--max-wait-hours", type=float, default=12, help="maximum wait per job, including queue time")
    args = parser.parse_args()
    cfg = config()
    preflight(cfg, resume=bool(args.resume))
    commit = command(["git", "rev-parse", "HEAD"]).stdout.strip()
    evidence = args.resume.resolve() if args.resume else Path(cfg["RUN_ROOT"]) / (time.strftime("%Y%m%d-%H%M%S") + f"-{os.getpid()}") / "evidence"
    flow = Workflow(cfg, evidence, args.max_wait_hours * 3600)
    if flow.state.get("git_sha", commit) != commit:
        raise RuntimeError("Code commit differs from the saved run; start a new run so benchmark provenance stays valid")
    flow.state["git_sha"] = commit
    flow.save()
    flow.log(f"Evidence directory: {evidence}")
    flow.log(f"To resume: bash scripts/run_assignment2.sh --resume {evidence}")
    if flow.state.get("complete"):
        flow.log("This workflow already completed; no jobs resubmitted")
        return
    flow.benchmark()
    flow.full_run()
    flow.failures()
    flow.reports()
    flow.deliver()


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, KeyError, ValueError) as error:
        print(f"STOPPED: {error}", flush=True)
        raise SystemExit(1)
