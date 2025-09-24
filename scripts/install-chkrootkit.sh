#!/usr/bin/env bash
set -euo pipefail

# install-chkrootkit.sh — install chkrootkit (rootkit scanner)
# Uses init_scripts.sh (logging + $OS).
# Arch/Manjaro: AUR via yay, with auto-patch on build failure.
# Debian/Ubuntu: apt.

# --- locate and source init ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
pushd "$SCRIPT_DIR" >/dev/null

if [[ ! -f "./init_scripts.sh" ]]; then
  echo "[ERROR] ./init_scripts.sh not found next to this script." >&2
  popd >/dev/null || true
  exit 1
fi
# shellcheck disable=SC1091
source "./init_scripts.sh"

popd >/dev/null

if [[ -z "${OS:-}" || "$OS" == "unknown" ]]; then
  error "OS detection failed in init_scripts.sh"
  exit 1
fi

# --- helpers ---
ensure_yay() {
  if command -v yay >/dev/null 2>&1; then return 0; fi
  info "AUR helper 'yay' not found, trying scripts/ensure_yay.sh"
  if [[ -x "$SCRIPT_DIR/ensure_yay.sh" ]]; then
    "$SCRIPT_DIR/ensure_yay.sh"
  else
    error "Missing $SCRIPT_DIR/ensure_yay.sh. Install yay manually:"
    echo "  sudo pacman -S --needed base-devel git"
    echo "  git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
    return 1
  fi
}

aur_build_with_patch() {
  # Patch the AUR snapshot to fix signal handler signature build error.
  local tmp
  tmp="$(mktemp -d -t chkrootkit-aur-XXXXXX)"
  info "Cloning AUR snapshot to: $tmp"
  pushd "$tmp" >/dev/null
  # get AUR build files
  yay -G chkrootkit >/dev/null
  cd chkrootkit

  # Defensive: patch both declaration and definition to 'void read_status(int)'
  # Only apply if file exists and matches older signature.
  if [[ -f chklastlog.c ]]; then
    sed -i 's/^[[:space:]]*void[[:space:]]\+read_status()[[:space:]]*;/void read_status(int);/' chklastlog.c || true
    sed -i 's/^[[:space:]]*void[[:space:]]\+read_status()[[:space:]]*{/void read_status(int) {/' chklastlog.c || true
  fi

  # Build and install
  info "Building chkrootkit with patched sources..."
  if MAKEFLAGS="${MAKEFLAGS:-}" PKGEXT='.pkg.tar.zst' makepkg -si --noconfirm; then
    popd >/dev/null
    rm -rf "$tmp"
    return 0
  else
    popd >/dev/null
    rm -rf "$tmp"
    return 1
  fi
}

verify_binary() {
  if command -v chkrootkit >/dev/null 2>&1; then
    info "chkrootkit installed successfully: $(command -v chkrootkit)"
    return 0
  fi
  return 1
}

info "Detected OS: $OS"
info "Installing chkrootkit on $OS ..."

case "$OS" in
  arch|manjaro)
    # Ensure AUR helper
    ensure_yay || exit 1

    set +e
    # 1) Try the straightforward AUR install
    yay -S --needed --noconfirm chkrootkit
    rc=$?
    set -e

    if (( rc != 0 )); then
      warning "AUR build failed for 'chkrootkit'. Attempting auto-patch build ..."
      if ! aur_build_with_patch; then
        error "Patched AUR build also failed."
      fi
    fi

    if verify_binary; then
      exit 0
    else
      error "chkrootkit binary not found in PATH after install."
      echo "Pragmatic alternatives:"
      echo " - Keep using rkhunter + Lynis (already supported in your project)."
      echo " - Consider ClamAV for on-disk malware scanning."
      exit 1
    fi
    ;;

  ubuntu|debian)
    sudo apt-get update
    sudo apt-get install -y chkrootkit
    if verify_binary; then
      exit 0
    else
      error "chkrootkit binary not found in PATH after apt install."
      exit 1
    fi
    ;;

  *)
    error "Unsupported distribution '$OS'. Please install chkrootkit manually."
    exit 1
    ;;
esac
