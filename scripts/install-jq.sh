#!/usr/bin/env bash
set -euo pipefail

# install-jq.sh — Install jq (lightweight JSON processor)
# Uses init_scripts.sh for OS detection and logging.

# Source init (defines $OS, info/warning/error, etc.)
if [[ -f "./init_scripts.sh" ]]; then
  # shellcheck disable=SC1091
  source ./init_scripts.sh
else
  echo "[ERROR] init_scripts.sh not found in current directory." >&2
  exit 1
fi

# Components to install
TO_INSTALL=()

# Descriptions (default = Debian/Ubuntu package names)
declare -A descriptions=(
  ["jq"]="jq (lightweight JSON processor)."
)

# Adjust per-OS (package name is 'jq' almost everywhere)
case "$OS" in
  manjaro|arch)
    descriptions=( ["jq"]="jq (lightweight JSON processor)." )
    ;;
  fedora|centos|redhat|opensuse|alpine)
    descriptions=( ["jq"]="jq (lightweight JSON processor)." )
    ;;
  macos)
    descriptions=( ["jq"]="jq (Homebrew)." )
    ;;
  *)
    : # keep default
    ;;
esac

# Check if installed
check_installed() {
  local pkg="$1"
  case "$OS" in
    manjaro|arch)
      if command -v pacman >/dev/null 2>&1; then pacman -Qi "$pkg" &>/dev/null; else pamac info "$pkg" &>/dev/null; fi
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
      command -v jq >/dev/null 2>&1
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

# Nothing to do?
if [[ ${#TO_INSTALL[@]} -eq 0 ]]; then
  info "jq already installed. Exiting."
  exit 0
fi

info "Components to install: ${TO_INSTALL[*]}"

# Install per OS
case "$OS" in
  ubuntu|debian|raspbian|wsl)
    sudo apt-get update -y
    for component in "${TO_INSTALL[@]}"; do
      info "Installing $component on $OS..."
      sudo apt-get install -y "$component"
    done
    ;;

  manjaro|arch)
    i
