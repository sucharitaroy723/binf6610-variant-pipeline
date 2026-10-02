#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
source "$ROOT/slurm/conf/slurm.env"
module load "$MINICONDA_MODULE"
mkdir -p "$ROOT/evidence/assignment3"
conda env export -p "$CONDA_ENV" --no-builds > "$ROOT/evidence/assignment3/course-env.yml"
python3 "$ROOT/scripts/assignment3/support.py" export-pins "$ROOT"
