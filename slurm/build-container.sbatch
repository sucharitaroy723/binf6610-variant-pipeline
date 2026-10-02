#!/bin/bash
#SBATCH -A binf6610.202710
#SBATCH -p courses
#SBATCH -c 8 --mem=24G -t 01:00:00
#SBATCH -J variant-image-build
#SBATCH -o logs/a3-build-%j.out
#SBATCH --export=NONE
set -euo pipefail
source "$SLURM_SUBMIT_DIR/conf/slurm.env"
export APPTAINER_CACHEDIR=/scratch/$USER/apptainer-cache
export APPTAINER_TMPDIR=/scratch/$USER/apptainer-tmp/$SLURM_JOB_ID
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR" "$(dirname -- "$SIF")" "$PIPELINE_DIR/evidence/assignment3"
trap 'rm -rf -- "$APPTAINER_TMPDIR"' EXIT
cd "$PIPELINE_DIR"
[[ ! -e "$SIF" ]] || { echo "Refusing to replace existing image: $SIF" >&2; exit 64; }
apptainer build "$SIF" containers/variant-call.def
apptainer inspect --json "$SIF" > evidence/assignment3/apptainer-inspect.json
