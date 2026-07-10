#!/usr/bin/env bash
# Download missing album zips from GCS via gcdn and unzip to /workspace/culling_ws.
# Run directly ON the pod. Requires: gcloud, gcdn (install via setup-pod-gcloud).
#
# Usage:
#   ./pod-sync-gcs-albums.sh           # download + unzip missing
#   ./pod-sync-gcs-albums.sh --list    # dry-run
#   ./pod-sync-gcs-albums.sh --help
set -uo pipefail

BUCKET="gs://ml-culling/culling-labeller-bucket/Selection_Model_Datasets/Selections_FullAlbums_dataset"
DL="/workspace/vk_culling/downloads"
OUT="/workspace/culling_ws"
LOG="/workspace/vk_culling/runs/pod_sync_gcs.log"
MODE="sync"

usage() { cat <<'EOF'
Usage: pod-sync-gcs-albums.sh [--list | --download-only | --unzip-only] [--help]

  --list          Show what's missing without doing anything
  --download-only Download zips only, skip unzip
  --unzip-only    Unzip already-downloaded zips only
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) MODE="list"; shift ;;
    --download-only) MODE="download"; shift ;;
    --unzip-only) MODE="unzip"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

fail() { echo "FATAL: $*" >&2; exit 1; }
log()  { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

mkdir -p "$DL" "$OUT" "$(dirname "$LOG")"
export PATH="/tmp/google-cloud-sdk/bin:/usr/local/bin:$PATH"

[[ "$MODE" != "unzip" ]] && { command -v gcloud &>/dev/null || fail "gcloud not found"; }
[[ "$MODE" == "sync" || "$MODE" == "download" ]] && { command -v gcdn &>/dev/null || fail "gcdn not found"; }

is_done() { [[ -f "$OUT/$1/.extract_complete" ]]; }

# --- List GCS zips ---
if [[ "$MODE" != "unzip" ]]; then
  log "Listing GCS bucket..."
  gcs_tmp=$(mktemp)
  gcloud storage ls "${BUCKET}/" > "$gcs_tmp" 2>&1 || { rm -f "$gcs_tmp"; fail "gcloud ls failed"; }
  mapfile -t gcs_zips < <(sed 's|.*/||' < "$gcs_tmp" | grep '\.zip$' | grep -v '_labelledraws' | sort)
  rm -f "$gcs_tmp"
  [[ ${#gcs_zips[@]} -gt 0 ]] || fail "No zips in GCS"
  log "${#gcs_zips[@]} zips in GCS"
fi

# --- Find missing ---
if [[ "$MODE" != "unzip" ]]; then
  to_download=()
  for z in "${gcs_zips[@]}"; do
    [[ -z "$z" ]] && continue
    base="${z%.zip}"
    is_done "$base" && continue
    if [[ -f "$DL/$z" ]]; then
      if unzip -tq "$DL/$z" &>/dev/null; then
        continue
      fi
      log "  corrupt zip, will re-download: $z"
      rm -f "$DL/$z"
    fi
    to_download+=("$z")
  done
  log "${#to_download[@]} to download"
  [[ "$MODE" == "list" ]] && { for z in "${to_download[@]}"; do log "  $z"; done; exit 0; }
fi

# --- Download via gcdn (atomic: .part → validate → mv) ---
errors=0
if [[ "$MODE" == "sync" || "$MODE" == "download" ]] && [[ ${#to_download[@]} -gt 0 ]]; then
  log "Downloading ${#to_download[@]} zips..."
  for z in "${to_download[@]}"; do
    part="$DL/${z}.part"
    log "DL: $z"
    if gcdn storage cp "$BUCKET/$z" "$part" 2>&1 | tee -a "$LOG" && [[ -f "$part" ]] && unzip -tq "$part" &>/dev/null; then
      mv "$part" "$DL/$z"
      log "  OK ($(du -h "$DL/$z" | cut -f1))"
    else
      log "  FAILED"
      rm -f "$part"
      errors=$((errors + 1))
    fi
  done
fi
[[ "$MODE" == "download" ]] && exit $errors

# --- Unzip missing ---
to_unzip=()
for z in "$DL"/*.zip; do
  [[ -f "$z" ]] || continue
  zname="$(basename "$z")"
  [[ "$zname" == *_labelledraws* || "$zname" == *.part* ]] && continue
  top=$(unzip -Z1 "$DL/$zname" 2>/dev/null | grep '/' | grep -v '__MACOSX' | head -1 | cut -d/ -f1)
  [[ -z "$top" ]] && top="${zname%.zip}"
  is_done "$top" && continue
  to_unzip+=("$zname|$top")
done

if [[ ${#to_unzip[@]} -gt 0 ]]; then
  log "Unzipping ${#to_unzip[@]} albums..."
  for entry in "${to_unzip[@]}"; do
    zname="${entry%%|*}"; top="${entry##*|}"
    log "UNZIP: $zname -> $top"
    t0=$(date +%s)
    if unzip -q -o "$DL/$zname" -d "$OUT" 2>&1 | tee -a "$LOG" && [[ -d "$OUT/$top" ]] && touch "$OUT/$top/.extract_complete"; then
      log "  OK ($(($(date +%s) - t0))s)"
    else
      log "  FAILED"
      errors=$((errors + 1))
    fi
  done
else
  log "Nothing to unzip"
fi

# --- Summary ---
log ""
log "=== SUMMARY ==="
log "  Albums: $(find "$OUT" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ') ($(find "$OUT" -maxdepth 2 -name .extract_complete | wc -l | tr -d ' ') complete)"
log "  Zips: $(find "$DL" -name '*.zip' ! -name '*_labelledraws*' ! -name '*.part*' | wc -l | tr -d ' ')"
[[ $errors -gt 0 ]] && { log "FINISHED WITH $errors ERROR(S)"; exit 1; }
log "Done."
