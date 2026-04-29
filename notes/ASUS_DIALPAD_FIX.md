# ASUS DialPad Driver Fix

## Status: ✅ RESOLVED

The ASUS DialPad driver is now working correctly in Niri. The service successfully connects to the Wayland display and runs without constant restarts.

## Problem (Historical)

The ASUS DialPad driver service was failing constantly with:
```
ERROR Failed to connect to Wayland display: Unable to connect to display
```

This caused:
- **183+ restart attempts** (and counting)
- **RAM buildup** from failed processes
- **Service never successfully starting**

## Root Cause

The service was hardcoded to use `WAYLAND_DISPLAY=wayland-0`, but the actual Wayland display in the Niri session is `wayland-1`. The display name varies by session and cannot be hardcoded.

## Solution

### Changes Made

1. **Removed hardcoded `WAYLAND_DISPLAY`**: Let the service inherit the display name from the session environment
2. **Added `PassEnvironment`**: Explicitly pass through `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, and `XDG_SESSION_TYPE` from the session
3. **Added `ExecStartPre` check**: Wait for the Wayland socket to be available before starting the service

### Updated Configuration

```nix
systemd.user.services.asus-dialpad-driver = {
  description = "ASUS DialPad Driver";
  wantedBy = [ "graphical-session.target" ];
  after = [ "graphical-session.target" ];
  serviceConfig = {
    Type = "simple";
    # Wait for Wayland display to be available before starting
    ExecStartPre = "${pkgs.bash}/bin/bash -c 'while [ -z \"$WAYLAND_DISPLAY\" ] || [ ! -S \"$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY\" ]; do sleep 0.5; done; echo \"Wayland display ready: $WAYLAND_DISPLAY\"'";
    ExecStart = "${asus-dialpad-driver}/bin/asus-dialpad-driver proartp16";
    WorkingDirectory = "${asus-dialpad-driver}/share/asus-dialpad-driver";
    Restart = "on-failure";
    RestartSec = 5;
    StandardOutput = "journal";
    StandardError = "journal";
    Environment = [
      "XDG_SESSION_TYPE=wayland"
      "LOG=WARNING"
      "HOME=%h"
    ];
    # Pass through environment from the session (including WAYLAND_DISPLAY)
    PassEnvironment = [ "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" "XDG_SESSION_TYPE" ];
  };
};
```

## How It Works

1. **`ExecStartPre`**: Waits for `WAYLAND_DISPLAY` to be set in the environment AND for the socket file to exist at `$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY`
2. **`PassEnvironment`**: Ensures the service inherits the correct `WAYLAND_DISPLAY` value from the graphical session
3. **No hardcoding**: The service adapts to whatever Wayland display name is used (wayland-0, wayland-1, etc.)

## After Rebuild

After rebuilding with `nixos-rebuild switch`:

1. **Reload systemd user services**:
   ```bash
   systemctl --user daemon-reload
   ```

2. **Stop the failing service** (if still running):
   ```bash
   systemctl --user stop asus-dialpad-driver
   ```

3. **Start the service**:
   ```bash
   systemctl --user start asus-dialpad-driver
   ```

4. **Check status**:
   ```bash
   systemctl --user status asus-dialpad-driver
   ```

5. **Check logs**:
   ```bash
   journalctl --user -u asus-dialpad-driver -f
   ```

## Expected Behavior

- Service should start successfully after Wayland display is ready
- No more "Failed to connect to Wayland display" errors
- Service should remain running (not constantly restarting)
- RAM usage should stabilize (no more buildup from failed processes)

## Verification

Check that the service is running and not restarting:

```bash
# Should show "active (running)" without constant restarts
systemctl --user status asus-dialpad-driver

# Should show successful connection (no errors)
journalctl --user -u asus-dialpad-driver -n 20

# Check restart count (should be low/stable)
systemctl --user show asus-dialpad-driver | grep NRestarts
```

## Notes

- The Wayland display name (`wayland-0`, `wayland-1`, etc.) is assigned by the compositor
- Different sessions may use different display names
- The fix ensures the service adapts to whatever display name is used
- The `ExecStartPre` check ensures the socket is actually available before attempting connection

## Current Status

✅ **Service is working correctly** - The ASUS DialPad driver now:
- Successfully connects to Wayland display (dynamically detected)
- Starts reliably after Wayland session is ready
- Runs without constant restarts
- No RAM buildup from failed processes
- Works in both GNOME and Niri sessions

The fix has been tested and verified. The service should start automatically when logging into a graphical session.

---

## Driver Version 2.2.0 Bug Fixes (2026-04-22)

Two additional bugs were found in asus-dialpad-driver 2.2.0 and patched via `postPatch` in `asus-dialpad.nix`.

### Bug 1: `coactivator_keys = None` causes TypeError on startup

`coactivator_keys` is initialized to `None` at module level. The Wayland keymap event fires early (before `load_all_config_values()` runs), triggering `wl_keyboard_keymap_handler` → `wl_load_keymap_state()` → `load_evdev_keys_for_coactivator_modifiers(None)`, which tries to iterate over `None`.

**Fix:**
```bash
substituteInPlace dialpad.py \
  --replace-fail "coactivator_keys = None" "coactivator_keys = []"
```

### Bug 2: `send_key_event` checks `uinput_device` which is never assigned

`initialize_virtual_device()` correctly creates `udev = dev.create_uinput_device()`, but `send_key_event` checks `uinput_device` (always `None`), causing every key event to log "Virtual device is not initialized" and return early. This is a 2.2.0 rename regression — the variable was renamed in half the code.

**Fix:**
```bash
# \b word boundaries prevent replacing create_uinput_device method name
sed -i 's/\buinput_device\b/udev/g' dialpad.py
```

### Config file note

`top_right_icon_coactivator_key` should be left empty (the default). Empty means no modifier key is required to toggle the dialpad via the top-right corner. Setting it to e.g. `KEY_LEFTSHIFT` would require holding Shift while touching to activate.

