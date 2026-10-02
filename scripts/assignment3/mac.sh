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
        python3 - "$DRIFT/day1.json" <<'PY'
import json,sys,time
from pathlib import Path
data=json.loads(Path(sys.argv[1]).read_text())
if time.time()-data["completed_epoch"]<86400:
    sys.exit("A full day is required between builds. Earliest second build: "+data["earliest_second_build_utc"])
PY
        docker build --pull --no-cache -t binf6610-drift:day2 "$DRIFT/context" 2>&1 | tee "$DRIFT/day2-build.log"
        docker run --rm binf6610-drift:day2 dpkg -l > "$DRIFT/day2-packages.txt"
        docker image inspect binf6610-drift:day2 > "$DRIFT/day2-inspect.json"
        set +e
        diff -u "$DRIFT/day1-packages.txt" "$DRIFT/day2-packages.txt" > "$DRIFT/packages.diff"
        STATUS=$?
        set -e
        (( STATUS <= 1 )) || die "Package-list comparison failed."
        python3 - "$DRIFT/day2.json" "$STATUS" <<'PY'
import json,sys,time
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({"completed_epoch":time.time(),"diff_exit_code":int(sys.argv[2])},indent=2)+"\n")
PY
        echo "Second build and package lists saved. An empty diff is a valid observed result."
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
