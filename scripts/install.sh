#!/usr/bin/env bash

################################################################################
# install.sh                                                                   #
# Copies setup repo to ~/.setup, runs gen-profile.sh, and sources ~/.profile  #
################################################################################

# Define target setup directory
SETUP_DIR="$HOME/.setup"

echo "📦 Copying setup files to $SETUP_DIR..."
mkdir -p "$SETUP_DIR"
cp -r "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"/* "$SETUP_DIR"

# Run gen-profile.sh from new location
bash "$SETUP_DIR/scripts/gen-profile.sh"

# Add sourcing of utility scripts to the end of ~/.profile
PROFILE_FILE="$HOME/.profile"

for script in print_messages.sh detect_script_permissions.sh detect_os.sh; do
  SOURCE_LINE="source $SETUP_DIR/scripts/$script"
  if ! grep -Fxq "$SOURCE_LINE" "$PROFILE_FILE"; then
    echo "$SOURCE_LINE" >> "$PROFILE_FILE"
    echo "🔗 Added $SOURCE_LINE to $PROFILE_FILE"
  fi
done

# Define shell-specific RC file
SHELL_NAME=$(basename "$SHELL")

case "$SHELL_NAME" in
  bash)
    RC_FILE="$HOME/.bashrc"
    ;;
  zsh)
    RC_FILE="$HOME/.zshrc"
    # ⚠️ Do not source .profile in zsh, use a managed file instead
    SOURCE_LINE="source $SETUP_DIR/scripts/init_zsh.sh"
    ;;
  *)
    RC_FILE="$HOME/.profile"
    ;;
esac

# Only add if not already present
if ! grep -Fxq "$SOURCE_LINE" "$RC_FILE"; then
  echo -e "\n# linux-setup profile\n$SOURCE_LINE" >> "$RC_FILE"
  echo "🔗 Added $SOURCE_LINE to $RC_FILE"
else
  echo "✅ $RC_FILE already sources linux-setup"
fi
