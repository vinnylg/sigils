# ==============================================================================
# Local Scripts Collection - Makefile
# ==============================================================================

# Configuration
# ------------------------------------------------------------------------------
# The SHELL variable ensures make commands run in Bash, even if the user is 
# invoking make from Fish or Zsh. This prevents syntax errors in recipes.
SHELL := /bin/bash

# Directories
BIN_DIR := bin
LIB_DIR := lib
TEST_DIR := tests
LOG_DIR := logs
DOCS_DIR := docs

# Tools (can be overridden via command line)
SHELLCHECK ?= shellcheck
SHFMT ?= shfmt

# ==============================================================================
# Targets
# ==============================================================================

.PHONY: help
help:
	@echo "Local Scripts Collection"
	@echo "========================"
	@echo "Usage: make [target]"
	@echo ""
	@echo "Development:"
	@echo "  check      Run static analysis (Linting + Validation)"
	@echo "  test       Run test suite (Integration)"
	@echo "  fmt        Format shell scripts (shfmt)"
	@echo "  clean      Remove logs and temporary files"
	@echo ""
	@echo "Installation:"
	@echo "  install    Symlink bin/* to ~/.local/bin"
	@echo "  uninstall  Remove symlinks"
	@echo ""

# ------------------------------------------------------------------------------
# Quality Assurance
# ------------------------------------------------------------------------------

# TODO(linting): Enforce stricter shellcheck rules
# Currently runs on default settings. Should eventually enforce specific
# exclusions in a .shellcheckrc file.
# labels: code-quality, ci
.PHONY: check
check:
	@echo "--> Running shellcheck..."
	$(SHELLCHECK) $(BIN_DIR)/* $(LIB_DIR)/**/*.sh
	@echo "--> Verifying repository structure (executable bits)..."
	@test -x $(BIN_DIR)/vscreen || echo "WARNING: vscreen is not executable"

# TODO(formatting): Implement consistent style enforcement
# Need to adopt 'shfmt' to automatically format scripts.
# Proposed style: 2 spaces, binary operators at start of line.
# labels: style, maintenance
.PHONY: fmt
fmt:
	@echo "TODO: Implement shfmt command here."
	@# $(SHFMT) -w $(BIN_DIR)/* $(LIB_DIR)/**/*.sh

# ------------------------------------------------------------------------------
# Testing
# ------------------------------------------------------------------------------

# TODO(testing): Implement automatic test discovery
# Currently hardcoded to vscreen integration tests.
# Future requirement: Scan $(TEST_DIR) for all *.sh or *.bats files and
# execute them in a harness.
# labels: automation, scaling
.PHONY: test
test:
	@echo "--> Running vscreen integration tests..."
	@bash $(TEST_DIR)/vscreen/integration.sh

# ------------------------------------------------------------------------------
# Maintenance
# ------------------------------------------------------------------------------

# TODO(documentation): Generate manual pages
# Scripts should eventually generate man-pages or markdown docs automatically
# based on the help text or inline comments (shdoc).
# labels: docs, user-experience
.PHONY: docs
docs:
	@echo "TODO: Generate documentation from source."

# TODO(cleanup): Handle comprehensive cleanup
# Currently only handles logs. Should also handle:
# - Temporary test fixtures in /tmp
# - Any compiled artifacts if we add Go/Rust later
# labels: maintenance
.PHONY: clean
clean:
	@echo "--> Cleaning logs..."
	@rm -f $(LOG_DIR)/*.log
	@rm -f $(LOG_DIR)/**/*.log
	@echo "Clean complete."

# ------------------------------------------------------------------------------
# Installation
# ------------------------------------------------------------------------------

# TODO(installation): Support shell completions
# Currently only links binaries. Needs to also symlink:
# - completions/bash/* -> ~/.local/share/bash-completion/completions/
# - completions/zsh/* -> ~/.zsh/completion/
# labels: deployment, user-experience
.PHONY: install
install:
	@echo "--> Installing binaries to ~/.local/bin..."
	@mkdir -p ~/.local/bin
	@# Using $(PWD) ensures the symlink points to the absolute path
	ln -sf $(PWD)/$(BIN_DIR)/* ~/.local/bin/
	@echo "Done. Ensure ~/.local/bin is in your PATH."

.PHONY: uninstall
uninstall:
	@echo "--> Removing symlinks from ~/.local/bin..."
	@# TODO: Be more specific to avoid deleting unrelated files
	@echo "TODO: safe uninstall logic not implemented yet."