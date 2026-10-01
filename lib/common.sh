# shellcheck shell=bash
# Shared configuration, samplesheet parsing, and successful-stage checkpoints.
PIPE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
REF=${REF:-/courses/BINF6610.202710/data/refs/grch38-1000g/GRCh38_full_analysis_set_plus_decoy_hla.fa}
REGION=${REGION:-chr20:1-10000000}
THREADS=${THREADS:-4}
[[ $THREADS =~ ^[1-9][0-9]*$ ]] || { echo 'THREADS must be a positive integer' >&2; exit 64; }
REF_DICT=${REF%.*}.dict
# Alignment and conversion run together; reserve one CPU for conversion.
ALIGN_THREADS=$(( THREADS > 1 ? THREADS - 1 : 1 ))
VIEW_THREADS=0
SORT_THREADS=$(( THREADS - 1 ))
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 65; }
hash_file() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | awk '{print $1}'; }

# The course CSV is unquoted. Select the six needed columns by header name,
# preserving empty R2 values, regardless of extra metadata or column order.
rows() {
    awk -F, -v want="${2:-}" '
        BEGIN { n=split("sample_id condition replicate library_type r1_fastq r2_fastq",need," ") }
        NR==1 {
            sub(/\r$/, "")
            for(i=1;i<=NF;i++) col[$i]=i
            for(i=1;i<=n;i++) if(!(need[i] in col)) {
                print "missing samplesheet column: " need[i] > "/dev/stderr"; exit 65
            }
            next
        }
        /^[[:space:]]*$/ {next}
        {
            sub(/\r$/, "")
            id=$col["sample_id"]
            if(id !~ /^[A-Za-z0-9_.-]+$/ || id=="." || id==".." || seen[id]++) {
                print "invalid or duplicate sample_id: " id > "/dev/stderr"; exit 65
            }
            if(want!="" && id!=want) next
            print id "," $col["condition"] "," $col["replicate"] "," $col["library_type"] "," $col["r1_fastq"] "," $col["r2_fastq"]
        }
    ' "$1"
}

setup_dirs() {
    [[ -s "$SHEET" ]] || die "samplesheet missing or empty: $SHEET"
    QC="${OUT}/qc_raw"; TRIM="${OUT}/trim"; ALN="${OUT}/align"
    POST="${OUT}/postprocess"; GVCF="${OUT}/gvcf"; COHORT="${OUT}/cohort"
    RES="${OUT}/results"; LOG="${OUT}/logs"; STATE="${OUT}/.state"
    mkdir -p "$QC" "$TRIM" "$ALN" "$POST" "$GVCF" "$COHORT" "$RES" "$LOG" "$STATE"
    if [[ -z ${TMPDIR:-} ]]; then
        TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/variant-call.XXXXXXXX")
        export TMPDIR
        trap 'rm -rf -- "$TMPDIR"' EXIT
    fi
    mkdir -p "$TMPDIR"
    # Materialize once: parser errors cannot disappear in process substitution.
    ROWS_FILE=$(mktemp "${TMPDIR}/rows.XXXXXXXX")
    rows "$SHEET" "${SAMPLE:-}" > "$ROWS_FILE" || die 'cannot read samplesheet'
    [[ -s "$ROWS_FILE" ]] || die "no sample '${SAMPLE:-}' in $SHEET"
    # A changed sheet, reference, region, or stage implementation invalidates skips.
    CODE_HASH=$(cat "${PIPE_DIR}/lib/common.sh" "${PIPE_DIR}"/stages/*.sh | {
        if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi
    } | awk '{print $1}')
    RUN_KEY="$(hash_file "$SHEET")|$REF|$REGION|$CODE_HASH"
}

stage_outputs_exist() {
    local stage=$1 id cond rep lt r1 r2 base
    if [[ $stage == validate ]]; then return 0; fi
    case "$stage" in
        merge) [[ -s "${COHORT}/cohort.raw.vcf.gz" && -s "${COHORT}/cohort.raw.vcf.gz.tbi" ]]; return ;;
        analyze) [[ -s "${RES}/cohort.filtered.vcf.gz" && -s "${RES}/cohort.filtered.vcf.gz.tbi" ]]; return ;;
        qc_report) [[ -s "${RES}/multiqc_report.html" && -d "${RES}/multiqc_report_data" ]]; return ;;
        publish) return 1 ;; # Always write a manifest for the current cohort job.
    esac
    while IFS=, read -r id cond rep lt r1 r2; do
        case "$stage" in
            qc_raw)
                base=$(basename "$r1" .fastq.gz)
                [[ -s "${QC}/${base}_fastqc.zip" ]] || return 1
                if [[ $lt == paired ]]; then
                    base=$(basename "$r2" .fastq.gz)
                    [[ -s "${QC}/${base}_fastqc.zip" ]] || return 1
                fi ;;
            trim)
                [[ -s "${TRIM}/${id}_R1.fastq.gz" ]] || return 1
                [[ $lt != paired || -s "${TRIM}/${id}_R2.fastq.gz" ]] || return 1 ;;
            align) [[ -s "${ALN}/${id}.unsorted.bam" ]] || return 1 ;;
            postprocess) [[ -s "${POST}/${id}.dedup.bam" && -s "${POST}/${id}.dedup.bam.bai" ]] || return 1 ;;
            quantify) [[ -s "${GVCF}/${id}.g.vcf.gz" && -s "${GVCF}/${id}.g.vcf.gz.tbi" ]] || return 1 ;;
        esac
    done < "$ROWS_FILE"
}

run_stage() {
    local stage=$1 target=${SAMPLE:-cohort} stamp id cond rep lt r1 r2 all_done=1
    stamp="${STATE}/${target}.${stage}.done"
    if [[ -z ${SAMPLE:-} && $stage =~ ^(validate|qc_raw|trim|align|postprocess|quantify)$ ]]; then
        while IFS=, read -r id cond rep lt r1 r2; do
            [[ -s "${STATE}/${id}.${stage}.done" ]] &&
                [[ $(head -1 "${STATE}/${id}.${stage}.done") == "$RUN_KEY" ]] || all_done=0
        done < "$ROWS_FILE"
        if (( all_done )) && stage_outputs_exist "$stage"; then
            log "$stage: every sample already completed"; return
        fi
    fi
    if [[ -s "$stamp" ]] && [[ $(head -1 "$stamp") == "$RUN_KEY" ]] && stage_outputs_exist "$stage"; then
        log "$target: $stage already completed"; return
    fi
    # Remove the checkpoint BEFORE work. An interrupted stage is always repeated.
    rm -f -- "$stamp"
    log "===== $target: $stage ====="
    "stage_${stage}"
    printf '%s\n%s\n' "$RUN_KEY" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${stamp}.tmp"
    mv -- "${stamp}.tmp" "$stamp"
}
