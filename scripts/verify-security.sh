#!/usr/bin/env bash
set -euo pipefail

# verify-security.sh — Check packages, services, and Falco rules
# Works on Manjaro/Arch (pacman) and Debian/Ubuntu (apt/dpkg)

COLOR_OK="\033[32m"; COLOR_WARN="\033[33m"; COLOR_ERR="\033[31m"; COLOR_DIM="\033[90m"; COLOR_OFF="\033[0m"
ok()   { printf "${COLOR_OK}✔${COLOR_OFF} %s\n" "$*"; }
warn() { printf "⚠ ${COLOR_WARN}%s${COLOR_OFF}\n" "$*"; }
err()  { printf "✘ ${COLOR_ERR}%s${COLOR_OFF}\n" "$*"; }
dim()  { printf "${COLOR_DIM}%s${COLOR_OFF}\n" "$*"; }

os_id() { . /etc/os-release 2>/dev/null || true; echo "${ID:-unknown}"; }
has()   { command -v "$1" >/dev/null 2>&1; }

pm_detect() {
  if has pacman; then echo pacman; return; fi
  if has apt-get && has dpkg; then echo apt; return; fi
  echo unknown
}

pm="$(pm_detect)"
id="$(os_id)"

# --- Package lists ---
declare -a PKGS_BASE=(lynis rkhunter chkrootkit ufw fail2ban lsof iproute2 logrotate mailutils falco)
case "$pm" in
  pacman) PKG_AUDIT=(audit) ;;
  apt)    PKG_AUDIT=(auditd audispd-plugins) ;;
  *)      PKG_AUDIT=() ;;
esac
PKGS=("${PKGS_BASE[@]}" "${PKG_AUDIT[@]}")

# --- Service list ---
SERVICES=(
  falco.service
  falco-bpf.service
  falco-modern-bpf.service
  auditd.service
  fail2ban.service
  security-check.timer
)

# --- Helpers for package/version checks ---
pkg_installed() {
  case "$pm" in
    pacman) pacman -Qi "$1" >/dev/null 2>&1 ;;
    apt)    dpkg -s "$1" >/dev/null 2>&1 ;;
    *)      return 1 ;;
  esac
}

pkg_version() {
  case "$pm" in
    pacman) pacman -Qi "$1" 2>/dev/null | awk -F': *' '/^Version/{print $2; exit}' ;;
    apt)    dpkg -s "$1" 2>/dev/null | awk -F': *' '/^Version/{print $2; exit}' ;;
    *)      echo "" ;;
  esac
}

suggest_install_line() {
  case "$pm" in
    pacman) echo "sudo pacman -S --needed ${*}" ;;
    apt)    echo "sudo apt-get update && sudo apt-get install -y ${*}" ;;
    *)      echo "# Unsupported package manager" ;;
  esac
}

# --- Start report ---
echo "== linux-setup security verification =="
echo "OS: $id   PM: $pm"
echo

# --- Package checks ---
missing_pkgs=()
ok_pkgs=()
echo "== Checking packages =="
if [[ "$pm" == "unknown" ]]; then
  err "Unsupported distro (need pacman or apt)"
else
  for p in "${PKGS[@]}"; do
    if pkg_installed "$p"; then
      v="$(pkg_version "$p")"
      ok_pkgs+=("$p")
      ok "$p installed${v:+ (version $v)}"
    else
      missing_pkgs+=("$p")
      err "$p missing"
    fi
  done
  if ((${#missing_pkgs[@]})); then
    echo
    warn "Install missing packages with:"
    echo "$(suggest_install_line "${missing_pkgs[@]}")"
  fi
fi
echo

# --- Binary checks ---
echo "== Checking key binaries =="
BINARIES=(falco lynis rkhunter chkrootkit ufw fail2ban-client auditctl ss lsof mail)
missing_bins=()
ok_bins=()
for b in "${BINARIES[@]}"; do
  if has "$b"; then ok_bins+=("$b"); ok "$b found"; else missing_bins+=("$b"); warn "$b not found in PATH"; fi
done
echo

# --- Service checks ---
echo "== Checking services =="
services_running=()
services_stopped=()
services_notfound=()
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
    if systemctl is-active --quiet "$svc"; then
      services_running+=("$svc")
      ok "$svc is running"
    else
      services_stopped+=("$svc")
      err "$svc is not running"
    fi
  else
    services_notfound+=("$svc")
    warn "$svc not installed"
  fi
done
echo

# --- Falco rules validation ---
echo "== Validating Falco local rules =="
RULE="/etc/falco/falco_rules.local.yaml"
if has falco; then
  if [[ -f "$RULE" ]]; then
    if falco --validate "$RULE" >/dev/null 2>&1; then
      ok "Falco local rules validate ($RULE)"
    else
      err "Falco rule validation failed ($RULE)"
      falco --validate "$RULE" || true
    fi
  else
    warn "No local rules at $RULE (optional)"
  fi
else
  warn "Falco binary not present; skipping validation"
fi
echo

# --- Summary ---
echo "== Summary =="

if ((${#ok_pkgs[@]})); then
  ok "Installed packages: ${ok_pkgs[*]}"
fi
if ((${#missing_pkgs[@]})); then
  err "Missing packages: ${missing_pkgs[*]}"
fi

if ((${#ok_bins[@]})); then
  ok "Binaries present: ${ok_bins[*]}"
fi
if ((${#missing_bins[@]})); then
  warn "Missing binaries: ${missing_bins[*]}"
fi

if ((${#services_running[@]})); then
  ok "Running services: ${services_running[*]}"
fi
if ((${#services_stopped[@]})); then
  err "Stopped services: ${services_stopped[*]}"
fi
if ((${#services_notfound[@]})); then
  warn "Not installed services: ${services_notfound[*]}"
fi

# exit code
rc=0
if ((${#missing_pkgs[@]})) || ((${#services_stopped[@]})); then
  rc=1
fi
exit "$rc"
