#!/bin/bash
# ============================
# vscreen Integration Test Suite
# Version: 2.2.0
# ============================
# Scope:  Robustness and System Integration
# Target: bin/vscreen (Local artifact)
# Output: logs/integration/vscreen/
# ============================
# This script performs exhaustive testing of vscreen functionality
# Results are saved to a timestamped log file
# ============================

# TODO(test-safety): Add GDM/display-manager compatibility check
# Tests that create many virtual displays can break GDM login screen.
#
# Symptoms observed:
# - After running stress tests, GDM shows black screen on user login
# - Cannot switch to TTY (Ctrl+Alt+F1-F6 unresponsive)
# - Requires hard reboot to recover
# - After reboot, system works normally (displays cleaned up)
#
# Root cause: Too many virtual outputs confuse display manager
#
# Proposed solutions:
# 1. Add --max-displays safety limit (default: 10)
# 2. Before tests, check if running under GDM/SDDM/LightDM
# 3. If display manager detected, warn user and require --force flag
# 4. Add emergency recovery command: vscreen --emergency-reset
#    - Runs from TTY/SSH
#    - Kills all xrandr processes
#    - Disables all virtual outputs
#    - Restarts display manager
#
# Temporary workaround:
# - Limit stress test to 10 displays instead of 20
# - Always run force_cleanup() between test sections
#
# labels: bug, critical, display-manager, safety

set -o pipefail

# Locates the script directory to find the project root regardless of CWD
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# We do not rely on global PATH. We test the built binary explicitly.
VSCREEN="$PROJECT_ROOT/bin/vscreen"

# Log Configuration
# LOG_DIR="$PROJECT_ROOT/logs/integration/vscreen"
LOG_DIR="$PROJECT_ROOT/logs/tests/vscreen/integration"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +"%Y%m%d%H%M%S")
LOGFILE="$LOG_DIR/${TIMESTAMP}.log"
LATEST_LINK="$LOG_DIR/latest.log"

# Updates the symlink to point to the most recent run
ln -sf "$(basename "$LOGFILE")" "$LATEST_LINK"

# TODO(test-refactoring): Split integration tests into focused test files
# Current approach puts all tests in one large file (300+ lines).
# This makes it hard to run specific test suites or debug failures.
#
# Proposed structure:
# - tests/vscreen/integration/
#   ├── 01_basic_commands.sh     # help, version, list
#   ├── 02_argument_validation.sh # invalid inputs
#   ├── 03_resolutions.sh         # predefined and custom resolutions
#   ├── 04_orientations.sh        # all rotation modes
#   ├── 05_positioning.sh         # relative and absolute positioning
#   ├── 06_change_command.sh      # modifying existing displays
#   ├── 07_stress_test.sh         # multiple displays
#   ├── 08_edge_cases.sh          # unusual scenarios
#   ├── 09_complex_scenarios.sh   # multi-display configurations
#   └── runner.sh                 # orchestrates all tests
#
# Benefits:
# - Run specific test categories independently
# - Parallel test execution for faster CI
# - Easier to maintain and understand
# - Better failure isolation
# - Each file under 100 lines
#
# labels: testing, refactoring, maintainability, developer-experience

# ============================
# Test Logic Begins
# ============================
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# ============================
# Colors (only for terminal)
# ============================
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

# ============================
# Logging Functions
# ============================
log_to_file() {
  echo "$*" | sed 's/\x1b\[[0-9;]*m//g; s/\\033\[[0-9;]*m//g' >> "$LOGFILE"
}

log() {
  echo -e "$*"
  log_to_file "$*"
}

log_section() {
  local msg="$1"
  log ""
  log "${CYAN}========================================${NC}"
  log "${CYAN}$msg${NC}"
  log "${CYAN}========================================${NC}"
}

log_test() {
  ((TEST_COUNT++))
  log ""
  log "${BLUE}[TEST $TEST_COUNT]${NC} $*"
}

log_pass() {
  ((PASS_COUNT++))
  log "${GREEN}✓ PASS${NC}: $*"
}

log_fail() {
  ((FAIL_COUNT++))
  log "${RED}✗ FAIL${NC}: $*"
}

log_info() {
  log "${YELLOW}ℹ INFO${NC}: $*"
}

log_cmd() {
  log "  $ $*"
}

# ============================
# Test Utilities
# ============================
run_test() {
  local description="$1"
  shift
  local cmd="$*"
  
  log_test "$description"
  log_cmd "$cmd"
  
  local output
  local exit_code
  
  output=$($cmd 2>&1)
  exit_code=$?
  
  if [[ -n "$output" ]]; then
    echo "$output" | while IFS= read -r line; do
      log "    $line"
    done
  fi
  
  return $exit_code
}

expect_success() {
  local description="$1"
  shift
  
  if run_test "$description" "$@"; then
    log_pass "$description"
    return 0
  else
    log_fail "$description (exit code: $?)"
    return 1
  fi
}

expect_failure() {
  local description="$1"
  shift
  
  if run_test "$description" "$@"; then
    log_fail "$description (should have failed but succeeded)"
    return 1
  else
    log_pass "$description (correctly failed)"
    return 0
  fi
}

get_active_virtuals() {
  xrandr 2>/dev/null | grep -c "^VIRTUAL[0-9]* connected"
}

get_virtual_list() {
  xrandr 2>/dev/null | awk '/^VIRTUAL[0-9]+ connected/{print $1}'
}

wait_for_xrandr() {
  sleep 0.5
}

force_cleanup() {
  log_info "Force cleanup: purging all virtual displays"
  "$VSCREEN" --purge-all &>> "$LOGFILE" || true
  wait_for_xrandr
}

# ============================
# Test Setup
# ============================
log_section "TEST SUITE INITIALIZATION"
log "Starting vscreen integration test suite"
log "Date: $(date)"
log "Logfile: $LOGFILE"
log "vscreen location: $VSCREEN"

# Check if vscreen exists
if [[ ! -f "$VSCREEN" ]]; then
  log_fail "vscreen script not found at $VSCREEN"
  exit 1
fi

# Make it executable
chmod +x "$VSCREEN"

# Force cleanup any existing virtual displays
log_info "Force cleaning up any existing virtual displays"
force_cleanup

# Verify cleanup
REMAINING=$(get_active_virtuals)
if [[ $REMAINING -gt 0 ]]; then
  log_fail "Could not clean up existing displays: $REMAINING remain active"
  get_virtual_list | while read -r v; do
    log_info "  Active: $v"
  done
  exit 1
fi

log_info "Cleanup successful, starting tests"

# ============================
# TEST 1: Help and Version
# ============================
log_section "TEST SECTION 1: Basic Commands"

expect_success "Display help" "$VSCREEN" --help
expect_success "Display version" "$VSCREEN" --version
expect_success "List all virtual outputs" "$VSCREEN" --list all
expect_success "List active virtual outputs" "$VSCREEN" --list active
expect_success "List free virtual outputs" "$VSCREEN" --list free

# ============================
# TEST 2: Invalid Arguments
# ============================
log_section "TEST SECTION 2: Invalid Arguments"

expect_failure "Invalid resolution ID" "$VSCREEN" -r 99
expect_failure "Invalid resolution name" "$VSCREEN" -r NOTEXIST
expect_failure "Invalid size format" "$VSCREEN" --size 1920
expect_failure "Invalid orientation" "$VSCREEN" --output 1 -r 1 -o INVALID
expect_failure "Invalid position format" "$VSCREEN" --output 1 -r 1 --pos 1920
expect_failure "Missing resolution argument" "$VSCREEN" -r
expect_failure "Missing size argument" "$VSCREEN" --size
expect_failure "Both -r and --size" "$VSCREEN" --output 1 -r 1 --size 1920x1080
expect_failure "Output without resolution" "$VSCREEN" --output 1
expect_failure "Invalid output number" "$VSCREEN" --output ABC -r 1

# ============================
# TEST 3: Predefined Resolutions
# ============================
log_section "TEST SECTION 3: Predefined Resolutions"

log_info "Testing all predefined resolutions by ID"
for id in 1 2 3 4 5 6; do
  expect_success "Activate VIRTUAL$id with resolution ID $id" "$VSCREEN" --output "$id" -r "$id"
  wait_for_xrandr
done

log_info "Current active displays:"
get_virtual_list | tee -a "$LOGFILE"

log_info "Deactivating all displays"
expect_success "Deactivate all displays" "$VSCREEN" --off-all
wait_for_xrandr

# Verify all were deactivated
REMAINING=$(get_active_virtuals)
if [[ $REMAINING -eq 0 ]]; then
  log_info "Verification: All displays deactivated"
else
  log_info "Verification failed: $REMAINING displays remain active"
  force_cleanup
fi

log_info "Testing predefined resolutions by name"
declare -A res_names=(
  [1]="FHD"
  [2]="HD+"
  [3]="HD"
)

for id in 1 2 3; do
  name="${res_names[$id]}"
  expect_success "Activate VIRTUAL$id with resolution name $name" "$VSCREEN" --output "$id" -r "$name"
  wait_for_xrandr
done

expect_success "Deactivate all displays" "$VSCREEN" --off-all
wait_for_xrandr
force_cleanup

# ============================
# TEST 4: Custom Resolutions
# ============================
log_section "TEST SECTION 4: Custom Resolutions"

declare -a custom_resolutions=(
  "1920x1080"
  "2560x1440"
  "1024x768"
)

for i in "${!custom_resolutions[@]}"; do
  res="${custom_resolutions[$i]}"
  output=$((i + 1))
  expect_success "Activate VIRTUAL$output with custom size $res" "$VSCREEN" --output "$output" --size "$res"
  wait_for_xrandr
done

expect_success "Deactivate all displays" "$VSCREEN" --off-all
wait_for_xrandr
force_cleanup

# ============================
# TEST 5: Orientations
# ============================
log_section "TEST SECTION 5: Orientations"

declare -a orientations=(
  "normal:L"
  "right:PR"
  "left:PL"
  "inverted:LF"
)

for orient in "${orientations[@]}"; do
  IFS=':' read -r mode alias <<< "$orient"
  
  expect_success "Activate with orientation $mode" "$VSCREEN" --output 1 -r 1 -o "$mode"
  wait_for_xrandr
  expect_success "Deactivate" "$VSCREEN" --off 1
  wait_for_xrandr
done

force_cleanup

# ============================
# TEST 6: Change Command
# ============================
log_section "TEST SECTION 6: Change Command"

expect_success "Activate VIRTUAL1 with FHD" "$VSCREEN" --output 1 -r FHD
wait_for_xrandr

expect_success "Change VIRTUAL1 to HD" "$VSCREEN" --change 1 -r HD
wait_for_xrandr

expect_success "Change VIRTUAL1 orientation to right" "$VSCREEN" --change 1 -o right
wait_for_xrandr

expect_success "Change VIRTUAL1 orientation back to normal" "$VSCREEN" --change 1 -o normal
wait_for_xrandr

expect_failure "Change inactive VIRTUAL2" "$VSCREEN" --change 2 -r 2

expect_success "Deactivate VIRTUAL1" "$VSCREEN" --off 1
wait_for_xrandr
force_cleanup

# ============================
# TEST 7: Positioning
# ============================
log_section "TEST SECTION 7: Positioning"

# Get primary output
PRIMARY=$(xrandr 2>/dev/null | awk '/primary|connected/ && /^[A-Z]/ {print $1; exit}')
log_info "Primary output detected: ${PRIMARY:-none}"

if [[ -n "$PRIMARY" && "$PRIMARY" != "VIRTUAL1" ]]; then
  expect_success "Position right of $PRIMARY" "$VSCREEN" --output 1 -r 1 --right-of "$PRIMARY"
  wait_for_xrandr
  expect_success "Deactivate" "$VSCREEN" --off 1
  wait_for_xrandr
fi

expect_success "Absolute position 1920x0" "$VSCREEN" --output 1 -r 1 --pos 1920x0
wait_for_xrandr
expect_success "Deactivate" "$VSCREEN" --off 1
wait_for_xrandr

# Test auto-positioning with multiple displays
expect_success "Activate VIRTUAL1" "$VSCREEN" --output 1 -r 1
wait_for_xrandr
expect_success "Activate VIRTUAL2 (auto-position)" "$VSCREEN" --output 2 -r 2
wait_for_xrandr
expect_success "Activate VIRTUAL3 (auto-position)" "$VSCREEN" --output 3 -r 3
wait_for_xrandr

log_info "Current display layout:"
xrandr --listmonitors 2>/dev/null | tee -a "$LOGFILE"

expect_success "Deactivate all" "$VSCREEN" --off-all
wait_for_xrandr
force_cleanup

# ============================
# TEST 8: Stress Test - 10 Displays
# ============================
log_section "TEST SECTION 8: Stress Test - Multiple Displays"

log_info "Attempting to activate 10 virtual displays"

STRESS_SUCCESS=0
STRESS_FAIL=0

for i in {1..10}; do
  res_id=$((i % 6 + 1))
  if "$VSCREEN" --output "$i" -r "$res_id" &>> "$LOGFILE"; then
    ((STRESS_SUCCESS++))
    log "[info] VIRTUAL$i activated"
  else
    ((STRESS_FAIL++))
    log "[warn] VIRTUAL$i failed to activate"
  fi
  wait_for_xrandr
done

log_info "Stress test results: $STRESS_SUCCESS successful, $STRESS_FAIL failed"
ACTIVE_COUNT=$(get_active_virtuals)
log_info "Total active displays: $ACTIVE_COUNT"

if [[ $ACTIVE_COUNT -eq $STRESS_SUCCESS ]]; then
  log_pass "Active count matches expected"
else
  log_fail "Active count mismatch: expected $STRESS_SUCCESS, got $ACTIVE_COUNT"
fi

force_cleanup

# ============================
# TEST 9: Edge Cases
# ============================
log_section "TEST SECTION 9: Edge Cases"

expect_failure "Deactivate non-existent VIRTUAL99" "$VSCREEN" --off 99
expect_failure "Change non-existent VIRTUAL99" "$VSCREEN" --change 99 -r 1

# Activate one display for next test
"$VSCREEN" --output 1 -r 1 &>> "$LOGFILE"
wait_for_xrandr

expect_failure "Activate already active display" "$VSCREEN" --output 1 -r 2

force_cleanup

expect_success "No-auto positioning" "$VSCREEN" --output 1 -r 1 --no-auto
wait_for_xrandr

force_cleanup

# ============================
# TEST 10: Complex Scenarios
# ============================
log_section "TEST SECTION 10: Complex Scenarios"

log_info "Scenario: Multiple displays with different configs"

expect_success "VIRTUAL1: FHD landscape" "$VSCREEN" --output 1 -r FHD -o normal
wait_for_xrandr

expect_success "VIRTUAL2: HD portrait right" "$VSCREEN" --output 2 -r HD -o right
wait_for_xrandr

expect_success "VIRTUAL3: Custom 2560x1440" "$VSCREEN" --output 3 --size 2560x1440 -o normal
wait_for_xrandr

log_info "Current complex setup:"
xrandr --listmonitors 2>/dev/null | tee -a "$LOGFILE"

expect_success "Change VIRTUAL2 to landscape" "$VSCREEN" --change 2 -o normal
wait_for_xrandr

expect_success "Change VIRTUAL1 to HD+" "$VSCREEN" --change 1 -r HD+
wait_for_xrandr

log_info "After changes:"
xrandr --listmonitors 2>/dev/null | tee -a "$LOGFILE"

# ============================
# FINAL CLEANUP
# ============================
log_section "FINAL CLEANUP"

log_info "Final force cleanup"
force_cleanup

log_info "Purging all custom modes"
expect_success "Purge all" "$VSCREEN" --purge-all

log_info "Final state verification"
FINAL_ACTIVE=$(get_active_virtuals)
log_info "Active virtual displays after cleanup: $FINAL_ACTIVE"

if [[ $FINAL_ACTIVE -eq 0 ]]; then
  log_pass "All displays successfully deactivated"
else
  log_fail "Some displays remain active: $FINAL_ACTIVE"
  get_virtual_list | while read -r v; do
    log_info "  Still active: $v"
  done
fi

# ============================
# TEST SUMMARY
# ============================
log_section "TEST SUMMARY"

log ""
log "Total tests run: $TEST_COUNT"
log "${GREEN}Passed: $PASS_COUNT${NC}"
log "${RED}Failed: $FAIL_COUNT${NC}"

if [[ $FAIL_COUNT -eq 0 ]]; then
  log ""
  log "${GREEN}========================================${NC}"
  log "${GREEN}   ALL TESTS PASSED SUCCESSFULLY! ✓${NC}"
  log "${GREEN}========================================${NC}"
  log ""
  log "Full log available at: $LOGFILE"
  exit 0
else
  PASS_RATE=$((PASS_COUNT * 100 / TEST_COUNT))
  log ""
  log "${YELLOW}========================================${NC}"
  log "${YELLOW}   SOME TESTS FAILED${NC}"
  log "${YELLOW}   Pass rate: ${PASS_RATE}%${NC}"
  log "${YELLOW}========================================${NC}"
  log ""
  log "Full log available at: $LOGFILE"
  exit 1
fi