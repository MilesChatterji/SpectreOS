# Hardware Controls Issue Analysis - GNOME vs Niri

## Problem Summary

Certain hardware controls work in GNOME/GDM but not in Niri:
- ✅ **Volume control** (function keys) - Works in Niri
- ❌ **Backlit keyboard toggle** - Works in GNOME/GDM, not in Niri
- ❌ **Brightness control** - Works in GNOME/GDM, not in Niri (software and keyboard function keys)
  - ✅ GPU issue resolved (AMD iGPU is now active - see GPU_OFFLOAD_NOTES.txt)
  - ❌ Still needs: brightnessctl in PATH, key bindings, and/or D-Bus service
- ❌ **Nightlight functionality** - Does not work (needs implementation - wlsunset configuration)
- ✅ **ASUS DialPad driver** - **FIXED** - Now works in Niri (see ASUS_DIALPAD_FIX.md)
- ❌ **WiFi status widget** - Mis-reports as "off" despite active connection (scanning interval issue)
- ❌ **Screen recording widget** - Does not properly connect to gpu-screen-recorder package

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

### 3. Backlit Keyboard Control

**Hardware Access**: The keyboard backlight LED is accessible:
- Path: `/sys/class/leds/asus::kbd_backlight/`
- Current brightness: `1` (out of `3` max)
- Files: `brightness`, `max_brightness`, `trigger`

**How GNOME Controls It**:
- GNOME Settings Daemon provides D-Bus interface
- Function keys trigger D-Bus calls to Settings Daemon
- Settings Daemon writes to `/sys/class/leds/asus::kbd_backlight/brightness`

**Why It Doesn't Work in Niri**:
1. **No D-Bus service**: Niri doesn't have a service to handle function key events
2. **No key binding**: Niri might not be mapping the function keys to actions
3. **Permission issue**: The application/widget trying to control it might not have write access

**Direct Control Test**:
```bash
# This should work if run as root or with proper permissions
echo 0 > /sys/class/leds/asus::kbd_backlight/brightness  # Off
echo 1 > /sys/class/leds/asus::kbd_backlight/brightness  # Low
echo 2 > /sys/class/leds/asus::kbd_backlight/brightness  # Medium
echo 3 > /sys/class/leds/asus::kbd_backlight/brightness  # High
```

### 4. Brightness Control - ❌ STILL NOT WORKING

**Hardware Access**: Display backlight is accessible:
- Path: `/sys/class/backlight/amdgpu_bl1/`
- This is the AMD GPU backlight controller

**Status Update**: 
- ✅ GPU switching issue has been resolved (AMD iGPU is now active - see GPU_OFFLOAD_NOTES.txt)
- ❌ **Brightness controls still not working** (both software and keyboard function keys)

**Why It's Still Not Working**:
1. **No brightnessctl in PATH**: `brightnessctl` is only in `noctalia-shell` runtime dependencies, not system-wide
2. **No D-Bus service**: No service to handle brightness function keys
3. **No key bindings**: Niri may not have key bindings configured for brightness function keys
4. **Widget integration**: Noctalia widgets may not be properly configured to control brightness

**Current State**:
- ✅ GPU issue resolved - AMD is now the active GPU (backlight hardware is accessible)
- ❌ Brightness control via software (brightnessctl) - not working
- ❌ Brightness control via keyboard function keys - not working
- `brightnessctl` is listed in `noctalia-shell` runtimeDeps but not system-wide
- No service or key bindings to handle brightness function keys

**Next Steps** (to be addressed later):
1. Add `brightnessctl` to `environment.systemPackages` for system-wide availability
2. Configure Niri key bindings for brightness function keys (XF86MonBrightnessUp/Down)
3. Test Noctalia brightness widgets to see if they work with brightnessctl
4. Consider creating a D-Bus service or systemd user service for brightness control

### 5. Volume Control (Why It Works)

**Volume works because**:
- PipeWire is running as a system service (not GNOME-specific)
- PipeWire provides D-Bus interface (`org.freedesktop.MediaKeys1`)
- Function keys can directly control PipeWire via D-Bus
- Niri or the application can handle these keys

### 6. WiFi Status Widget Mis-reporting

**Problem**: The WiFi widget in Noctalia Shell shows as "off" even though WiFi is connected and working.

**Root Cause**: Scanning interval and timing issues in Noctalia's NetworkService:
- The widget icon depends on `NetworkService.networks` being populated with a connected network
- The scan happens asynchronously after component initialization
- If the scan doesn't complete or is delayed, `NetworkService.networks` remains empty
- The widget shows "wifi-off" when `networks` is empty, even if WiFi is actually connected
- The widget does NOT check `Settings.data.network.wifiEnabled` for icon display

**Current State**:
- ✅ WiFi adapter is enabled (`nmcli radio wifi` returns "enabled")
- ✅ WiFi is connected (active connection exists)
- ✅ `nmcli` scan command works correctly and shows connected network
- ❌ Widget shows "wifi-off" because `NetworkService.networks` is empty or scan hasn't completed

**Why It Happens**:
1. **Initial State**: On startup, `NetworkService.networks` starts as empty `{}`
2. **Scan Timing**: The scan happens asynchronously after component initialization
3. **Scan Failure/Delay**: If the scan fails or doesn't complete in time, `networks` remains empty
4. **Widget Logic**: Widget only checks `NetworkService.networks` for connected status, not `Settings.data.network.wifiEnabled`

**Solution Options**:
1. Fix widget logic to check `Settings.data.network.wifiEnabled` as fallback
2. Ensure scan completes reliably before widget renders
3. Improve state detection to combine `wifiEnabled` AND network connection status
4. Check if `nmcli` output format matches expected parsing

See `WIFI_STATUS_ISSUE_ANALYSIS.md` for detailed analysis.

### 7. Nightlight Functionality - ❌ STILL NOT WORKING

**Problem**: Nightlight (blue light filter) functionality does not work in Niri.

**Root Cause**: 
- Nightlight typically requires access to display color temperature controls
- May require specific GPU driver support or D-Bus services
- GNOME provides nightlight via Settings Daemon, which Niri doesn't have
- Note: GPU issue is resolved (AMD is now active), but nightlight still needs implementation

**Current State**:
- ❌ Nightlight not functional in Niri
- ❌ No equivalent service to GNOME's nightlight implementation
- ✅ GPU issue resolved (AMD is now active GPU - see GPU_OFFLOAD_NOTES.txt)
- `wlsunset` is available in noctalia-shell runtimeDeps but not configured/started

**Next Steps** (to be addressed later):
1. Configure `wlsunset` as a systemd user service for automatic nightlight
2. Integrate nightlight control into Noctalia widgets
3. Add key bindings or widget controls to toggle nightlight on/off
4. Check if display hardware supports color temperature adjustment

**Potential Solutions**:
1. Use `wlsunset` (already in noctalia-shell runtimeDeps) - provides Wayland nightlight
2. Configure `wlsunset` as a systemd user service
3. Integrate nightlight control into Noctalia widgets
4. Check if display hardware supports color temperature adjustment

**Note**: `wlsunset` is already available in noctalia-shell dependencies but may need to be configured/started.

### 8. Screen Recording Widget Not Connecting to gpu-screen-recorder

**Problem**: The screen recording bar widget in Noctalia does not properly connect to the `gpu-screen-recorder` package.

**Root Cause**: 
- Widget may be looking for `gpu-screen-recorder` in a different location
- Widget may not have proper permissions or environment variables
- Widget may need specific configuration to connect to the package
- Path or command name mismatch between widget expectations and actual package

**Current State**:
- ✅ `gpu-screen-recorder` is installed system-wide (see GPU_SCREEN_RECORDER_FIX.md)
- ✅ `gpu-screen-recorder` is available in PATH
- ✅ `gpu-screen-recorder` works when run directly from command line
- ❌ Widget does not properly connect/control the package

**Potential Solutions**:
1. Check widget source code to see how it's trying to call gpu-screen-recorder
2. Verify widget has access to PATH where gpu-screen-recorder is located
3. Check if widget needs specific environment variables or permissions
4. Ensure widget can execute the gpu-screen-recorder command
5. May need to configure widget with explicit path to gpu-screen-recorder

**Note**: This is a widget integration issue, not a package installation issue. The package itself works correctly.

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
2. ❌ **Backlit Keyboard**: No service to handle function keys → no D-Bus interface → no control
3. ✅ **GPU Issue**: **RESOLVED** - AMD iGPU is now active (see GPU_OFFLOAD_NOTES.txt)
4. ❌ **Brightness Control**: **STILL NOT WORKING** - Both software and keyboard function keys (needs brightnessctl in PATH and key bindings/service)
5. ❌ **Nightlight**: **STILL NOT WORKING** - Needs implementation (wlsunset configuration)
6. ❌ **WiFi Status Widget**: Mis-reports as "off" due to scanning interval/timing issues in Noctalia
7. ❌ **Screen Recording Widget**: Does not properly connect to gpu-screen-recorder package
8. ✅ **Volume**: Works because PipeWire is session-independent

**Why GNOME Works**:
- GNOME Settings Daemon provides D-Bus interfaces for all hardware controls
- Function keys are automatically mapped to D-Bus calls
- Services are started automatically with the session

**Why Niri Doesn't Work**:
- No equivalent to GNOME Settings Daemon
- Function keys not automatically mapped
- Services need explicit configuration
- Some tools (like `brightnessctl`) not in system PATH

**Next Steps** (Priority Order):
1. ✅ ~~Fix ASUS DialPad Wayland display detection~~ - **COMPLETED**
2. ✅ ~~Resolve GPU switching issue (AMD now active)~~ - **COMPLETED** (see GPU_OFFLOAD_NOTES.txt)
3. ❌ **TODO**: Fix brightness control (software and keyboard function keys)
   - Add `brightnessctl` to system packages
   - Configure Niri key bindings for brightness function keys
   - Test Noctalia brightness widgets
4. ❌ **TODO**: Configure nightlight functionality (wlsunset or alternative)
   - Set up wlsunset as systemd user service
   - Add controls/widgets for nightlight toggle
5. ❌ **TODO**: Fix WiFi widget logic in Noctalia to handle scanning intervals properly (see WIFI_STATUS_ISSUE_ANALYSIS.md)
6. ❌ **TODO**: Fix screen recording widget connection to gpu-screen-recorder
7. ❌ **TODO**: Fix backlit keyboard control (function keys)
   - Configure Niri key bindings OR
   - Create a hardware control service to handle function keys

