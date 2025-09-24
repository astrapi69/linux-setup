#!/usr/bin/env bash
set -euo pipefail

# install-fail2ban.sh — Install Fail2ban (provides fail2ban-client)
# Uses init_scripts.sh for OS detection and logging.

# Source the init script (defines $OS, info/warning/error, etc.)
if [[ -f "./init_scripts.sh" ]]; then
  # shellcheck disable=SC1091
  source ./init_scripts.sh
else
  echo "[ERROR] init_scripts.sh not found in current directory." >&2
  exit 1
fi

# Array for packages to install
TO_INSTALL=()

# Descriptions (default = Debian/Ubuntu names)
declare -A descriptions=(
  ["fail2ban"]="Fail2ban (Intrusion prevention tool, provides fail2ban-client)."
)

# Adjust names based on distro
case "$OS" in
  manjaro|arch)
    descriptions=( ["fail2ban"]="Fail2ban (Intrusion prevention tool)." )
    ;;
  fedora|centos|redhat)
    descriptions=( ["fail2ban"]="Fail2ban (Intrusion prevention tool)." )
    ;;
  opensuse)
    descriptions=( ["fail2ban"]="Fail2ban (Intrusion prevention tool)." )
    ;;
  alpine)
    descriptions=( ["fail2ban"]="Fail2ban (Intrusion prevention tool)." )
    ;;
  macos)
    descriptions=( ["fail2ban"]="Fail2ban — not supported on macOS." )
    ;;
esac

# Helper: check if package is installed
check_installed() {
  local pkg="$1"
  case "$OS" in
    manjaro|arch)
      pacman -Qi "$pkg" &>/dev/null
      ;;
    ubuntu|debian|raspbian|wsl)
      dpkg -s "$pkg" &>/dev/null
      ;;
    fedora|centos|redhat|opensuse)
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

# Check packages
for package in "${!descriptions[@]}"; do
  if check_installed "$package"; then
    info "$package already installed. Skipping."
  else
    info "Preparing to install ${descriptions[$package]}"
    TO_INSTALL+=("$package")
  fi
done

# Early exit unsupported OS
if [[ "$OS" == "macos" ]]; then
  error "Fail2ban is not supported on macOS."
  exit 1
fi

# Exit if already installed
if [[ ${#TO_INSTALL[@]} -eq 0 ]]; then
  info "Fail2ban already installed. Exiting."
else
  info "Components to install: ${TO_INSTALL[*]}"

  case "$OS" in
    ubuntu|debian|raspbian|wsl)
      sudo apt-get update -y
      for component in "${TO_INSTALL[@]}"; do
        info "Installing $component..."
        sudo apt-get install -y "$component"
      done
      ;;
    manjaro|arch)
      sudo pacman -Sy --noconfirm
      for component in "${TO_INSTALL[@]}"; do
        info "Installing $component..."
        sudo pacman -S --needed --noconfirm "$component"
      done
      ;;
    fedora|centos|redhat)
      sudo dnf install -y "${TO_INSTALL[@]}" || sudo yum install -y "${TO_INSTALL[@]}"
      ;;
    opensuse)
      sudo zypper refresh
      sudo zypper install -y "${TO_INSTALL[@]}"
      ;;
    alpine)
      sudo apk update
      sudo apk add "${TO_INSTALL[@]}"
      ;;
    *)
      error "Unsupported OS: $OS"
      exit 1
      ;;
  esac
fi

# Verify binary
if command -v fail2ban-client >/dev/null 2>&1; then
  info "✅ fail2ban-client installed successfully."
else
  error "❌ fail2ban-client not found after install."
  exit 1
fi

# Enable service if systemd unit exists
if systemctl list-unit-files | grep -q '^fail2ban\.service'; then
  info "Enabling and starting fail2ban service..."
  sudo systemctl enable --now fail2ban.service
else
  warning "fail2ban.service not found (may not be packaged with this distro)."
fi

info "Fail2ban installation script completed successfully on $OS."
