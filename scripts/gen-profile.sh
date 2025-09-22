#!/usr/bin/env bash

################################################################################
# gen-profile.sh                                                               #
# Merges modular dotfiles into ~/.profile from ~/.setup/dotfiles              #
################################################################################

DOTFILES_DIR="$HOME/.setup/dotfiles"
TARGET_PROFILE="$HOME/.profile"

INPUT_FILES=(
  ".aliasesrc"
  ".dirrc"
  ".shell-aliases"
  ".tweak"
  ".zipping"
)

echo "🔧 Generating $TARGET_PROFILE from $DOTFILES_DIR"
> "$TARGET_PROFILE"

for file in "${INPUT_FILES[@]}"; do
  full_path="$DOTFILES_DIR/$file"
  if [[ -f "$full_path" ]]; then
    echo "  ✅ Including $full_path"
    cat "$full_path" >> "$TARGET_PROFILE"
    echo -e "\n" >> "$TARGET_PROFILE"
  else
    echo "  ⚠️  Skipping missing file: $full_path"
  fi
done

echo "✅ Profile written to $TARGET_PROFILE"