#!/bin/bash
#SBATCH -A binf6610.202710
#SBATCH -p courses
#SBATCH -c 4 --mem=16G -t 00:30:00
#SBATCH -J variant-image-pull
#SBATCH -o logs/a3-pull-%j.out
#SBATCH --export=NONE
set -euo pipefail
source "$SLURM_SUBMIT_DIR/conf/slurm.env"
export APPTAINER_CACHEDIR=/scratch/$USER/apptainer-cache
export APPTAINER_TMPDIR=/scratch/$USER/apptainer-tmp/$SLURM_JOB_ID
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR" "$(dirname -- "$SIF")" "$PIPELINE_DIR/evidence/assignment3"
trap 'rm -rf -- "$APPTAINER_TMPDIR"' EXIT
IMAGE_REF=$(cat "$PIPELINE_DIR/containers/image-ref.txt")
[[ "$IMAGE_REF" =~ @sha256:[0-9a-f]{64}$ ]] || { echo 'image-ref.txt must contain the pushed image digest' >&2; exit 64; }
[[ ! -e "$SIF" ]] || { echo "Refusing to replace existing image: $SIF" >&2; exit 64; }
apptainer pull "$SIF" "docker://$IMAGE_REF"
apptainer inspect --json "$SIF" > "$PIPELINE_DIR/evidence/assignment3/apptainer-inspect.json"
