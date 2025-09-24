#!/usr/bin/env bash
# scripts/install-lynis.sh
# Installs Lynis system auditing tool.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"

log "Installing Lynis..."

pm_install lynis

log "✅ Lynis installed. Run 'sudo lynis audit system' to start an audit."