#!/usr/bin/env bash
# Provision full security stack from this repo (Ubuntu/Debian focused).
# Idempotent: safe to re-run. Requires root.

set -euo pipefail

log() { printf '\033[1;34m== %s\033[0m\n' "$*"; }
warn(){ printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# --- root check
[[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run as root: sudo bash $0"

# --- repo paths
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SEC_DIR="${REPO_ROOT}/security"
CFG_DIR="${SEC_DIR}/config"
SYS_DIR="${SEC_DIR}/systemd"
LOG_DIR="${LOG_DIR:-/var/log/linux-setup}"

# --- OS detection (simple)
PM=""
if command -v apt >/dev/null 2>&1; then
  PM="apt"
elif command -v apt-get >/dev/null 2>&1; then
  PM="apt"
elif command -v pacman >/dev/null 2>&1; then
  PM="pacman"
fi

[[ -n "$PM" ]] || die "Unsupported distro. Need apt or pacman."

log "Repo: $REPO_ROOT"
log "Log dir: $LOG_DIR"
log "Package manager: $PM"

# --- packages
install_apt() {
  export DEBIAN_FRONTEND=noninteractive
  apt update -y
  # Core stack (match your verify script)
  apt install -y lynis rkhunter chkrootkit ufw fail2ban lsof iproute2 logrotate mailutils auditd audispd-plugins
  # Falco from distro (if available) or skip silently; your verify expects it
  if ! dpkg -s falco >/dev/null 2>&1; then
    warn "Package 'falco' not found in apt or not installed; skipping falco install (verify will warn)."
  fi
}
install_pacman() {
  pacman -Sy --noconfirm lynis rkhunter chkrootkit ufw fail2ban lsof iproute2 logrotate mailutils auditd
  warn "Falco not auto-installed on pacman path here. Add AUR if needed."
}

log "Installing packages…"
case "$PM" in
  apt)    install_apt ;;
  pacman) install_pacman ;;
esac

# --- baseline config
log "Preparing log directory"
install -d -m 0750 -o root -g adm "$LOG_DIR"

log "Writing /etc/default/linux-setup"
cat >/etc/default/linux-setup <<EOF
LS_REPO="${REPO_ROOT}"
LOG_DIR="${LOG_DIR}"
EOF
chmod 0644 /etc/default/linux-setup

# Fail2ban
if [[ -f "${CFG_DIR}/fail2ban/jail.local" ]]; then
  log "Installing Fail2ban jail.local"
  install -D -m 0644 "${CFG_DIR}/fail2ban/jail.local" /etc/fail2ban/jail.d/linux-setup.local
fi

# Falco local rules
if [[ -f "${CFG_DIR}/falco_rules_local.yaml" ]]; then
  log "Installing Falco local rules"
  install -D -m 0644 "${CFG_DIR}/falco_rules_local.yaml" /etc/falco/falco_rules.local.yaml || warn "Falco rules copy failed (Falco not present?)."
fi

# auditd
if [[ -f "${CFG_DIR}/audit.rules" ]]; then
  log "Installing audit rules"
  install -D -m 0640 "${CFG_DIR}/audit.rules" /etc/audit/rules.d/linux-setup.rules
fi

# optional env file
if [[ -f "${CFG_DIR}/security.env" ]]; then
  log "Placing /etc/security.d/linux-setup.env"
  install -D -m 0644 "${CFG_DIR}/security.env" /etc/security.d/linux-setup.env
fi

# --- UFW sane defaults (idempotent)
log "Configuring UFW"
ufw --force enable || true
ufw allow OpenSSH || true
ufw default deny incoming
ufw default allow outgoing

# --- systemd units (service + timer)
SERVICE_DST="/etc/systemd/system/security-check.service"
TIMER_DST="/etc/systemd/system/security-check.timer"

log "Installing systemd units"
if [[ -f "${SYS_DIR}/security-check.service" ]]; then
  install -D -m 0644 "${SYS_DIR}/security-check.service" "${SERVICE_DST}"
else
  # Fallback: generate service on the fly
  cat >"${SERVICE_DST}" <<'EOF'
[Unit]
Description=Linux-Setup Security Report
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/default/linux-setup
WorkingDirectory=${LS_REPO}/scripts
ExecStart=/usr/bin/env bash ${LS_REPO}/scripts/verify-security.sh
StandardOutput=append:${LOG_DIR}/security_check_%Y-%m-%d.log
StandardError=append:${LOG_DIR}/security_check_%Y-%m-%d.log
User=root
EOF
fi

if [[ -f "${SYS_DIR}/security-check.timer" ]]; then
  install -D -m 0644 "${SYS_DIR}/security-check.timer" "${TIMER_DST}"
else
  cat >"${TIMER_DST}" <<'EOF'
[Unit]
Description=Daily security verification
[Timer]
OnCalendar=*-*-* 07:00:00
Persistent=true
RandomizedDelaySec=10m
[Install]
WantedBy=timers.target
EOF
fi

systemctl daemon-reload
systemctl enable --now security-check.timer

# --- restart/enable core services
log "Enabling services"
systemctl enable --now auditd || true
systemctl enable --now fail2ban || true
# Prefer modern-bpf where present; don't run two Falco drivers concurrently
if systemctl list-unit-files | grep -q '^falco-modern-bpf\.service'; then
  systemctl enable --now falco.service falco-modern-bpf.service || true
  systemctl disable --now falco-bpf.service || true
elif systemctl list-unit-files | grep -q '^falco\.service'; then
  systemctl enable --now falco.service || true
fi

# --- baselines & quick checks
log "Updating rkhunter signatures and baseline"
command -v rkhunter >/dev/null 2>&1 && rkhunter --update || true
command -v rkhunter >/dev/null 2>&1 && rkhunter --propupd || true

log "Quick chkrootkit run (non-fatal)"
command -v chkrootkit >/dev/null 2>&1 && chkrootkit || true

log "Quick Lynis (non-fatal)"
command -v lynis >/dev/null 2>&1 && lynis audit system --quick || true

# --- immediate first security check (creates log)
log "Running initial security-check.service"
if ! systemctl start security-check.service; then
  warn "Initial run failed. Inspect: journalctl -xeu security-check.service"
fi

log "Done. Logs under: ${LOG_DIR}"
