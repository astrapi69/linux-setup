#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/common.sh"

case "$(os_id)" in
  arch|manjaro)
    # AUR auf Arch/Manjaro
    if ! command -v yay >/dev/null; then
      "$DIR/ensure_yay.sh"
    fi
    yay -S --noconfirm falco
    ;;
  ubuntu|debian)
    # Offizielles Falco-Repo für Debian/Ubuntu
    if ! dpkg -s falco >/dev/null 2>&1; then
      sudo install -d /usr/share/keyrings
      curl -fsSL https://falco.org/repo/falcosecurity-packages.asc \
        | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" \
        | sudo tee /etc/apt/sources.list.d/falcosecurity.list >/dev/null
      sudo apt-get update
      sudo apt-get install -y falco
    fi
    ;;
  *) echo "Unsupported distro"; exit 1 ;;
esac

# Units neu einlesen und **nur** reale Unit aktivieren (kein Alias!)
sudo systemctl daemon-reload
if systemctl list-unit-files | grep -q '^falco-modern-bpf\.service'; then
  sudo systemctl enable --now falco-modern-bpf.service
elif systemctl list-unit-files | grep -q '^falco-bpf\.service'; then
  sudo systemctl enable --now falco-bpf.service
else
  # Fallback (legacy/userspace)
  sudo systemctl enable --now falco.service || true
fi
