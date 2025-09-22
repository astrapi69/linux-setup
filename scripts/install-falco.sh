#!/usr/bin/env bash
# scripts/install-falco.sh
# Installs Falco for real-time threat detection.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"

log "Installing Falco..."

case "$(os_id)" in
    arch|manjaro)
        # Install via AUR
        if ! command -v yay >/dev/null; then
            "$DIR/ensure_yay.sh"
        fi
        yay -S --noconfirm falco
        ;;

    ubuntu|debian)
        # Install via official Falco repository
        if ! dpkg -s falco >/dev/null 2>&1; then
            log "Adding Falco official repository..."
            sudo install -d /usr/share/keyrings
            curl -fsSL https://falco.org/repo/falcosecurity-packages.asc \
                | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" \
                | sudo tee /etc/apt/sources.list.d/falcosecurity.list >/dev/null
            sudo apt-get update
            sudo apt-get install -y falco
        fi
        ;;

    *)
        log "Unsupported distro: $(os_id)"
        exit 1
        ;;
esac

# Reload systemd and enable the correct Falco service unit
log "Enabling Falco service..."
sudo systemctl daemon-reload

# Stop any potentially conflicting services
sudo systemctl stop falco.service falco-bpf.service falco-modern-bpf.service 2>/dev/null || true

# Enable the preferred unit
if systemctl list-unit-files --type=service | grep -q '^falco-modern-bpf\.service'; then
    sudo systemctl enable --now falco-modern-bpf.service
    log "✅ Falco (modern-bpf) enabled and started."
elif systemctl list-unit-files --type=service | grep -q '^falco-bpf\.service'; then
    sudo systemctl enable --now falco-bpf.service
    log "✅ Falco (bpf) enabled and started."
else
    # Fallback to legacy unit
    if sudo systemctl enable --now falco.service; then
        log "✅ Falco (legacy) enabled and started."
    else
        log "⚠️  Falco installation successful, but no service unit could be activated."
        exit 1
    fi
fi

# Copy custom rules if they exist
if [ -f "$DIR/../security/config/falco_rules_local.yaml" ]; then
    sudo mkdir -p /etc/falco
    sudo cp "$DIR/../security/config/falco_rules_local.yaml" /etc/falco/
    sudo systemctl restart falco-modern-bpf.service falco-bpf.service falco.service 2>/dev/null || true
    log "✅ Custom Falco rules deployed."
fi