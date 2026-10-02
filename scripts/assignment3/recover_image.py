#!/usr/bin/env python3
"""Archive a terminal image-job failure and permit one explicit retry."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time
from support import sha

ROOT = Path(__file__).resolve().parents[2]
def output(args):
    r = subprocess.run(args, text=True, capture_output=True)
    if r.returncode:
        raise RuntimeError(r.stderr or r.stdout)
    return r.stdout

def recover(job):
    evidence = ROOT / "evidence/assignment3"
    state_path = evidence / "workflow.json"
    state = json.loads(state_path.read_text())
    if state["jobs"].get("image", {}).get("id") != job:
        raise RuntimeError("The requested job is not the saved image job.")
    if set(state["jobs"]) != {"image"} or state.get("cluster_complete"):
        raise RuntimeError("Later jobs exist; inspect the workflow before recovery.")
    username = subprocess.check_output(["id", "-un"], text=True).strip()
    # Finished jobs can be purged from squeue while remaining in sacct.
    queue = output(["squeue", "-h", "-u", username, "-o", "%i|%j|%T"])
    live_rows = [line.split("|") for line in queue.splitlines() if "|" in line]
    active = [row for row in live_rows if row[0] == job]
    if active:
        raise RuntimeError("Image job is still active or completing: " + "|".join(active[0]))
    accounting = output(["sacct", "-X", "-j", job, "--noheader", "--parsable2",
                         "--format=JobID,State,ExitCode,Elapsed"])
    rows = [line.split("|") for line in accounting.splitlines() if "|" in line]
    terminal_failures = {"FAILED", "TIMEOUT", "CANCELLED", "OUT_OF_MEMORY",
                         "NODE_FAIL", "PREEMPTED", "BOOT_FAIL", "DEADLINE", "REVOKED"}
    if not rows or any(row[1].split()[0].rstrip("+") not in terminal_failures for row in rows):
        raise RuntimeError("No confirmed terminal failure; refusing to retry.\n" + accounting)
    # The caller must stop the old monitor before modifying its saved state.
    if any(row[1] == "a3-monitor" for row in live_rows):
        raise RuntimeError("Stop the old a3-monitor job before retrying.")
    archive = evidence / ("image-recovery-" + job)
    if archive.exists():
        raise RuntimeError("This failure was already archived; inspect saved state.")
    archive.mkdir()
    (archive / "workflow-before.json").write_text(json.dumps(state, indent=2) + "\n")
    (archive / "accounting.txt").write_text(accounting)
    for path in sorted((ROOT / "slurm/logs").glob("a3-image_" + job + "*.out")):
        shutil.copy2(path, archive / path.name)
    script = 'source "$1"; printf "%s" "$SIF"'
    sif = Path(output(["bash", "-c", script, "config", str(ROOT / "slurm/conf/slurm.env")]))
    if sif.exists():
        quarantine = sif.with_name(sif.name + ".failed-" + job)
        if quarantine.exists():
            raise RuntimeError("Quarantine path already exists: " + str(quarantine))
        sif.rename(quarantine)
        (archive / "quarantined-image.txt").write_text(str(quarantine) + "\n")
    state.setdefault("image_attempts", []).append({
        "job": state["jobs"].pop("image"), "accounting": rows,
        "archive": str(archive.relative_to(ROOT)), "recovered_epoch": time.time(),
        "retry_pull_sha256": sha(ROOT / "slurm/pull.sbatch")
    })
    state.pop("source_hashes", None)
    temp = state_path.with_suffix(".tmp")
    temp.write_text(json.dumps(state, indent=2) + "\n")
    temp.replace(state_path)
    print("Failed image job archived. Ready for a new compute monitor.")
if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("job_id")
    a = p.parse_args()
    if not a.job_id.isdigit():
        p.error("job ID must be numeric")
    try:
        recover(a.job_id)
    except (RuntimeError, OSError, ValueError, KeyError) as e:
        p.exit(1, str(e) + "\n")
