# USB Authentication with pam_usb

Hardware token authentication for Linux. USB device as primary auth, password as fallback, automatic session lock on removal.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites and Dependencies](#2-prerequisites-and-dependencies)
3. [Build and Installation](#3-build-and-installation)
4. [Device Configuration](#4-device-configuration)
5. [PAM Integration](#5-pam-integration)
6. [Polkit Configuration](#6-polkit-configuration)
7. [Automatic Lock on Removal](#7-automatic-lock-on-removal)
8. [Temporary Lock Disable](#8-temporary-lock-disable)
9. [Best Practices](#9-best-practices)
10. [Troubleshooting and Recovery](#10-troubleshooting-and-recovery)
11. [Backup and Restore](#11-backup-and-restore)

---

## 1. Overview

### How it works

pam_usb authenticates users via USB storage devices using One-Time Pads (OTP):

1. USB device stores encrypted pad data
2. Local config (`/etc/security/pam_usb.conf`) stores matching pad
3. On auth attempt: pads are compared
4. On success: new pads are generated and written to both locations
5. On USB removal: udev triggers session lock

### Authentication flow

```
USB present → pam_usb validates pad → access granted → new pad generated
USB absent  → pam_usb fails        → fallback to password
```

### Components

| Component | Purpose |
|-----------|---------|
| `pam_usb.so` | PAM module for authentication |
| `pamusb-conf` | Device/user configuration tool |
| `pamusb-check` | Manual authentication test |
| udev rule | Triggers lock on USB removal |
| anti-bounce script | Prevents false locks from electrical bounce |

---

## 2. Prerequisites and Dependencies

### Debian/Ubuntu

```bash
sudo apt update
sudo apt install \
    git \
    build-essential \
    libpam0g-dev \
    libudev-dev \
    libusb-1.0-0-dev \
    libxml2-dev \
    pkg-config \
    libudisks2-dev
```

### Arch Linux

```bash
sudo pacman -S \
    git \
    base-devel \
    pam \
    systemd-libs \
    libusb \
    libxml2 \
    udisks2
```

### Pre-installation safety

Create a rescue user with sudo access before modifying PAM:

```bash
sudo useradd -m -G sudo rescue    # Debian
sudo useradd -m -G wheel rescue   # Arch
sudo passwd rescue
```

Test that rescue user can sudo before proceeding.

---

## 3. Build and Installation

### Clone and build

```bash
git clone https://github.com/mcdope/pam_usb.git
cd pam_usb
make
sudo make install
```

### Verify installation

```bash
# Check PAM module exists
ls -l /lib/*/security/pam_usb.so

# Check binaries
which pamusb-conf pamusb-check
```

Expected paths:
- PAM module: `/lib/x86_64-linux-gnu/security/pam_usb.so` (Debian) or `/lib/security/pam_usb.so` (Arch)
- Binaries: `/usr/bin/pamusb-conf`, `/usr/bin/pamusb-check`

---

## 4. Device Configuration

### Identify USB device

Connect only the USB device to be used, then:

```bash
# List block devices
lsblk

# Get device serial (needed for udev rule later)
udevadm info --query=all --name=/dev/sdX | grep ID_SERIAL_SHORT
```

Note the `ID_SERIAL_SHORT` value for later.

### Register device

```bash
sudo pamusb-conf --add-device <device_name>
```

Example:
```bash
sudo pamusb-conf --add-device authkey
```

The tool auto-detects the connected USB. Confirm when prompted.

### Associate user

```bash
sudo pamusb-conf --add-user <username>
```

Example:
```bash
sudo pamusb-conf --add-user vlgoncalves
```

### Verify configuration

```bash
# View config
cat /etc/security/pam_usb.conf

# Test authentication (USB connected)
pamusb-check <username>
```

Expected output:
```
* Authentication request for user "vlgoncalves" (pamusb-check)
* Device "authkey" is connected (...)
* Performing one time pad verification...
* Access granted.
```

First successful auth shows "Regenerating new pads..." — this is normal.

### Test without USB

Remove the USB device:

```bash
pamusb-check <username>
```

Expected output:
```
* Authentication request for user "vlgoncalves" (pamusb-check)
* Device "authkey" is not connected.
* Access denied.
```

---

## 5. PAM Integration

### Backup first

```bash
sudo cp -a /etc/pam.d /etc/pam.d.backup
```

### Understanding PAM placement

Add this line at the **top** of each PAM file:
```
auth sufficient pam_usb.so
```

- `sufficient`: if USB auth succeeds, skip password; if fails, continue to password
- Must be **before** other auth lines

### sudo

Edit `/etc/pam.d/sudo`:

```bash
sudo vim /etc/pam.d/sudo
```

Add at top:
```
auth sufficient pam_usb.so
```

### Display Managers

#### GDM (GNOME)

File: `/etc/pam.d/gdm-password`

```bash
sudo vim /etc/pam.d/gdm-password
```

Add at top:
```
auth sufficient pam_usb.so
```

#### SDDM (KDE)

File: `/etc/pam.d/sddm`

```bash
sudo vim /etc/pam.d/sddm
```

Add at top:
```
auth sufficient pam_usb.so
```

#### LightDM

File: `/etc/pam.d/lightdm`

```bash
sudo vim /etc/pam.d/lightdm
```

Add at top:
```
auth sufficient pam_usb.so
```

#### Ly (TTY-based)

File: `/etc/pam.d/ly`

```bash
sudo vim /etc/pam.d/ly
```

Add at top:
```
auth sufficient pam_usb.so
```

#### TTY login (no display manager)

File: `/etc/pam.d/login`

```bash
sudo vim /etc/pam.d/login
```

Add at top:
```
auth sufficient pam_usb.so
```

### Screen lockers

For unlock after lock, configure the screen locker's PAM file:

| Locker | PAM file |
|--------|----------|
| gnome-screensaver | `/etc/pam.d/gnome-screensaver` |
| swaylock | `/etc/pam.d/swaylock` |
| i3lock | Uses `login` or create `/etc/pam.d/i3lock` |
| xscreensaver | `/etc/pam.d/xscreensaver` |

Example for swaylock:
```bash
sudo vim /etc/pam.d/swaylock
```

Add at top:
```
auth sufficient pam_usb.so
```

### Verification

Test each integration:

```bash
# Test sudo (new terminal)
sudo ls

# Test DM: logout and login again

# Test screen locker: lock and unlock
```

With USB connected: no password prompt.
Without USB: password prompt appears.

---

## 6. Polkit Configuration

Polkit handles authentication for graphical applications requesting elevated privileges (GParted, GNOME Disks, Software Center, etc.).

### Identify Polkit PAM file

```bash
ls /etc/pam.d/polkit*
```

Common names:
- `polkit-1` (most distros)
- `polkit-gnome-authentication-agent-1`

### Configure

```bash
sudo vim /etc/pam.d/polkit-1
```

Add at top:
```
auth sufficient pam_usb.so
```

### Verification

Launch a graphical app that requests elevation:

```bash
# Example: GParted from application menu
# Or: gnome-disks
```

With USB connected: no password dialog.
Without USB: password dialog appears.

---

## 7. Automatic Lock on Removal

This section implements a robust lock/unlock system that:
- Filters electrical bounce and duplicate events
- Only affects the active graphical session
- Works correctly with multiple USB devices connected
- Handles both X11 and Wayland

### Why simple udev rules fail

udev has no concept of:
- Active graphical session
- Which user is logged in
- Which USB is "relevant"

When any USB storage device is added/removed, events can overlap and race conditions occur. This causes issues like:
- Lock not triggering
- Unlock requiring removal of unrelated USB devices
- Intermittent password prompts

The solution requires two filters: **debounce** and **session validation**.

### Get device UUID

Use filesystem UUID instead of serial for more reliable identification:

```bash
lsblk -o NAME,FSTYPE,LABEL,UUID
```

Example output:
```
sdb                                                                                        
└─sdb1        vfat     FAT32 BUGGY     1DA7-7194
```

Note the UUID (e.g., `1DA7-7194`).

### Create debounce script

This script filters rapid duplicate events:

```bash
sudo vim /usr/local/bin/usb-pam-guard.sh
```

Content:

```bash
#!/bin/bash
set -euo pipefail

STATE_DIR="/run/usb-pam-lock"
STATE_FILE="$STATE_DIR/last_event"
DEBOUNCE_SECONDS=3

mkdir -p "$STATE_DIR"

now=$(date +%s)

if [[ -f "$STATE_FILE" ]]; then
    last=$(cat "$STATE_FILE")
    delta=$(( now - last ))
    if (( delta < DEBOUNCE_SECONDS )); then
        exit 0
    fi
fi

echo "$now" > "$STATE_FILE"

/usr/local/bin/usb-pam-dispatch.sh "$@"
```

### Create session dispatch script

This script validates the session and executes lock/unlock:

```bash
sudo vim /usr/local/bin/usb-pam-dispatch.sh
```

Content:

```bash
#!/bin/bash
set -euo pipefail

ACTION="$1"
TARGET_USER="vlgoncalves"  # Change to your username

# Find active session for target user
SESSION_ID=$(loginctl list-sessions --no-legend | awk -v u="$TARGET_USER" '$3 == u {print $1}' | head -n1)

# No session found, nothing to do
[[ -z "$SESSION_ID" ]] && exit 0

# Verify it's a graphical session
SESSION_TYPE=$(loginctl show-session "$SESSION_ID" -p Type --value)
[[ "$SESSION_TYPE" != "x11" && "$SESSION_TYPE" != "wayland" ]] && exit 0

# Get user ID for DBUS
USER_ID=$(id -u "$TARGET_USER")

# Set environment for session communication
export DISPLAY=$(loginctl show-session "$SESSION_ID" -p Display --value)
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"

case "$ACTION" in
    add)
        loginctl unlock-session "$SESSION_ID"
        ;;
    remove)
        loginctl lock-session "$SESSION_ID"
        ;;
esac
```

### Set permissions

```bash
sudo chmod +x /usr/local/bin/usb-pam-guard.sh
sudo chmod +x /usr/local/bin/usb-pam-dispatch.sh
```

### Create udev rule

```bash
sudo vim /etc/udev/rules.d/90-usb-lock.rules
```

Content (replace UUID with yours):

```udev
ACTION=="add|remove", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="1DA7-7194", RUN+="/usr/local/bin/usb-pam-guard.sh %E{ACTION}"
```

Key points:
- `ID_FS_UUID` identifies only your specific device
- Handles both `add` and `remove` actions
- All complex logic is outside udev

Reload rules:

```bash
sudo udevadm control --reload
```

### Verification

1. **Single USB test**:
   - Remove auth USB → session locks after ~3 seconds
   - Reconnect auth USB → session unlocks automatically

2. **Multiple USB test**:
   - Connect another USB device (e.g., Ventoy)
   - Remove auth USB → session locks (other USB ignored)
   - Reconnect auth USB → session unlocks (other USB ignored)

3. **Bounce test**:
   - Remove and reconnect auth USB within 3 seconds → no lock

---

## 8. Temporary Lock Disable

Sometimes you need to remove the USB device without triggering a lock (e.g., to use it on another machine temporarily).

### Bash function

Add to `~/.bashrc` or `~/.bash_functions`:

```bash
usb_auth_remove() {
    local rule="/etc/udev/rules.d/90-usb-lock.rules"
    local disabled="/etc/udev/rules.d/90-usb-lock.rules.disabled"
    local restore="/etc/udev/rules.d/89-usb-lock-restore.rules"
    local uuid="1DA7-7194"  # Your device UUID

    if [[ ! -f "$rule" ]]; then
        echo "Lock rule already disabled or missing"
        return 1
    fi

    # Disable lock rule
    sudo mv "$rule" "$disabled"

    # Create temporary rule: when device reconnects, restore lock
    echo "ACTION==\"add\", SUBSYSTEM==\"block\", ENV{ID_FS_UUID}==\"$uuid\", RUN+=\"/bin/bash -c 'mv $disabled $rule && rm $restore && udevadm control --reload'\"" | sudo tee "$restore" > /dev/null

    sudo udevadm control --reload

    echo "Lock disabled. Reconnect device to re-enable."
}
```

### Usage

```bash
usb_auth_remove    # Disables lock
# Remove USB - no lock triggered
# Do what you need
# Reconnect USB - lock rule automatically restored
```

---

## 9. Best Practices

### Preventing pad corruption

Pad corruption occurs when pad regeneration is interrupted. Prevention:

| Scenario | Risk | Mitigation |
|----------|------|------------|
| Removal during login | High | Wait for desktop to fully load before removing |
| Removal during sudo | Medium | Wait for command to complete |
| Concurrent authentications | Medium | Don't run multiple sudo in parallel |
| Removal for lock | Low | Debounce script handles this |

**Safe removal timing:**
- After login: wait 2-3 seconds for desktop to load
- After sudo: wait for command output to appear
- For locking: just remove — debounce handles it

### Concurrent authentication issue

The pam_usb uses One-Time Pads. Each authentication:
1. Reads current pad from USB
2. Verifies against local config
3. Generates new pad
4. Writes new pad to USB AND config

If two processes authenticate simultaneously (e.g., two `sudo` in different terminals), both read the same pad and try to write different new pads → desync.

**Prevention:**
- Don't run multiple `sudo` commands in parallel
- Wait for one authentication to complete before starting another
- In normal desktop use, this rarely happens accidentally

### Operational guidelines

1. **Single auth at a time**: Don't open two terminals and sudo simultaneously
2. **Wait after auth**: Brief pause after login/sudo before removing USB
3. **Don't force unmount**: Let the system handle USB removal naturally
4. **Keep backups**: Regular backup of config and pad state (see section 11)

### Security notes

- USB auth is "something you have" — combine with password for 2FA if needed
- Physical access to USB = access to account
- Consider encrypted USB for additional security
- Lost USB: immediately `--reset-pads` and re-register new device

---

## 10. Troubleshooting and Recovery

### Common issues

#### "Device not connected"

```
* Device "authkey" is not connected.
* Access denied.
```

Causes:
- USB not inserted
- USB in different port (some configs are port-specific)
- Device not recognized by system

Fix:
```bash
lsblk  # Verify USB is detected
dmesg | tail -20  # Check for USB errors
```

#### "Can't read device pad" / "Pad checking failed"

```
* Can't read device pad!
* Pad checking failed!
* Access denied.
```

Cause: Pad desynchronization between USB and config.

Fix:
```bash
# With USB connected:
sudo pamusb-conf --reset-pads=<username>
pamusb-check <username>
```

#### "Access denied" despite USB present

```bash
# Debug check
pamusb-check --debug <username>
```

Look for specific error in output.

#### Unlock fails with multiple USB devices connected

**Symptom:** USB device is connected but unlock only works after removing other USB devices.

**Cause:** udev events from other USB devices interfere with the lock/unlock logic. Race conditions cause the session to remain locked.

**Solution:** Use the robust lock/unlock system from section 7 that:
- Filters events by filesystem UUID (not serial)
- Implements debounce to prevent duplicate events
- Validates the active graphical session

If already using the simple udev rule, migrate to the full solution:

```bash
# Remove old scripts
sudo rm -f /usr/local/bin/usb-pam-lock.sh

# Create new scripts from section 7
sudo vim /usr/local/bin/usb-pam-guard.sh
sudo vim /usr/local/bin/usb-pam-dispatch.sh
sudo chmod +x /usr/local/bin/usb-pam-guard.sh
sudo chmod +x /usr/local/bin/usb-pam-dispatch.sh

# Update udev rule to use UUID and handle add+remove
sudo vim /etc/udev/rules.d/90-usb-lock.rules
sudo udevadm control --reload
```

#### Locked out of system

Option A — TTY access:
```bash
# Ctrl+Alt+F2 for TTY
# Login with password (or rescue user)
sudo sed -i '/pam_usb.so/d' /etc/pam.d/gdm-password
sudo sed -i '/pam_usb.so/d' /etc/pam.d/sudo
sudo systemctl restart gdm
```

Option B — Recovery mode:
1. Boot to recovery/single user mode
2. Mount filesystem read-write
3. Remove pam_usb lines from PAM files
4. Reboot normally

Option C — Live USB:
1. Boot from live USB
2. Mount root partition
3. Edit PAM files to remove pam_usb lines
4. Reboot

### Debug commands

```bash
# Test authentication with debug output
pamusb-check --debug <username>

# Monitor PAM activity in real-time
journalctl -f | grep -i pam

# Check if pamusb-agent is running (should NOT be for this setup)
ps aux | grep pamusb-agent

# List udev rules
ls -la /etc/udev/rules.d/

# Test udev rule matching
udevadm test $(udevadm info -q path -n /dev/sdX)
```

### Reset commands reference

```bash
# Reset pads (fix desync)
sudo pamusb-conf --reset-pads=<username>

# Remove PAM integration (emergency)
sudo sed -i '/pam_usb.so/d' /etc/pam.d/sudo
sudo sed -i '/pam_usb.so/d' /etc/pam.d/gdm-password
sudo sed -i '/pam_usb.so/d' /etc/pam.d/polkit-1

# Verify PAM files are clean
grep -r pam_usb /etc/pam.d/
```

---

## 11. Backup and Restore

### What to backup

| Item | Path | Contains |
|------|------|----------|
| Main config | `/etc/security/pam_usb.conf` | Device definitions, user mappings, pad data |
| PAM configs | `/etc/pam.d/` | Modified PAM files |
| udev rule | `/etc/udev/rules.d/90-usb-lock.rules` | Lock trigger |
| Debounce script | `/usr/local/bin/usb-pam-guard.sh` | Event filtering |
| Dispatch script | `/usr/local/bin/usb-pam-dispatch.sh` | Session lock/unlock |

### Backup procedure

```bash
# Create backup directory
mkdir -p ~/pam_usb_backup

# Backup all components
sudo cp /etc/security/pam_usb.conf ~/pam_usb_backup/
sudo cp -a /etc/pam.d ~/pam_usb_backup/
sudo cp /etc/udev/rules.d/90-usb-lock.rules ~/pam_usb_backup/
sudo cp /usr/local/bin/usb-pam-guard.sh ~/pam_usb_backup/
sudo cp /usr/local/bin/usb-pam-dispatch.sh ~/pam_usb_backup/

# Set ownership
sudo chown -R $(whoami):$(whoami) ~/pam_usb_backup
```

### Restore procedure

```bash
# Restore config
sudo cp ~/pam_usb_backup/pam_usb.conf /etc/security/

# Restore PAM (careful - verify files first)
sudo cp ~/pam_usb_backup/pam.d/* /etc/pam.d/

# Restore udev and scripts
sudo cp ~/pam_usb_backup/90-usb-lock.rules /etc/udev/rules.d/
sudo cp ~/pam_usb_backup/usb-pam-guard.sh /usr/local/bin/
sudo cp ~/pam_usb_backup/usb-pam-dispatch.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/usb-pam-guard.sh
sudo chmod +x /usr/local/bin/usb-pam-dispatch.sh

# Reload udev
sudo udevadm control --reload

# Reset pads (required after restore)
sudo pamusb-conf --reset-pads=<username>
```

### New device registration (lost/replaced USB)

```bash
# Remove old device from config (manual edit required)
sudo vim /etc/security/pam_usb.conf
# Delete <device> block for old device

# Register new device
sudo pamusb-conf --add-device <device_name>
sudo pamusb-conf --add-user <username>

# Get new device UUID for udev rule
lsblk -o NAME,FSTYPE,LABEL,UUID

# Update udev rule with new UUID
sudo vim /etc/udev/rules.d/90-usb-lock.rules
# Update ID_FS_UUID value

sudo udevadm control --reload
```

---

## Quick Reference

### Essential commands

```bash
# Test authentication
pamusb-check <username>

# Debug test
pamusb-check --debug <username>

# Add device
sudo pamusb-conf --add-device <name>

# Add user
sudo pamusb-conf --add-user <username>

# Fix pad desync
sudo pamusb-conf --reset-pads=<username>

# Get USB UUID (preferred for udev)
lsblk -o NAME,FSTYPE,LABEL,UUID

# Get USB serial (alternative)
udevadm info --query=all --name=/dev/sdX | grep ID_SERIAL_SHORT

# Reload udev rules
sudo udevadm control --reload

# Temporarily disable lock (bash function from section 8)
usb_auth_remove
```

### File locations

```
/etc/security/pam_usb.conf          # Main configuration
/etc/pam.d/                          # PAM service files
/etc/udev/rules.d/90-usb-lock.rules  # Lock trigger rule
/usr/local/bin/usb-pam-guard.sh      # Debounce script
/usr/local/bin/usb-pam-dispatch.sh   # Session dispatch script
/lib/*/security/pam_usb.so           # PAM module
/run/usb-pam-lock/                   # Runtime state (debounce)
```

### PAM files by service

| Service | File |
|---------|------|
| sudo | `/etc/pam.d/sudo` |
| GDM | `/etc/pam.d/gdm-password` |
| SDDM | `/etc/pam.d/sddm` |
| LightDM | `/etc/pam.d/lightdm` |
| Ly | `/etc/pam.d/ly` |
| TTY login | `/etc/pam.d/login` |
| Polkit | `/etc/pam.d/polkit-1` |
| swaylock | `/etc/pam.d/swaylock` |
