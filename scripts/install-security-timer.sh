#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LS_REPO="${LS_REPO:-$REPO_ROOT}"
LOG_DIR="${LOG_DIR:-/var/log/linux-setup}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run as root: sudo env LS_REPO=\"$LS_REPO\" LOG_DIR=\"$LOG_DIR\" bash $0"; exit 1
fi

install -d -m 0750 -o root -g adm "$LOG_DIR"

# /etc/default/linux-setup
cat > /etc/default/linux-setup <<EOF
LS_REPO="$LS_REPO"
LOG_DIR="$LOG_DIR"
EOF
chmod 0644 /etc/default/linux-setup

install -D -m 0644 "$REPO_ROOT/security/systemd/security-check.service" /etc/systemd/system/security-check.service
install -D -m 0644 "$REPO_ROOT/security/systemd/security-check.timer"   /etc/systemd/system/security-check.timer

systemctl daemon-reload
systemctl enable --now security-check.timer
systemctl start security-check.service || true

echo "== status =="
systemctl status --no-pager security-check.service | sed -n '1,25p' || true

echo "== last log =="
LAST_LOG=$(ls -1t "$LOG_DIR"/security_check_*.log 2>/dev/null | head -n1 || true)
[[ -n "$LAST_LOG" ]] && tail -n 100 "$LAST_LOG" || echo "No log yet."
