#!/usr/bin/env bash
set -euo pipefail

# install-ufw.sh — Install Uncomplicated Firewall (UFW) across OSes
# Uses init_scripts.sh for OS detection and logging.
#
# Optional env flags:
#   UFW_ENABLE=true          # apply defaults and enable UFW
#   UFW_ALLOW_SSH=true       # allow OpenSSH (port 22) before enabling
#   UFW_DEFAULT_IN=deny      # set default incoming policy (deny|allow)
#   UFW_DEFAULT_OUT=allow    # set default outgoing policy (deny|allow)

# Source the common initialization script (defines $OS, info/warning/error, etc.)
if [[ -f "./init_scripts.sh" ]]; then
  # shellcheck disable=SC1091
  source ./init_scripts.sh
else
  echo "[ERROR] init_scripts.sh not found in current directory." >&2
  exit 1
fi

UFW_ENABLE="${UFW_ENABLE:-false}"
UFW_ALLOW_SSH="${UFW_ALLOW_SSH:-false}"
UFW_DEFAULT_IN="${UFW_DEFAULT_IN:-deny}"
UFW_DEFAULT_OUT="${UFW_DEFAULT_OUT:-allow}"

# Components to install (key = package name on that OS)
TO_INSTALL=()

# Descriptions (default = Debian/Ubuntu names)
declare -A descriptions=(
  ["ufw"]="UFW (Uncomplicated Firewall)."
)

# Map/adjust package names for other OS families if needed
case "$OS" in
  manjaro|arch)
    # Arch/Manjaro package is also 'ufw'
    descriptions=( ["ufw"]="UFW (Uncomplicated Firewall)." )
    ;;
  fedora|centos|redhat)
    # Fedora has 'ufw' in repos; RHEL/CentOS often prefer firewalld but ufw exists via EPEL/newer repos
    descriptions=( ["ufw"]="UFW (Uncomplicated Firewall)." )
    ;;
  opensuse)
    # openSUSE also ships ufw
    descriptions=( ["ufw"]="UFW (Uncomplicated Firewall)." )
    ;;
  alpine)
    descriptions=( ["ufw"]="UFW (Uncomplicated Firewall)." )
    ;;
  macos)
    # Not supported (macOS uses pf). We’ll print an error later.
    descriptions=( ["ufw"]="UFW (Uncomplicated Firewall) — not supported on macOS." )
    ;;
  *)
    # leave default mapping
    :
    ;;
esac

# Helper: check if installed
check_installed() {
  local pkg="$1"
  case "$OS" in
    manjaro|arch)
      if command -v pacman >/dev/null 2>&1; then pacman -Qi "$pkg" &>/dev/null; else pamac info "$pkg" &>/dev/null; fi
      ;;
    ubuntu|debian|raspbian|wsl)
      dpkg -s "$pkg" &>/dev/null
      ;;
    fedora|centos|redhat)
      # dnf/yum based systems
      rpm -q "$pkg" &>/dev/null
      ;;
    opensuse)
      rpm -q "$pkg" &>/dev/null
      ;;
    alpine)
      apk info -e "$pkg" &>/dev/null
      ;;
    macos)
      false
      ;;
    *)
      false
      ;;
  esac
}

# Build install list
for package in "${!descriptions[@]}"; do
  if check_installed "$package"; then
    info "$package is already installed. Skipping."
  else
    info "Preparing to install ${descriptions[$package]}"
    TO_INSTALL+=("$package")
  fi
done

# Early exit on unsupported OS
if [[ "$OS" == "macos" ]]; then
  error "UFW is not supported on macOS (use pf instead)."
  exit 1
fi

# If nothing to do
if [[ ${#TO_INSTALL[@]} -eq 0 ]]; then
  info "All UFW components are already installed."
else
  info "Components to install: ${TO_INSTALL[*]}"

  case "$OS" in
    ubuntu|debian|raspbian|wsl)
      info "Debian-based system detected. Updating package database..."
      sudo apt-get update -y
      for component in "${TO_INSTALL[@]}"; do
        info "Installing $component (${descriptions[$component]})..."
        sudo apt-get install -y "$component"
      done
      ;;

    manjaro|arch)
      if command -v pamac >/dev/null 2>&1; then
        info "Arch-based system (pamac). Refreshing database..."
        pamac update --force-refresh || true
        for component in "${TO_INSTALL[@]}"; do
          info "Installing $component (${descriptions[$component]})..."
          pamac install --no-confirm "$component"
        done
      else
        info "Arch-based system (pacman). Syncing..."
        sudo pacman -Sy --noconfirm
        for component in "${TO_INSTALL[@]}"; do
          info "Installing $component (${descriptions[$component]})..."
          sudo pacman -S --needed --noconfirm "$component"
        done
      fi
      ;;

    fedora|centos|redhat)
      info "RPM-based system detected. Updating package database…"
      sudo dnf -y makecache || sudo yum -y makecache || true
      for component in "${TO_INSTALL[@]}"; do
        info "Installing $component (${descriptions[$component]})..."
        sudo dnf install -y "$component" || sudo yum install -y "$component"
      done
      ;;

    opensuse)
      info "openSUSE detected. Refreshing…"
      sudo zypper refresh
      for component in "${TO_INSTALL[@]}"; do
        info "Installing $component (${descriptions[$component]})..."
        sudo zypper install -y "$component"
      done
      ;;

    alpine)
      info "Alpine Linux detected. Updating…"
      sudo apk update
      for component in "${TO_INSTALL[@]}"; do
        info "Installing $component (${descriptions[$component]})..."
        sudo apk add "$component"
      done
      ;;

    *)
      error "Unsupported OS: $OS"
      exit 1
      ;;
  esac
fi

# Verify installation
if ! check_installed "ufw"; then
  error "❌ ufw installation failed or package not found after install."
  exit 1
fi
info "✅ ufw package is installed."

# Optional: configure & enable
if [[ "$UFW_ENABLE" == "true" ]]; then
  info "Applying UFW defaults: incoming=$UFW_DEFAULT_IN, outgoing=$UFW_DEFAULT_OUT"
  sudo ufw --force default "${UFW_DEFAULT_IN}"
  sudo ufw --force default "${UFW_DEFAULT_OUT}"

  if [[ "$UFW_ALLOW_SSH" == "true" ]]; then
    if command -v sshd >/dev/null 2>&1 || systemctl list-unit-files | grep -q '^sshd\.service'; then
      info "Allowing OpenSSH (22/tcp) before enabling UFW…"
      sudo ufw allow OpenSSH || sudo ufw allow 22/tcp || true
    else
      info "No sshd detected; skipping OpenSSH allow."
    fi
  fi

  # Ensure systemd unit exists (varies by distro)
  if systemctl list-unit-files | grep -q '^ufw\.service'; then
    info "Enabling ufw systemd service at boot…"
    sudo systemctl enable ufw.service || true
  fi

  info "Enabling UFW now…"
  # --force skips the interactive prompt
  sudo ufw --force enable

  # Show status
  sudo ufw status verbose || true
else
  info "UFW_ENABLE=false — skipping enablement/config. Set UFW_ENABLE=true to apply defaults and enable UFW."
fi

info "UFW installation script completed on $OS."
