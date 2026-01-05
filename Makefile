# ==============================================================================
# Local Scripts Collection - Makefile
# ==============================================================================

# Configuration
# ------------------------------------------------------------------------------
# The SHELL variable ensures make commands run in Bash, even if the user is 
# invoking make from Fish or Zsh. This prevents syntax errors in recipes.
SHELL := /bin/bash
.DEFAULT_GOAL := help

SIGILS_ROOT := $(shell pwd)
IS_ROOT := $(shell [ $$(id -u) -eq 0 ] && echo 1 || echo 0)

# Directories
BIN_DIR := $(SIGILS_ROOT)/bin
LIB_DIR := $(SIGILS_ROOT)/lib
TEST_DIR := $(SIGILS_ROOT)/tests
LOG_DIR := $(SIGILS_ROOT)/logs
DOCS_DIR := $(SIGILS_ROOT)/docs
DATA_DIR := $(SIGILS_ROOT)/data

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
# 	@echo "Installation:"
# 	@echo "  install    Symlink bin/* to ~/.local/bin"
# 	@echo "  uninstall  Remove symlinks"
# 	@echo ""

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
#
# I realy don't know what happens here. I guess that instalation was put this in .bashrc:
#	if [ -f "$HOME/.local/sigils/init/env.bash" ]; then
#		source "$HOME/.local/sigils/init/env.bash"
#	fi
#
# Not this stranger things
# .PHONY: install
# install:
# 	@echo "--> Installing binaries to ~/.local/bin..."
# 	@mkdir -p ~/.local/bin
# 	@# Using $(PWD) ensures the symlink points to the absolute path
# 	ln -sf $(PWD)/$(BIN_DIR)/* ~/.local/bin/
# 	@echo "Done. Ensure ~/.local/bin is in your PATH."
#
# .PHONY: uninstall
# uninstall:
# 	@echo "--> Removing symlinks from ~/.local/bin..."
# 	@# TODO: Be more specific to avoid deleting unrelated files
# 	@echo "TODO: safe uninstall logic not implemented yet."
# labels: deployment, user-experience


# ------------------------------------------------------------------------------
# Install Sigils
# ------------------------------------------------------------------------------

.PHONY: executable
executable:
	@echo "Making all script in $(BIN_DIR) executable"
	@chmod +x $(BIN_DIR)/*

# =============================================================================
# vscreen
# =============================================================================

# TODO(vscreen): Add dependency checking for xrandr, intel drivers

.PHONY: vscreen
vscreen:
	@echo "Making vscreen and vscreen-reset executable..."
	@chmod +x $(BIN_DIR)/vscreen
	@chmod +x $(BIN_DIR)/vscreen-reset
	@echo "vscreen ready. Make sure $(BIN_DIR) is in PATH."

# =============================================================================
# netmon
# =============================================================================

# Systemd paths based on user/root context
ifeq ($(IS_ROOT),1)
    SYSTEMD_DIR := /etc/systemd/system
    SYSTEMCTL := systemctl
else
    SYSTEMD_DIR := $(HOME)/.config/systemd/user
    SYSTEMCTL := systemctl --user
endif

.PHONY: netmon
netmon: netmon-install-deps netmon-link netmon-enable
	@echo ""
	@echo "netmon installed and running."

.PHONY: netmon-install-deps
netmon-install-deps:
	@echo "Checking dependencies..."
	@command -v speedtest >/dev/null 2>&1 || { \
		echo "Installing Ookla speedtest..."; \
		curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash && \
		sudo apt install -y speedtest; \
	}
	@command -v python3 >/dev/null 2>&1 || { \
		echo "Installing Python 3..."; \
		sudo apt update && sudo apt install -y python3; \
	}
	@echo "Dependencies OK."

.PHONY: netmon-link
netmon-link:
	@echo "Setting up netmon..."
	@chmod +x $(BIN_DIR)/netmon
	@mkdir -p $(SYSTEMD_DIR)
	ln -sf $(SIGILS_ROOT)/rituals/netmon.service $(SYSTEMD_DIR)/netmon.service
	ln -sf $(SIGILS_ROOT)/rituals/netmon.timer $(SYSTEMD_DIR)/netmon.timer
	$(SYSTEMCTL) daemon-reload
	@echo "Systemd units linked."

.PHONY: netmon-enable
netmon-enable:
	$(SYSTEMCTL) enable --now netmon.timer
	@echo "netmon timer enabled."
	@$(SYSTEMCTL) list-timers netmon.timer

.PHONY: netmon-disable
netmon-disable:
	-$(SYSTEMCTL) disable --now netmon.timer 2>/dev/null || true
	@echo "netmon timer disabled."

.PHONY: netmon-unlink
netmon-unlink: netmon-disable
	@echo "Removing systemd unit symlinks..."
	rm -f $(SYSTEMD_DIR)/netmon.service
	rm -f $(SYSTEMD_DIR)/netmon.timer
	$(SYSTEMCTL) daemon-reload
	@echo "Systemd units removed."

.PHONY: netmon-reload
netmon-reload:
	$(SYSTEMCTL) daemon-reload
	@echo "Systemd daemon reloaded."

# TODO(install-all): make install all sigils that have targets here
