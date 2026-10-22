# scripts

Reusable pod/infra setup scripts.

| Script | Purpose |
|--------|---------|
| `setup-pod-gcloud` | Install gcloud CLI + gcdn on a RunPod/remote pod via SSH |
| `pod-sync-gcs-albums.sh` | Download & unzip GCS album zips to a pod workspace |
| `setup-pod-claude` | Install + authenticate Claude Code, GitHub creds, monitoring tools and `podmon` on a pod; chains `setup-pod-gcloud` |
| `podmon` | One tmux window on the pod: nvtop + htop + disk/IO + log tail (installed by `setup-pod-claude`) |
| `creds-keeper` | Check/re-login local gcloud, ADC and GitHub logins (Workspace reauth expires them) |

Scripts are symlinked into `~/bin` so they are on `PATH`; keep the symlinks pointing here.
