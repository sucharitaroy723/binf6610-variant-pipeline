#!/usr/bin/env bash
# Works in the standalone kit and after installation in the repository.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"
ACTION=help
if (( $# > 0 )); then ACTION=$1; fi
EVIDENCE="$ROOT/evidence/assignment3"
DRIFT="$EVIDENCE/docker-drift"
BASE=mambaorg/micromamba:2.0.5-ubuntu24.04
die() { echo "error: $*" >&2; exit 1; }
need_docker() {
    command -v docker >/dev/null || die "Install/start Docker Desktop on your Mac first."
    docker info >/dev/null 2>&1 || die "Start Docker Desktop, wait until it is ready, then rerun."
}
case "$ACTION" in
    drift-start)
        need_docker
        [[ ! -f "$DRIFT/day1.json" ]] || die "Day 1 is already saved; use drift-finish tomorrow."
        mkdir -p "$DRIFT/context"
        printf 'FROM ubuntu\nRUN apt-get update && apt-get install -y curl\n' > "$DRIFT/context/Dockerfile"
        docker build -t binf6610-drift:day1 "$DRIFT/context" 2>&1 | tee "$DRIFT/day1-build.log"
        docker run --rm binf6610-drift:day1 dpkg -l > "$DRIFT/day1-packages.txt"
        docker image inspect binf6610-drift:day1 > "$DRIFT/day1-inspect.json"
        python3 - "$DRIFT/day1.json" <<'PY'
import datetime, json, sys, time
from pathlib import Path
now=time.time()
earliest=datetime.datetime.fromtimestamp(now+86400,datetime.timezone.utc)
Path(sys.argv[1]).write_text(json.dumps({"completed_epoch":now,"earliest_second_build_utc":earliest.isoformat()},indent=2)+"\n")
print("First build saved. Run drift-finish after",earliest.isoformat(),"(UTC).")
PY
        ;;
    drift-finish)
        need_docker
        [[ -s "$DRIFT/day1.json" ]] || die "Run drift-start first."
        [[ ! -f "$DRIFT/day2.json" ]] || die "Day 2 is already saved; evidence will not be overwritten."
        MIN_HOURS=24
        if (( $# > 1 )); then
            [[ $# == 3 && "$2" == --after-hours ]] || die "usage: drift-finish [--after-hours 3]"
            MIN_HOURS=$3
        fi
        python3 - "$DRIFT/day1.json" "$MIN_HOURS" <<'PY'
import json,sys,time,math
from pathlib import Path
data=json.loads(Path(sys.argv[1]).read_text())
hours=float(sys.argv[2])
if not math.isfinite(hours) or not 2 <= hours <= 24:
    sys.exit("Requested interval must be between 2 and 24 hours.")
elapsed=time.time()-data["completed_epoch"]
if elapsed < hours*3600:
    sys.exit(f"Second build is too early: {elapsed/3600:.2f} hours elapsed; {hours:g} requested.")
if hours < 24:
    print("Short-interval diagnostic build: the assignment's day-apart requirement remains incomplete.")
PY
        docker build --pull --no-cache -t binf6610-drift:day2 "$DRIFT/context" 2>&1 | tee "$DRIFT/day2-build.log"
        docker run --rm binf6610-drift:day2 dpkg -l > "$DRIFT/day2-packages.txt"
        docker image inspect binf6610-drift:day2 > "$DRIFT/day2-inspect.json"
        set +e
        diff -u "$DRIFT/day1-packages.txt" "$DRIFT/day2-packages.txt" > "$DRIFT/packages.diff"
        STATUS=$?
        set -e
        (( STATUS <= 1 )) || die "Package-list comparison failed."
        python3 - "$DRIFT/day2.json" "$STATUS" "$DRIFT/day1.json" <<'PY'
import json,sys,time
from pathlib import Path
now=time.time()
first=json.loads(Path(sys.argv[3]).read_text())["completed_epoch"]
interval=now-first
Path(sys.argv[1]).write_text(json.dumps({"completed_epoch":now,"diff_exit_code":int(sys.argv[2]),
    "interval_seconds":interval,"day_apart_requirement_met":interval>=86400},indent=2)+"\n")
print(f"Observed interval: {interval/3600:.2f} hours. Day-apart requirement met: {interval>=86400}.")
PY
        echo "Second build and package lists saved. Review the actual interval before claiming the timing requirement."
        ;;
    build)
        need_docker
        NAME=""
        if (( $# > 1 )); then NAME=$2; fi
        [[ "$NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || die "usage: bash scripts/assignment3/mac.sh build YOUR_DOCKERHUB_USERNAME"
        mkdir -p "$EVIDENCE"
        IMAGE="docker.io/$NAME/variant-call:1.0"
        docker pull --platform linux/amd64 "$BASE" 2>&1 | tee "$EVIDENCE/base-pull.log"
        docker image inspect "$BASE" > "$EVIDENCE/base-inspect.json"
        docker build --platform linux/amd64 -t "$IMAGE" containers/ 2>&1 | tee "$EVIDENCE/docker-build.log"
        ARCH=$(docker image inspect --format '{{.Architecture}}' "$IMAGE")
        [[ "$ARCH" == amd64 ]] || die "The image reports $ARCH instead of amd64."
        docker run --rm --platform linux/amd64 -v "$ROOT/tests:/t:ro" "$IMAGE" bash /t/print_versions.sh \
            > "$EVIDENCE/versions-docker.txt"
        python3 scripts/assignment3/support.py check-versions "$EVIDENCE/versions-docker.txt"
        docker login
        docker push "$IMAGE" 2>&1 | tee "$EVIDENCE/docker-push.log"
        docker image inspect "$IMAGE" > "$EVIDENCE/image-inspect.json"
        python3 scripts/assignment3/support.py image-metadata "$ROOT" "$IMAGE"
        echo "Build/push evidence saved. Confirm variant-call is public in Docker Hub."
        ;;
    *)
        echo "Actions: drift-start; drift-finish (24 hours later); build YOUR_DOCKERHUB_USERNAME"
        ;;
esac
