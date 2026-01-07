# DisplayPort Multi-Stream Transport (DP-MST) Configuration

## Problem
Only one monitor is detected when using daisy-chained monitors via USB-C -> DP (USB-C -> Monitor 1 -> DP out -> Monitor 2). This works fine in Windows but not in NixOS/Niri.

## Hardware Topology
- **NVIDIA GPU (card1)**: Handles internal display (eDP) and HDMI ports
- **AMD iGPU (card2)**: Handles USB-C display ports (USB-C ports are on CPU/iGPU bus)
- **USB-C for MST**: Connected to AMD iGPU, which is already being used by Niri compositor ✅

This is ideal for MST - since USB-C is on AMD and we're using AMD for the compositor, MST should work without needing NVIDIA modesetting.

## Changes Made

### 1. Kernel Parameters (`configuration.nix`)
Added kernel parameters to enable MST debugging and ensure proper MST initialization:
```nix
boot.kernelParams = [
  "drm.debug=0x04"  # Enable DRM debug output for MST
];
```

### 2. Niri Wrapper Comments (`niri.nix`)
Added documentation about MST support in the Niri wrapper script, noting that MST should work as long as the USB-C port is connected to the AMD card.

### 3. NVIDIA Modesetting Note (`gpu-offload.nix`)
Added a comment about NVIDIA modesetting (not needed for this setup since USB-C is on AMD).

## Diagnostic Steps

### 1. Check which GPU handles your USB-C port
```bash
# Check DP port status
ls -la /sys/class/drm/card*/card*-DP-*/status

# Check which card has active DP connections
for dp in /sys/class/drm/card*/card*-DP-*/status; do
  echo "$dp: $(cat $dp 2>/dev/null || echo 'not found')"
done
```

### 2. Check MST topology detection
```bash
# After connecting monitors, check dmesg for MST messages
sudo dmesg | grep -iE "mst|displayport.*mst"

# Check if MST devices are detected
ls -la /sys/class/drm/card*/card*-DP-*/dp_mst* 2>/dev/null
```

### 3. Check current displays in Niri
```bash
# If wlr-randr is available
wlr-randr

# Or check DRM directly
cat /sys/class/drm/card*/status
```

### 4. Verify AMD card is handling USB-C
Since USB-C is on AMD (card2), verify it's being used:
```bash
# Check which card has active DP connections
for dp in /sys/class/drm/card2/card2-DP-*/status; do
  echo "$dp: $(cat $dp 2>/dev/null || echo 'not found')"
done

# Should show "connected" for USB-C DP ports on card2 (AMD)
```

## Expected Behavior

After rebuilding with these changes:
- MST topology should be detected when monitors are connected
- Both monitors should appear in `wlr-randr` or display settings
- MST debug messages should appear in `dmesg`

## Solution: Auto-Enable MST Outputs

**Problem Found**: MST topology is detected by the kernel, but the second monitor (DP-11) is connected but disabled. Niri/wlroots detects it but doesn't enable it automatically.

**Solution Implemented**:
1. Added `wlr-randr` to system packages for display management
2. Created `enable-mst-outputs` script that detects and enables disabled MST outputs
3. Added systemd service to run the script after Niri starts

**Manual Test** (before rebuild):
```bash
# Enable the second monitor manually
wlr-randr --output DP-11 --on

# Verify both monitors are enabled
niri msg outputs
```

**After Rebuild**: The `enable-mst-outputs` service will automatically enable MST outputs on boot.

## If MST Still Doesn't Work

1. **Verify USB-C connection**: Confirm USB-C is on AMD card2 (should be based on hardware topology)
2. **Check MST topology**: Look for MST devices in `/sys/class/drm/card2/card2-DP-*/dp_mst*`
3. **Check cable/adapter**: Ensure your USB-C to DP adapter supports MST (some adapters don't)
4. **Monitor MST capability**: Verify both monitors support MST daisy-chaining
5. **Manually enable outputs**: Use `wlr-randr --output DP-11 --on` to enable the second monitor
6. **Check kernel logs**: `journalctl -k | grep -i mst` should show MST topology detection
7. **Increase debug level**: Temporarily change `drm.debug=0x04` to `drm.debug=0x0e` for more verbose MST logging

## Additional Resources

- [DRM MST Documentation](https://www.kernel.org/doc/html/latest/gpu/drm-kms.html#displayport-multi-stream-transport-mst-support)
- [wlroots MST Support](https://gitlab.freedesktop.org/wlroots/wlroots/-/issues)

