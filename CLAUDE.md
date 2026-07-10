# scripts

Reusable shell scripts for provisioning and syncing data on ephemeral GPU pods (RunPod, etc.).

## Scripts

### `setup-pod-gcloud`

Runs **from your Mac** over SSH. Installs gcloud CLI + `gcdn` on a remote pod and copies local GCP credentials.

- **Args:** `HOST PORT` (from RunPod UI; change every session)
- **SSH key:** `~/.ssh/id_ed25519` (hardcoded)
- **What it installs:** gcloud CLI, `gcdn` (CDN-accelerated GCS download wrapper from Aftershoot), ADC credentials
- **Idempotent:** skips already-installed components
- **Credential flow:** copies `~/.config/gcloud/{application_default_credentials.json,credentials.db,access_tokens.db}` to pod, sets restrictive permissions

### `pod-sync-gcs-albums.sh`

Runs **on the pod**. Downloads album zips from a GCS bucket via `gcdn` and unzips them.

- **Requires:** `gcloud` + `gcdn` on the pod (install via `setup-pod-gcloud`)
- **Hardcoded paths:**
  - GCS bucket: `gs://ml-culling/culling-labeller-bucket/Selection_Model_Datasets/Selections_FullAlbums_dataset`
  - Download dir: `/workspace/vk_culling/downloads`
  - Extract dir: `/workspace/culling_ws`
  - Log: `/workspace/vk_culling/runs/pod_sync_gcs.log`
- **Modes:** `--list` (dry-run), `--download-only`, `--unzip-only`, default syncs both
- **Idempotent:** uses `.extract_complete` marker files; validates existing zips with `unzip -tq`, re-downloads corrupt ones
- **Atomic downloads:** writes to `.part` file, validates, then `mv`

## Conventions

- Scripts use `set -uo pipefail`, `fail()` for fatal errors, structured logging
- Exit code 0 = success, non-zero = errors occurred (count tracked)
- `gcdn` is a private Aftershoot binary that wraps `gcloud storage cp` with CDN-signed URLs to bypass 403s on direct GCS access
