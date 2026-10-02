#!/bin/bash
#SBATCH -A binf6610.202710
#SBATCH -p courses
#SBATCH -c 4 --mem=16G -t 03:00:00
#SBATCH -J variant-image-pull
#SBATCH -o logs/a3-pull-%j.out
#SBATCH --export=NONE
set -euo pipefail
source "$SLURM_SUBMIT_DIR/conf/slurm.env"
export APPTAINER_CACHEDIR=/scratch/$USER/apptainer-cache
# Extract thousands of package files on the compute node's local filesystem.
export APPTAINER_TMPDIR
APPTAINER_TMPDIR=$(mktemp -d "${SLURM_TMPDIR:-/tmp}/a3-apptainer-${SLURM_JOB_ID}.XXXXXX")
mkdir -p "$APPTAINER_CACHEDIR" "$(dirname -- "$SIF")" "$PIPELINE_DIR/evidence/assignment3"
PARTIAL="$SIF.partial-$SLURM_JOB_ID"
trap 'rm -f -- "$PARTIAL"; rm -rf -- "$APPTAINER_TMPDIR"' EXIT
echo "Temporary conversion directory: $APPTAINER_TMPDIR"
df -h "$APPTAINER_TMPDIR"
IMAGE_REF=$(cat "$PIPELINE_DIR/containers/image-ref.txt")
[[ "$IMAGE_REF" =~ @sha256:[0-9a-f]{64}$ ]] || { echo 'image-ref.txt must contain the pushed image digest' >&2; exit 64; }
[[ ! -e "$SIF" ]] || { echo "Refusing to replace existing image: $SIF" >&2; exit 64; }
LOCAL_SIF="$APPTAINER_TMPDIR/variant-call.sif"
apptainer pull "$LOCAL_SIF" "docker://$IMAGE_REF"
apptainer inspect --json "$LOCAL_SIF" > "$PIPELINE_DIR/evidence/assignment3/apptainer-inspect.json"
# Publish only a successfully converted and inspected image.
cp "$LOCAL_SIF" "$PARTIAL"
mv "$PARTIAL" "$SIF"
echo "Verified SIF saved: $SIF"
