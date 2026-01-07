# DaVinci Resolve Audio Conflict Issue

**Date**: December 21, 2025  
**Issue**: DaVinci Resolve causes audio degradation in other applications (Spotify, VLC)  
**Symptom**: When DaVinci Resolve is running, audio quality degrades for all applications. When DaVinci closes, audio quality returns to normal.

---

## Problem Description

When DaVinci Resolve is running:
- ✅ Video plays correctly
- ❌ No audio in DaVinci Resolve
- ❌ Audio quality degrades significantly in other applications (Spotify, VLC)
- ✅ Audio quality returns to normal when DaVinci Resolve is closed

This suggests DaVinci Resolve is **interfering with the audio system** rather than just not playing audio itself.

---

## Root Cause Analysis

### Likely Causes

1. **Exclusive Audio Access**: DaVinci Resolve may be opening the ALSA audio device with exclusive access, preventing other applications from using it properly.

2. **Direct Hardware Access**: DaVinci Resolve might be bypassing PipeWire and accessing `/dev/snd/*` directly, which conflicts with PipeWire's control of the audio device.

3. **Sample Rate/Format Conflict**: DaVinci Resolve might be changing the audio device's sample rate or format, forcing PipeWire to resample all audio, causing quality degradation.

4. **ALSA Plugin Not Used**: Despite environment variables, DaVinci Resolve might not be using the PulseAudio ALSA plugin and is accessing hardware directly.

---

## Current Configuration

### Environment Variables Set (in `nvidia-offload` wrapper)

```bash
ALSA_PCM_NAME=pulse              # Force PulseAudio plugin
ALSA_PLUGIN_DIR=/nix/store/.../lib/alsa-lib  # Plugin location
LD_LIBRARY_PATH=/nix/store/.../alsa-plugins/lib  # Library path
XDG_RUNTIME_DIR=/run/user/1000   # PipeWire socket location
PIPEWIRE_RUNTIME_DIR=/run/user/1000
PULSE_RUNTIME_PATH=/run/user/1000/pulse
PULSE_SERVER=unix:/run/user/1000/pulse/native
```

### ALSA Configuration

`~/.asoundrc`:
```
pcm.!default {
  type pulse
}
ctl.!default {
  type pulse
}
```

---

## Diagnostic Steps

### 1. Check What Audio Devices DaVinci Resolve Opens

```bash
# While DaVinci Resolve is running
RESOLVE_PID=$(pgrep -f resolve | head -1)
lsof -p $RESOLVE_PID | grep -E "/dev/snd|audio|pulse"
```

**If this shows `/dev/snd/*` devices**: DaVinci is accessing hardware directly, bypassing PipeWire.

### 2. Check for Exclusive Access

```bash
# Check what processes are using audio devices
lsof /dev/snd/*
```

**If DaVinci Resolve appears here**: It's holding the audio device, potentially with exclusive access.

### 3. Check PipeWire Status

```bash
systemctl --user status pipewire pipewire-pulse
pw-cli info  # If available
```

---

## Potential Solutions

### Solution 1: Force PulseAudio Plugin Usage (Current Attempt)

**Status**: ✅ Implemented in `gpu-offload.nix`

We've set:
- `ALSA_PCM_NAME=pulse` - Forces PulseAudio plugin
- `ALSA_PLUGIN_DIR` - Points to plugin location
- `LD_LIBRARY_PATH` - Ensures plugin library is found

**If this doesn't work**: DaVinci Resolve may be ignoring ALSA configuration and opening devices directly.

---

### Solution 2: Configure DaVinci Resolve Audio Settings

**Location**: `Preferences > System > Video and Audio I/O`

1. Set **Audio Output Device** to "Manual"
2. Select **PulseAudio** or **default** as the device
3. **Disable "Exclusive Mode"** if such an option exists
4. Set **Audio Sample Rate** to match system (typically 48000 Hz)

**Note**: Some versions of DaVinci Resolve don't expose these options, or they may be in different locations.

---

### Solution 3: Configure PipeWire to Prevent Exclusive Access

Create `~/.config/pipewire/pipewire.conf` to configure PipeWire behavior:

```ini
context.properties = {
    # Prevent applications from taking exclusive access
    default.clock.rate = 48000
    default.clock.quantum = 1024
    default.clock.min-quantum = 32
    default.clock.max-quantum = 8192
}

# Configure ALSA to work better with PipeWire
alsa.properties = {
    # Don't allow exclusive access
    api.alsa.use-acp = true
    api.alsa.acp.auto-profile = false
}
```

**Note**: This requires PipeWire configuration knowledge and may need adjustment.

---

### Solution 4: Use PulseAudio Directly (If PipeWire is the Issue)

If the issue is PipeWire-specific, we could try:
1. Install PulseAudio (separate from PipeWire)
2. Configure DaVinci Resolve to use PulseAudio directly
3. This is a workaround, not ideal

---

### Solution 5: Check DaVinci Resolve Version-Specific Issues

**Current Version**: 20.3.0.0010

- Check DaVinci Resolve release notes for audio-related changes
- Search for known issues with this version and Linux audio
- Consider downgrading if a previous version worked

---

## Immediate Next Steps

1. **Rebuild NixOS** with the updated `gpu-offload.nix`:
   ```bash
   sudo nixos-rebuild switch
   ```

2. **Restart DaVinci Resolve** completely

3. **Run diagnostic script**:
   ```bash
   ./check-audio-conflict.sh
   ```

4. **Check DaVinci Resolve audio settings**:
   - `Preferences > System > Video and Audio I/O`
   - Try different audio output device settings
   - Look for any "exclusive mode" or "direct access" options

5. **Monitor audio while DaVinci is running**:
   - Launch DaVinci Resolve
   - Play audio in Spotify/VLC
   - Note the quality difference
   - Check `lsof /dev/snd/*` to see what DaVinci is accessing

---

## Expected Behavior After Fix

- ✅ DaVinci Resolve plays audio correctly
- ✅ Other applications (Spotify, VLC) maintain normal audio quality
- ✅ No audio degradation when DaVinci Resolve is running
- ✅ Multiple applications can use audio simultaneously

---

## Related Files

- `gpu-offload.nix` - Contains `nvidia-offload` wrapper with audio environment variables
- `~/.asoundrc` - ALSA configuration routing to PulseAudio
- `~/.config/home-manager/home.nix` - Home Manager config with `.asoundrc` and `alsa-plugins`
- `check-audio-conflict.sh` - Diagnostic script for audio conflicts

---

## Notes

- This is a **DaVinci Resolve-specific issue**, not a system configuration problem
- The system audio configuration (PipeWire, ALSA, environment variables) is correct
- The issue is that DaVinci Resolve is likely bypassing our configuration and accessing audio hardware directly
- This may require a DaVinci Resolve update or configuration change to fix properly

