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

### `setup-pod-claude`

Runs **from your Mac** over SSH. Sets up a pod in one command, then chains `setup-pod-gcloud`.

- **Args:** `HOST PORT`, or paste RunPod's whole command: `setup-pod-claude ssh root@HOST -p PORT -i KEY`
- **Claude auth source (first found):** `$CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`), `$ANTHROPIC_API_KEY`, macOS Keychain
- **Also sets up:** GitHub over HTTPS (token from `$GH_TOKEN`/`$GITHUB_TOKEN`/`gh auth token`; `git@github.com:` remotes rewritten to https), monitoring tools (nvtop htop btop iotop ncdu sysstat tmux), `podmon`
- **Idempotent:** leaves working Claude/GitHub creds alone; `FORCE=1` overwrites, `SKIP_GCLOUD=1` skips the gcloud chain
- **Gotcha:** the remote script is fed through `bash -s`, so any remote command that reads stdin (e.g. `claude -p`, `apt-get`) must use `</dev/null` or it swallows the rest of the script
- Finds its siblings `setup-pod-gcloud` and `podmon` next to itself (via the `~/bin` symlinks)

### `podmon`

Runs **on the pod** (copied to `/usr/local/bin/podmon` by `setup-pod-claude`). `podmon [LOGFILE]` opens a 4-pane tmux dashboard; `podmon --kill` closes it.

### `creds-keeper`

Runs **on your Mac**. Checks gcloud login, ADC and `gh`; `--fix` re-logins what expired, `--notify` sends a macOS notification, `--install-agent` runs it every 30 min via launchd. The Workspace reauth policy makes copied refresh tokens expire periodically, and the sign-in must be done by the user; `setup-pod-gcloud` now refuses to copy expired creds.

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
