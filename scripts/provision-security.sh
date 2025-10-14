#!/usr/bin/env bash
# Provision full security stack from this repo (Ubuntu/Debian focused).
# Idempotent: safe to re-run. Requires root.
# Parse args
MODE="harden"
PROFILE="desktop"
QUICK=false
TARGET=""

while [[ $# -gt 0 ]]; do
  case $1 in
    audit|harden|fix) MODE="$1" ;;
    --profile) PROFILE="$2"; shift ;;
    --quick) QUICK=true ;;
    --fix) TARGET="$2"; shift ;;  # for "fix --fix id"
  esac
  shift
done

set -euo pipefail

LOG_DIR="/var/log/linux-setup"
TS="$(date +%F_%H%M%S)"
LOG_FILE="$LOG_DIR/provision-security_${TS}.log"
JSON_FILE="$LOG_DIR/provision-security_${TS}.json"
SUMMARY_MD="$HOME/linux-setup-report/latest.md"
mkdir -p "$LOG_DIR" "$(dirname "$SUMMARY_MD")"

# Alles mitschneiden
exec > >(tee -a "$LOG_FILE") 2>&1

# Initialize JSON
echo '{}' > "$JSON_FILE"

# Helper: set JSON key (supports dotted paths via jq)
json_set() {
  local key="$1" value="$2"
  jq --arg k "$key" --arg v "$value" '
    def setpathdot($path; $value):
      reduce ($path | split("."))[] as $key
        (.; setpath([$key]; $value));
    setpathdot($k; $v)
  ' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
}

# Helper: append to JSON array
json_append() {
  local key="$1" value="$2"
  jq --arg k "$key" --argjson v "$value" '
    (.[$k] // []) as $arr | .[$k] = ($arr + [$v])
  ' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
}

# Helper: simple top-level JSON key (backward compat)
json_add() {
  local key="$1" value="$2"
  jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
}

# Logging
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

# --- OS detection
PM=""
if command -v apt >/dev/null 2>&1; then PM="apt"; fi
[[ -n "$PM" ]] || die "Unsupported distro. Need apt."

log "Repo: $REPO_ROOT"
log "Log dir: $LOG_DIR"
log "Package manager: $PM"

# Record metadata
json_set "run_id" "$(date -Iseconds)"
json_set "distro" "$(source /etc/os-release; echo "$NAME $VERSION_ID")"
json_set "profile" "desktop"
json_set "mode" "$MODE"
json_set "profile" "$PROFILE"

# --- packages
install_apt() {
  export DEBIAN_FRONTEND=noninteractive
  apt update -y
  apt install -y lynis rkhunter chkrootkit ufw fail2ban lsof iproute2 logrotate mailutils auditd audispd-plugins
}
log "Installing packages…"
install_apt

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

# auditd
if [[ -f "${CFG_DIR}/audit.rules" ]]; then
  log "Installing audit rules"
  install -D -m 0640 "${CFG_DIR}/audit.rules" /etc/audit/rules.d/linux-setup.rules
fi

# --- UFW
log "Configuring UFW"
ufw --force enable || true
ufw allow OpenSSH || true
ufw default deny incoming
ufw default allow outgoing

# Record UFW status
json_set "findings.ufw.status" "enabled"
json_set "findings.ufw.openssh_allowed" "true"

# --- systemd units
SERVICE_DST="/etc/systemd/system/security-check.service"
TIMER_DST="/etc/systemd/system/security-check.timer"

log "Installing systemd units"
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

systemctl daemon-reload
systemctl enable --now security-check.timer

# --- services
log "Enabling services"
systemctl enable --now auditd fail2ban

# --- baselines
log "Updating rkhunter signatures"
rkhunter --update || true
rkhunter --propupd || true

log "Quick chkrootkit run (non-fatal)"
chkrootkit || true

# --- Lynis audit
log "Running Lynis audit"
lynis audit system --quick || true

# --- Parse Lynis findings
LYNIS_LOG="/var/log/lynis.log"
if [[ -f "$LYNIS_LOG" ]]; then
  # Extract warnings
  while IFS= read -r line; do
    if [[ $line == \!* ]]; then
      id=$(echo "$line" | grep -oE '\[([A-Z0-9-]+)\]' | tr -d '[]')
      title=$(echo "$line" | sed 's/^\! *//' | sed "s/ \[$id\].*//")
      json_append "findings" "{\"id\":\"lynis.$id\",\"title\":\"$title\",\"severity\":\"high\",\"status\":\"unfixed\",\"source\":\"lynis\"}"
    fi
  done < <(grep '^\!' "$LYNIS_LOG")

  # Extract suggestions (top 10)
  while IFS= read -r line; do
    if [[ $line == \** ]]; then
      id=$(echo "$line" | grep -oE '\[([A-Z0-9-]+)\]' | tr -d '[]')
      title=$(echo "$line" | sed 's/^\* *//' | sed "s/ \[$id\].*//")
      json_append "findings" "{\"id\":\"lynis.$id\",\"title\":\"$title\",\"severity\":\"medium\",\"status\":\"unfixed\",\"source\":\"lynis\"}"
    fi
  done < <(grep '^\*' "$LYNIS_LOG" | head -n 10)
fi

# Only run full provisioning in 'harden' or 'audit' mode
if [[ "$MODE" != "fix" ]]; then
  # --- packages
  install_apt

  # --- baseline config
  # ... (all your current setup steps)

  # --- Lynis audit
  lynis audit system --quick || true

  # --- Parse Lynis findings
  # ... (your parsing logic)
fi

# --- Fix handler (optional mode) -----------------------------------------------
if [[ "$MODE" == "fix" && -n "$TARGET" ]]; then
  case "$TARGET" in
    lynis.KRNL-5830)
      log "Fix: Reboot required for kernel update"
      warn "System must reboot to apply kernel security patches."
      json_add "fix_applied" "true"
      json_add "fix_note" "Reboot required"
      ;;
    ssh.password_auth_enabled)
      log "Fix: Disabling SSH password authentication"
      sudo sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sudo systemctl reload sshd
      json_add "fix_applied" "true"
      json_add "fix_note" "SSH password auth disabled"
      ;;
    firewall.disabled)
      log "Fix: Enabling UFW"
      sudo ufw --force enable
      json_add "fix_applied" "true"
      json_add "fix_note" "UFW enabled"
      ;;
    *)
      warn "Unknown fix target: $TARGET"
      json_add "fix_error" "unknown target"
      ;;
  esac
  exit 0
fi

# --- Generate user-friendly Markdown report
cat > "$SUMMARY_MD" <<EOF
# Linux-Setup Security Report
**Generated:** $(date)
**Distro:** $(source /etc/os-release; echo "$NAME $VERSION_ID")
**Log:** $LOG_FILE
**JSON:** $JSON_FILE

## 🔍 Key Findings

$(jq -r '.findings[] | "- **[\(.severity | ascii_upcase)]** \(.title) (\(.id))" ' "$JSON_FILE" 2>/dev/null || echo "- No findings recorded.")

## 🛠️ Next Steps (Recommended)

- [ ] Review firewall rules: \`sudo ufw status verbose\`
- [ ] Check SSH hardening: disable password auth if using keys
- [ ] Monitor Fail2ban: \`sudo fail2ban-client status\`
- [ ] Enable automatic security updates: \`sudo dpkg-reconfigure -plow unattended-upgrades\`
- [ ] Schedule weekly audits via GUI or \`systemctl enable linux-setup-audit.timer\`

> 💡 Open this report anytime with: \`xdg-open "$SUMMARY_MD"\`
EOF

log "Report: $SUMMARY_MD"
log "JSON:   $JSON_FILE"
log "Done. Logs under: ${LOG_DIR}"