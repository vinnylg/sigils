#!/bin/bash

# ============================================================
# Explicit bootstrap script for this repo
#
# Purpose:
#   - Expose user scripts via PATH
#   - Load bash completion files
#   - Do NOT execute any user tools
#   - Do NOT source libraries automatically
#
# This file is meant to be sourced from:
#   ~/.bashrc, ~/.zshrc (via bash emulation), etc.
#
# Example:
#   source ~/.local/scripts/init/env.bash
# ============================================================

# ------------------------------------------------------------
# Resolve repository root directory
#
# This works even if:
#   - the script is symlinked
#   - the repository is moved
# ------------------------------------------------------------

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
BASE_DIR="$(realpath "$SCRIPT_DIR/..")"

# ------------------------------------------------------------
# Expose executables (bin/) via PATH
#
# - Only prepends if not already present
# - Keeps PATH idempotent
# ------------------------------------------------------------

if [[ -d "$BASE_DIR/bin" ]]; then
  case ":$PATH:" in
    *":$BASE_DIR/bin:"*) ;;  # already in PATH
    *) export PATH="$BASE_DIR/bin:$PATH" ;;
  esac
fi

# ------------------------------------------------------------
# Load bash completion scripts
#
# - Only *.bash files are sourced
# - Missing directory is silently ignored
# ------------------------------------------------------------

if [[ -d "$BASE_DIR/completions" ]]; then
  for completion in "$BASE_DIR/completions/bash/"*.bash; do
    [[ -f "$completion" ]] && source "$completion"
  done
fi

# ------------------------------------------------------------
# Library directory (lib/)
#
# Intentionally NOT sourced automatically.
# Libraries must be explicitly sourced by tools or tests.
#
# This avoids:
#   - polluting the interactive shell
#   - implicit side effects
# ------------------------------------------------------------

# export VSCRIPTS_LIB="$BASE_DIR/lib"
