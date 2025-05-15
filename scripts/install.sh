#!/usr/bin/env bash

################################################################################
# install.sh                                                                   #
# Runs gen-profile.sh and appends source ~/.profile to shell rc file          #
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run gen-profile.sh
bash "$SCRIPT_DIR/gen-profile.sh"

TARGET_PROFILE="$HOME/.profile"
SHELL_NAME=$(basename "$SHELL")
RC_FILE="$HOME/.bashrc"

if [[ "$SHELL_NAME" == "zsh" ]]; then
  RC_FILE="$HOME/.zshrc"
fi

SOURCE_LINE="source $TARGET_PROFILE"

# Append if not present
if ! grep -Fxq "$SOURCE_LINE" "$RC_FILE"; then
  echo -e "\n# Source generated profile\n$SOURCE_LINE" >> "$RC_FILE"
  echo "🔗 Added source to $RC_FILE"
else
  echo "✅ $RC_FILE already sources $TARGET_PROFILE"
fi

echo "✅ Done. Run: source $RC_FILE"
