#!/usr/bin/env bash
# scripts/install-mailutils.sh
# Installs 'mail' command for sending security reports via email.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"

log "Installing mailutils (for email notifications)..."

case "$(pm)" in
  pacman)
    # On Arch/Manjaro, 'mail' is provided by 's-nail'
    pm_install s-nail
    log "✅ Installed s-nail (provides 'mail' command)."
    ;;
  apt)
    # On Debian/Ubuntu, install 'mailutils'
    pm_install mailutils
    log "✅ Installed mailutils."
    ;;
  *)
    log "Unsupported package manager: $(pm)"
    exit 1
    ;;
esac