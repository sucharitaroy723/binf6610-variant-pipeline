#!/usr/bin/env python3
"""Validate observed versions and write documentation from real build evidence."""
import hashlib
import json
from pathlib import Path
import re
import sys

PINS = {"bwa": "0.7.19", "samtools": "1.24", "bcftools": "1.24",
        "gatk4": "4.6.2.0", "fastqc": "0.12.1", "fastp": "1.3.7", "multiqc": "1.35"}
REPORTED = {**PINS, "bwa": "0.7.19-r1273", "gatk": PINS["gatk4"]}
del REPORTED["gatk4"]
BASE = "mambaorg/micromamba:2.0.5-ubuntu24.04"


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1048576), b""):
            digest.update(block)
    return digest.hexdigest()


def check_versions(path):
    found = {}
    for line in Path(path).read_text().splitlines():
        pieces = line.split()
        if len(pieces) == 2:
            found[pieces[0]] = pieces[1]
    problems = [f"{tool}: observed {found.get(tool, 'missing')}, expected {value}"
                for tool, value in REPORTED.items() if found.get(tool) != value]
    if problems:
        raise RuntimeError("Version check failed:\n" + "\n".join(problems))
    print("All seven observed tool versions match the assignment.")


def recipe_pins(root):
    return dict(re.findall(r"^\s*-\s*([a-z0-9]+)=([^=\s]+)\s*$",
                           (root / "containers/env.yml").read_text(), re.M))


def export_pins(root):
    source = root / "evidence/assignment3/course-env.yml"
    found = dict(re.findall(r"^\s*-\s*([a-z0-9]+)=([^=\s]+)\s*$", source.read_text(), re.M))
    bad = [f"{tool}: course reports {found.get(tool, 'missing')}, assignment expects {version}"
           for tool, version in PINS.items() if found.get(tool) != version]
    if bad:
        raise RuntimeError("Course export differs from the supplied rubric. Resolve before building:\n" + "\n".join(bad))
    chosen = {tool: found[tool] for tool in PINS}
    chosen["git"] = "2.47.1"
    text = "name: base\nchannels:\n  - conda-forge\n  - bioconda\ndependencies:\n"
    text += "".join(f"  - {tool}={version}\n" for tool, version in chosen.items())
    (root / "containers/env.yml").write_text(text)
    (root / "evidence/assignment3/course-pins.txt").write_text(
        "".join(f"{tool}={chosen[tool]}\n" for tool in PINS))
    print("containers/env.yml now contains the pins extracted from the course environment.")


def image_metadata(root, tag):
    evidence = root / "evidence/assignment3"
    push = (evidence / "docker-push.log").read_text()
    digests = re.findall(r"digest:\s*(sha256:[0-9a-f]{64})", push)
    if not digests:
        raise RuntimeError("No successful pushed-image digest in docker-push.log.")
    image = json.loads((evidence / "image-inspect.json").read_text())[0]
    if image["Architecture"] != "amd64":
        raise RuntimeError("Image is not amd64.")
    base = json.loads((evidence / "base-inspect.json").read_text())[0]
    refs = [ref for ref in base.get("RepoDigests", []) if "mambaorg/micromamba@" in ref]
    if not refs:
        raise RuntimeError("No observed base image registry digest in base-inspect.json.")
    pushed = tag.rsplit(":", 1)[0] + "@" + digests[-1]
    data = {"tag": tag, "pushed_image": pushed, "architecture": "amd64",
            "base_tag": BASE, "base_digest": refs[0],
            "env_sha256": sha(root / "containers/env.yml"),
            "dockerfile_sha256": sha(root / "containers/Dockerfile")}
    (evidence / "image.json").write_text(json.dumps(data, indent=2) + "\n")
    (root / "containers/image-ref.txt").write_text(pushed + "\n")
    write_image_doc(root, data=data)
    print("Recorded pushed image:", pushed)


def write_image_doc(root, data=None, build_job=None):
    versions = " ".join(f"{tool}={version}" for tool, version in recipe_pins(root).items())
    if data:
        base = data["base_tag"] + "\n" + data["base_digest"]
        image = data["pushed_image"]
        paragraph = ("To rerun this analysis in a year, pull the immutable digest under The pushed image "
                     "and run the saved pipeline with the original samplesheet, reference, input FASTQs, "
                     "and per-sample/cohort CPU counts. Versions pinned records the selected packages; "
                     "Base image identifies the starting image. The registry digest identifies the built "
                     "software, including dependencies; a tag or a checksum of one converted SIF is "
                     "not a replacement for that digest.")
    elif build_job:
        base = BASE + "\nBase registry digest was not captured on this permitted local-build route."
        image = f"built from containers/variant-call.def by job {build_job}"
        paragraph = ("This image was built on Explorer from the supplied definition file. There is no "
                     "registry digest for the built image. The SIF lives in scratch storage and must be "
                     "rebuilt after it is removed; rebuilding from this recipe is not guaranteed to be "
                     "byte-identical. To rerun, use the definition file and Versions pinned, the original "
                     "pipeline, samplesheet, reference, FASTQs, and CPU counts. Base image gives the "
                     "starting tag; dependency resolution may differ on a later rebuild.")
    else:
        raise RuntimeError("IMAGE.md requires real build or push evidence.")
    (root / "IMAGE.md").write_text(
        "## Base image\n" + base + "\n\n## Versions pinned\n" + versions +
        "\n\n## The pushed image\n" + image + "\n\n" + paragraph + "\n")


def main():
    action = sys.argv[1]
    if action == "check-versions":
        check_versions(sys.argv[2])
    elif action == "export-pins":
        export_pins(Path(sys.argv[2]))
    elif action == "image-metadata":
        image_metadata(Path(sys.argv[2]), sys.argv[3])
    else:
        raise RuntimeError("Unknown action: " + action)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        sys.exit(str(error))
