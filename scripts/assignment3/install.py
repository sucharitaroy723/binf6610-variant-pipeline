#!/usr/bin/env python3
"""Install the container port after Assignment 2 has finished."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from support import sha

KIT = Path(__file__).resolve().parents[2]
VARIABLES = ("THREADS", "TMPDIR", "REF", "REGION", "JAVA_TOOL_OPTIONS",
             "SLURM_JOB_ID", "SLURM_CPUS_PER_TASK")


def parameter(name):
    return "$" + "{" + name + "}"


def wrap_script(text, entry):
    if "apptainer exec" in text:
        raise RuntimeError("A production job is already containerized; inspect before replacing it.")
    lines = text.splitlines(keepends=True)
    lines = [line for line in lines if not re.match(r"\s*(?:source|conda)\s+activate\b", line)
             and not (re.match(r"\s*module\s+load\b", line) and
                      re.search(r"MINICONDA|miniconda", line, re.I))]
    calls = [i for i, line in enumerate(lines) if re.match(r"\s*bash\s", line) and entry in line]
    if len(calls) != 1 or any(line.strip() and not line.lstrip().startswith("#") for line in lines[calls[0]+1:]):
        raise RuntimeError(f"Expected one final bash call to {entry}; no files changed.")
    prefix = '[[ -s "' + parameter("SIF") + '" ]] || { echo "Container image missing: ' + parameter("SIF") + '" >&2; exit 66; }\n'
    prefix += "apptainer exec --cleanenv \\\n"
    for name in VARIABLES:
        prefix += f'    --env {name}="{parameter(name)}" \\\n'
    prefix += '    --bind "' + parameter("PIPELINE_DIR") + ',/courses/BINF6610.202710,/scratch/' + parameter("USER") + '" \\\n'
    prefix += '    "' + parameter("SIF") + '" \\\n'
    lines[calls[0]] = prefix + "    " + lines[calls[0]].lstrip()
    return "".join(lines)


def validate_bash(text):
    with tempfile.NamedTemporaryFile(mode="w", suffix=".sh") as stream:
        stream.write(text)
        stream.flush()
        result = subprocess.run(["bash", "-n", stream.name], capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stderr)


def measured_cpus(root, supplied=None):
    if supplied:
        return supplied
    path = root / "RESOURCES.md"
    text = path.read_text() if path.exists() else ""
    matches = re.findall(r"^\|\s*full-array\s*/\s*\d+(?:_\d+)?\s*\|\s*(\d+)\s*\|", text, re.M)
    values = set(map(int, matches))
    if len(values) == 1:
        return values.pop()
    raise RuntimeError("Cannot determine the production array CPU count from RESOURCES.md. "
                       "Use --sample-cpus with the actual Assignment 2 count.")


def install(root, sample_cpus=None):
    root = root.resolve()
    marker = root / "docs/assignment3/baseline.json"
    if marker.exists():
        raise RuntimeError("Assignment 3 is already installed. The original jobs are under docs/assignment3/week2/.")
    required = ["run_sample.sh", "run_pipeline.sh", "lib/common.sh", "lib/write_manifest.sh",
                "slurm/01_persample.sbatch", "slurm/02_cohort.sbatch", "slurm/conf/slurm.env",
                "cluster-run/cohort.filtered.vcf.gz", "cluster-run/manifest.json", "TROUBLESHOOTING.md"]
    for name in required:
        path = root / name
        if not path.is_file() or not path.stat().st_size:
            raise RuntimeError(f"Assignment 2 must finish before installation; missing {name}.")
    baseline_manifest = json.loads((root / "cluster-run/manifest.json").read_text())
    if str(baseline_manifest.get("platform", {}).get("container", "none")).endswith(".sif"):
        raise RuntimeError("cluster-run must hold the conda baseline, not a container run.")
    if "APPTAINER_CONTAINER" not in (root / "lib/write_manifest.sh").read_text():
        raise RuntimeError("The manifest writer does not yet record the container; finish the Assignment 2 writer first.")
    cpus = measured_cpus(root, sample_cpus)
    originals = {name: (root / "slurm" / name).read_text()
                 for name in ["01_persample.sbatch", "02_cohort.sbatch", "conf/slurm.env"]}
    wrapped = {"01_persample.sbatch": wrap_script(originals["01_persample.sbatch"], "run_sample.sh"),
               "02_cohort.sbatch": wrap_script(originals["02_cohort.sbatch"], "run_pipeline.sh")}
    config = originals["conf/slurm.env"]
    config = re.sub(r"(?m)^(?:RUN_ROOT|SIF|PER_SAMPLE_CPUS)=.*\n?", "", config)
    config += "\n# Assignment 3: fresh run; preserve the measured Assignment 2 array CPU count.\n"
    config += "RUN_ROOT=/scratch/" + parameter("USER") + "/w3-variant\n"
    config += "SIF=/scratch/" + parameter("USER") + "/containers/variant-call.sif\n"
    config += f"PER_SAMPLE_CPUS={cpus}\n"
    for text in [*wrapped.values(), config]:
        validate_bash(text)
    paths = [*sorted((root / "lib").glob("*.sh")), *sorted((root / "stages").glob("*.sh")),
             root / "run_pipeline.sh", root / "run_sample.sh"]
    baseline = {"sample_cpus": cpus, "code_sha256": {str(path.relative_to(root)): sha(path) for path in paths},
                "vcf_sha256": sha(root / "cluster-run/cohort.filtered.vcf.gz"),
                "manifest_sha256": sha(root / "cluster-run/manifest.json"),
                "manifest": baseline_manifest}
    # Check all additive destinations for conflicts before writing anything.
    sources = [*sorted((KIT / "containers").glob("*")), *sorted((KIT / "scripts/assignment3").glob("*")),
               *sorted((KIT / "slurm").glob("*.sbatch")), KIT / "scripts/run_assignment3.sh",
               KIT / "tests/print_versions.sh", KIT / "ASSIGNMENT3.md", KIT / "ASSIGNMENT3-REQUIREMENTS.md"]
    sources = [source for source in sources if source.is_file()]
    for source in sources:
        target = root / source.relative_to(KIT)
        if target.exists() and source.resolve() != target.resolve() and source.read_bytes() != target.read_bytes():
            raise RuntimeError(f"Conflicting existing file {target}; installation stopped before changing the jobs.")
    backup = root / "docs/assignment3/week2"
    backup.mkdir(parents=True)
    for name, text in originals.items():
        target = backup / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
    previous_notes = root / "docs/assignment2-troubleshooting.md"
    previous_notes.write_text((root / "TROUBLESHOOTING.md").read_text())
    old_test = root / "tests/run_acceptance.sh"
    saved_test = root / "tests/run_acceptance_w02.sh"
    if old_test.exists() and old_test.read_bytes() != (KIT / "tests/run_acceptance.sh").read_bytes():
        if saved_test.exists() and saved_test.read_bytes() != old_test.read_bytes():
            raise RuntimeError("Existing run_acceptance_w02.sh differs from the current Assignment 2 suite.")
        shutil.copy2(old_test, saved_test)
    for source in sources:
        target = root / source.relative_to(KIT)
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.resolve() != target.resolve():
            shutil.copy2(source, target)
    shutil.copy2(KIT / "tests/run_acceptance.sh", old_test)
    for name, text in wrapped.items():
        (root / "slurm" / name).write_text(text)
    (root / "slurm/conf/slurm.env").write_text(config)
    for label, remove in [("no-bind", "--bind"), ("no-threads", "--env THREADS=")]:
        probe = "".join(line for line in wrapped["01_persample.sbatch"].splitlines(keepends=True)
                        if remove not in line)
        probe = re.sub(r"(?m)^#SBATCH --output=.*$", f"#SBATCH --output=logs/a3-{label}_%A_%a.out", probe)
        validate_bash(probe)
        (root / f"slurm/a3-{label}.sbatch").write_text(probe)
    ignores = root / ".gitignore"
    text = ignores.read_text() if ignores.exists() else ""
    for value in ["*.sif", "assignment3-workflow.log", "evidence/assignment3/workflow.json", "__pycache__/"]:
        if value not in text.splitlines():
            text += "\n" + value + "\n"
    ignores.write_text(text)
    marker.write_text(json.dumps(baseline, indent=2) + "\n")
    for name, value in baseline["code_sha256"].items():
        if sha(root / name) != value:
            raise RuntimeError("Pipeline changed during installation: " + name)
    print(f"Installed with {cpus} array CPUs. Analysis code and cluster-run are unchanged.")
    print("Next on Explorer: bash scripts/assignment3/export_pins.sh")
    print("Commit the prepared container port before starting the production jobs.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repository", type=Path)
    parser.add_argument("--sample-cpus", type=int, help="actual production array CPU count from Assignment 2")
    args = parser.parse_args()
    if args.sample_cpus is not None and args.sample_cpus < 1:
        parser.error("--sample-cpus must be positive")
    try:
        install(args.repository, args.sample_cpus)
    except (RuntimeError, OSError, ValueError) as error:
        parser.exit(1, str(error) + "\n")
