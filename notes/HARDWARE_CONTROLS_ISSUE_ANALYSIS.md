# Hardware Controls Issue Analysis - GNOME vs Niri

## Problem Summary

Certain hardware controls work in GNOME/GDM but not in Niri:
- ✅ **Volume control** (function keys) - Works in Niri
- ✅ **Backlit keyboard toggle** - **FIXED** - Now works in Niri (key bindings configured)
- ✅ **Brightness control** - **FIXED** - Now works in Niri (software widget and keyboard function keys)
  - ✅ GPU issue resolved (AMD iGPU is now active - see GPU_OFFLOAD_NOTES.txt)
  - ✅ brightnessctl in PATH, key bindings configured, Noctalia widget working
- ✅ **Nightlight functionality** - **FIXED** - Now works in Niri (wlsunset service configured)
- ✅ **ASUS DialPad driver** - **FIXED** - Now works in Niri (see ASUS_DIALPAD_FIX.md)
- ✅ **WiFi status widget** - **FIXED** - Now correctly reports WiFi status (PATH fix for nmcli)
- ✅ **Screen recording widget** - **FIXED** - Now properly connects to gpu-screen-recorder package (PATH fix)

## Root Cause Analysis

### 1. GNOME Settings Daemon

**GNOME provides a D-Bus service** (`org.gnome.SettingsDaemon`) that handles hardware controls:
- Keyboard backlight control
- Display brightness control
- Power management
- Media key handling

**Niri does NOT have this service**, so hardware controls that depend on it won't work.

### 2. ASUS DialPad Driver Issue - ✅ RESOLVED

**Status**: **FIXED** - The ASUS DialPad driver now works correctly in Niri.

**Problem (Resolved)**: The ASUS DialPad driver was failing to connect to Wayland display due to hardcoded `WAYLAND_DISPLAY=wayland-0` when the actual display was `wayland-1`.

**Solution Applied**:
1. Removed hardcoded `WAYLAND_DISPLAY` from service environment
2. Added `PassEnvironment` to inherit `WAYLAND_DISPLAY` from session
3. Added `ExecStartPre` check to wait for Wayland socket to be available

**Current Status**: Service now successfully connects and runs without constant restarts. See `ASUS_DIALPAD_FIX.md` for full details.

### 3. Backlit Keyboard Control - ✅ RESOLVED

**Hardware Access**: The keyboard backlight LED is accessible:
- Path: `/sys/class/leds/asus::kbd_backlight/`
- Current brightness: `1` (out of `3` max)
- Files: `brightness`, `max_brightness`, `trigger`

**How GNOME Controls It**:
- GNOME Settings Daemon provides D-Bus interface
- Function keys trigger D-Bus calls to Settings Daemon
- Settings Daemon writes to `/sys/class/leds/asus::kbd_backlight/brightness`

**Solution Applied**:
1. ✅ Configured Niri key bindings for keyboard backlight control
2. ✅ Added `brightnessctl` key bindings: `XF86KbdBrightnessUp`, `XF86KbdBrightnessDown`
3. ✅ Added toggle key binding: `Mod+Shift+B` to toggle between off (0) and max (3)
4. ✅ `brightnessctl` available system-wide and accessible via key bindings

**Current State**:
- ✅ Keyboard backlight control working via function keys
- ✅ Toggle key binding working (`Mod+Shift+B`)
- ✅ `brightnessctl` configured to control `asus::kbd_backlight` device
- ✅ Key bindings configured in `~/.config/niri/config.kdl`

**Key Bindings Configured**:
- `XF86KbdBrightnessUp`: Increase keyboard backlight
- `XF86KbdBrightnessDown`: Decrease keyboard backlight
- `Mod+Shift+B`: Toggle keyboard backlight (off ↔ max)

### 4. Brightness Control - ✅ RESOLVED

**Hardware Access**: Display backlight is accessible:
- Path: `/sys/class/backlight/amdgpu_bl1/`
- This is the AMD GPU backlight controller

**Status Update**: 
- ✅ GPU switching issue has been resolved (AMD iGPU is now active - see GPU_OFFLOAD_NOTES.txt)
- ✅ **Brightness controls now working** (both software widget and keyboard function keys)

**Solution Applied**:
1. ✅ Added `brightnessctl` to `environment.systemPackages` in `niri.nix` for system-wide availability
2. ✅ Configured Niri key bindings for brightness function keys (XF86MonBrightnessUp/Down) in `~/.config/niri/config.kdl`
3. ✅ Fixed Noctalia brightness widget by ensuring `sh` and `brightnessctl` are in PATH via systemd service environment
4. ✅ Added explicit PATH to `noctalia-shell` systemd service to include `/run/current-system/sw/bin` and necessary binaries

**Current State**:
- ✅ GPU issue resolved - AMD is now the active GPU (backlight hardware is accessible)
- ✅ Brightness control via software widget - working (Noctalia widget shows correct percentage)
- ✅ Brightness control via keyboard function keys - working (XF86MonBrightnessUp/Down key bindings)
- ✅ `brightnessctl` available system-wide and in Noctalia service PATH
- ✅ Key bindings configured in Niri config for brightness function keys

### 5. Volume Control (Why It Works)

**Volume works because**:
- PipeWire is running as a system service (not GNOME-specific)
- PipeWire provides D-Bus interface (`org.freedesktop.MediaKeys1`)
- Function keys can directly control PipeWire via D-Bus
- Niri or the application can handle these keys

### 6. WiFi Status Widget Mis-reporting - ✅ RESOLVED

**Problem**: The WiFi widget in Noctalia Shell shows as "off" even though WiFi is connected and working.

**Root Cause**: `nmcli` was not found in PATH when Noctalia's NetworkService tried to scan for networks, causing the scan to fail silently.

**Solution Applied**:
1. ✅ Added explicit PATH to `noctalia-shell` systemd service environment
2. ✅ Included `/run/current-system/sw/bin` and NetworkManager binaries in PATH
3. ✅ Added `PassEnvironment = [ "PATH" ];` to ensure PATH is inherited

**Current State**:
- ✅ WiFi adapter is enabled (`nmcli radio wifi` returns "enabled")
- ✅ WiFi is connected (active connection exists)
- ✅ `nmcli` scan command works correctly and shows connected network
- ✅ Widget now correctly shows WiFi status (connected/disconnected)
- ✅ `nmcli` is accessible in Noctalia service PATH

**Why It Was Failing**:
1. **PATH Issue**: `nmcli` was not in the PATH when Noctalia's NetworkService tried to execute it
2. **Service Environment**: The systemd user service didn't have the system PATH configured
3. **Scan Failure**: Without `nmcli`, the network scan failed, leaving `NetworkService.networks` empty
4. **Widget Display**: Empty networks caused widget to show "wifi-off" even when WiFi was connected

**Fix Details**:
- Added `PATH=/run/current-system/sw/bin:${pkgs.lib.makeBinPath [ ... pkgs.networkmanager ]}` to service environment
- This ensures `nmcli`, `sh`, `brightnessctl`, and other system binaries are accessible to Noctalia

### 7. Nightlight Functionality - ✅ RESOLVED

**Problem**: Nightlight (blue light filter) functionality does not work in Niri.

**Root Cause**: 
- Nightlight requires `wlsunset` to be running as a service
- GNOME provides nightlight via Settings Daemon, which Niri doesn't have
- `wlsunset` was available but not configured/started

**Solution Applied**:
1. ✅ Added `wlsunset` to `environment.systemPackages` in `niri.nix` for system-wide availability
2. ✅ Configured `wlsunset` as a systemd user service in `niri.nix`
3. ✅ Added key binding in Niri config (`Mod+Shift+N`) to toggle nightlight on/off
4. ✅ Service starts automatically with the user session

**Current State**:
- ✅ Nightlight functional in Niri via `wlsunset` service
- ✅ Service configured and starts automatically
- ✅ GPU issue resolved (AMD is now active GPU - see GPU_OFFLOAD_NOTES.txt)
- ✅ Key binding configured for easy toggle (`Mod+Shift+N`)
- ✅ `wlsunset` available system-wide

**Service Configuration**:
- Service name: `wlsunset.service` (systemd user service)
- Starts with: `graphical-session.target`
- Key binding: `Mod+Shift+N` toggles service on/off
- Can be controlled via: `systemctl --user start/stop wlsunset.service`

### 8. Screen Recording Widget Not Connecting to gpu-screen-recorder - ✅ RESOLVED

**Problem**: The screen recording bar widget in Noctalia does not properly connect to the `gpu-screen-recorder` package.

**Root Cause**: 
- `gpu-screen-recorder` was not in PATH when Noctalia's widget tried to execute it
- Widget could not find the `gpu-screen-recorder` command, causing widget and control center interactions to fail

**Solution Applied**:
1. ✅ Added explicit PATH to `noctalia-shell` systemd service environment
2. ✅ Included `/run/current-system/sw/bin` in PATH where `gpu-screen-recorder` is located
3. ✅ Added `PassEnvironment = [ "PATH" ];` to ensure PATH is inherited

**Current State**:
- ✅ `gpu-screen-recorder` is installed system-wide
- ✅ `gpu-screen-recorder` is available in PATH
- ✅ `gpu-screen-recorder` works when run directly from command line
- ✅ Widget now properly connects/controls the package
- ✅ Control center interactions working correctly

**Why It Was Failing**:
- The widget tried to execute `gpu-screen-recorder` but couldn't find it in the service's PATH
- Without access to the system PATH, the widget couldn't locate the binary
- The PATH fix applied to resolve brightness/WiFi issues also fixed screen recording

**Note**: This was a PATH configuration issue, not a package installation or widget integration issue. The package and widget were both correct, they just needed proper PATH access.

## Key Differences: GNOME vs Niri

### GNOME Session Provides:
1. **GNOME Settings Daemon** - Handles hardware controls via D-Bus
2. **Automatic key bindings** - Function keys are automatically mapped
3. **D-Bus services** - Various services for hardware control
4. **Session environment** - Proper environment variables set

### Niri Session Provides:
1. **Minimal services** - Only what's explicitly configured
2. **No automatic key bindings** - Need to configure manually
3. **No hardware control daemon** - Need to provide alternative
4. **Basic session** - Only essential environment variables

## Solutions

### Solution 1: Add brightnessctl System-Wide

Add `brightnessctl` to `environment.systemPackages` in `niri.nix` or `configuration.nix`:

```nix
environment.systemPackages = with pkgs; [
  # ... existing packages ...
  brightnessctl  # For brightness and keyboard backlight control
];
```

### Solution 2: Fix ASUS DialPad Driver - ✅ COMPLETED

**Status**: This has been implemented and is working. The service now:
- Dynamically detects the Wayland display from session environment
- Waits for the Wayland socket to be available before starting
- Successfully connects without constant restarts

See `ASUS_DIALPAD_FIX.md` for implementation details.

### Solution 3: Create Hardware Control Service

Create a systemd user service to handle function keys for hardware controls:

```nix
systemd.user.services.hardware-control = {
  description = "Hardware Control Service for Niri";
  wantedBy = [ "graphical-session.target" ];
  after = [ "graphical-session.target" ];
  serviceConfig = {
    Type = "simple";
    ExecStart = "${pkgs.writeScriptBin "hardware-control" ''
      #!${pkgs.bash}/bin/bash
      # Monitor function keys and control hardware
      # This would need a tool to listen for key events
    ''}/bin/hardware-control";
  };
};
```

**Better approach**: Use `swayidle` or similar tool, or configure Niri key bindings directly.

### Solution 4: Configure Niri Key Bindings

Add key bindings in Niri config to control hardware:

```nix
# In niri configuration (if Niri supports this)
# Function key + brightness up/down -> brightnessctl
# Function key + keyboard backlight -> direct sysfs write
```

### Solution 5: Use Noctalia Widgets

Noctalia has widgets for brightness control. Ensure:
1. `brightnessctl` is available (already in runtimeDeps)
2. Widgets have proper permissions
3. Widgets are properly configured

## Diagnostic Commands

```bash
# Check ASUS DialPad driver status (should show "active (running)")
systemctl --user status asus-dialpad-driver
journalctl --user -u asus-dialpad-driver -n 50

# Check Wayland display
echo $WAYLAND_DISPLAY
ls -la /tmp/*wayland* 2>/dev/null

# Test keyboard backlight control (requires root or proper permissions)
sudo cat /sys/class/leds/asus::kbd_backlight/brightness
sudo echo 0 > /sys/class/leds/asus::kbd_backlight/brightness  # Test off
sudo echo 3 > /sys/class/leds/asus::kbd_backlight/brightness  # Test max

# Check brightnessctl availability
which brightnessctl
brightnessctl --version

# Check backlight control
ls -la /sys/class/backlight/
cat /sys/class/backlight/amdgpu_bl1/brightness
cat /sys/class/backlight/amdgpu_bl1/max_brightness

# Check D-Bus services
dbus-send --session --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames | grep -i -E "(settings|power|brightness|keyboard)"

# Check WiFi status (for Noctalia widget issue)
nmcli radio wifi
nmcli -t -f SSID,SECURITY,SIGNAL,IN-USE device wifi list --rescan yes
nmcli -t -f NAME,TYPE,DEVICE connection show --active | grep wifi
```

## Summary

**Main Issues**:
1. ✅ **ASUS DialPad**: **FIXED** - Now dynamically detects Wayland display
2. ✅ **Backlit Keyboard**: **FIXED** - Key bindings configured in Niri config (XF86KbdBrightnessUp/Down, Mod+Shift+B)
3. ✅ **GPU Issue**: **RESOLVED** - AMD iGPU is now active (see GPU_OFFLOAD_NOTES.txt)
4. ✅ **Brightness Control**: **FIXED** - Both software widget and keyboard function keys working
5. ✅ **Nightlight**: **FIXED** - wlsunset service configured and working (toggle with Mod+Shift+N)
6. ✅ **WiFi Status Widget**: **FIXED** - Now correctly reports WiFi status (PATH fix for nmcli)
7. ✅ **Screen Recording Widget**: **FIXED** - Now properly connects to gpu-screen-recorder package (PATH fix)
8. ✅ **Volume**: Works because PipeWire is session-independent

**Why GNOME Works**:
- GNOME Settings Daemon provides D-Bus interfaces for all hardware controls
- Function keys are automatically mapped to D-Bus calls
- Services are started automatically with the session

**How Niri Now Works**:
- ✅ Explicit key bindings configured in Niri config for hardware controls
- ✅ Systemd user services configured for background functionality (wlsunset)
- ✅ System tools (brightnessctl, nmcli) available in PATH via service environment
- ✅ Noctalia widgets can access system binaries via proper PATH configuration

**Completed Tasks**:
1. ✅ ~~Fix ASUS DialPad Wayland display detection~~ - **COMPLETED**
2. ✅ ~~Resolve GPU switching issue (AMD now active)~~ - **COMPLETED** (see GPU_OFFLOAD_NOTES.txt)
3. ✅ ~~Fix brightness control (software and keyboard function keys)~~ - **COMPLETED**
   - ✅ Added `brightnessctl` to system packages
   - ✅ Configured Niri key bindings for brightness function keys
   - ✅ Fixed Noctalia brightness widgets (PATH configuration)
4. ✅ ~~Configure nightlight functionality (wlsunset)~~ - **COMPLETED**
   - ✅ Set up wlsunset as systemd user service
   - ✅ Added key binding for nightlight toggle
5. ✅ ~~Fix WiFi widget logic in Noctalia~~ - **COMPLETED** (PATH fix for nmcli)
6. ✅ ~~Fix backlit keyboard control (function keys)~~ - **COMPLETED** (key bindings configured)

**Remaining Tasks**:
1. ✅ ~~Fix screen recording widget connection to gpu-screen-recorder~~ - **COMPLETED** (PATH fix resolved the issue)

**All Major Hardware Control Issues Resolved!** 🎉

