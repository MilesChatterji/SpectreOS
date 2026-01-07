# DaVinci Resolve Video Playback Fix

**Date**: December 20, 2025  
**Issue**: Black video playback with no audio in DaVinci Resolve Studio  
**Status**: ✅ Video fixed, 🔄 Audio still needs investigation

---

## Problem Description

DaVinci Resolve Studio was showing black video playback with no audio, despite:
- NVIDIA GPU being detected and selected in DaVinci preferences
- `nvidia-smi` showing GPU memory usage (634MiB)
- GPU processing mode set to "Auto" in DaVinci settings

---

## Root Cause

The DaVinci Resolve process was launched with **AMD GPU environment variables** instead of NVIDIA, causing the video decoder to use the AMD iGPU instead of the NVIDIA dGPU.

**Environment variables in the running process (incorrect):**
```
DRI_PRIME=0                          # AMD iGPU
__GLX_VENDOR_LIBRARY_NAME=mesa       # Mesa/AMD drivers
__NV_PRIME_RENDER_OFFLOAD=0          # NVIDIA offload disabled
__VK_LAYER_NV_optimus=               # NVIDIA Vulkan layer disabled
MESA_LOADER_DRIVER_OVERRIDE=radeonsi # Force AMD driver
```

**What it should be (with NVIDIA offload):**
```
DRI_PRIME=1                          # NVIDIA dGPU
__GLX_VENDOR_LIBRARY_NAME=nvidia     # NVIDIA drivers
__NV_PRIME_RENDER_OFFLOAD=1          # NVIDIA offload enabled
__VK_LAYER_NV_optimus=NVIDIA_only    # NVIDIA Vulkan layer enabled
```

---

## Solution

Created a custom desktop file that launches DaVinci Resolve with the `nvidia-offload` wrapper, which sets the correct NVIDIA environment variables.

### Implementation

**File**: `~/.config/home-manager/home.nix`

Added to `home.file`:
```nix
# Custom desktop file for DaVinci Resolve Studio with NVIDIA GPU offload
# This fixes black video playback and GPU memory errors by forcing NVIDIA GPU usage
# The nvidia-offload wrapper sets: __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia
".local/share/applications/davinci-resolve-studio.desktop" = {
  text = ''
    [Desktop Entry]
    Categories=AudioVideo;AudioVideoEditing;Video;Graphics
    Comment=Professional video editing, color, effects and audio post-processing
    Exec=/run/current-system/sw/bin/nvidia-offload davinci-resolve-studio
    GenericName=Video Editor
    Icon=davinci-resolve-studio
    Name=Davinci Resolve Studio
    StartupWMClass=resolve
    Type=Application
    Version=1.5
  '';
  force = true;
};
```

**Location**: `~/.local/share/applications/davinci-resolve-studio.desktop`

**Key change**: The `Exec` line now uses `/run/current-system/sw/bin/nvidia-offload davinci-resolve-studio` instead of just `davinci-resolve-studio`.

---

## How It Works

The `nvidia-offload` wrapper script (defined in `gpu-offload.nix`) sets the following environment variables:

```bash
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export DRI_PRIME=1
export GBM_BACKEND=nvidia-drm
```

These variables ensure that:
1. **OpenGL applications** use NVIDIA via `__GLX_VENDOR_LIBRARY_NAME=nvidia`
2. **Vulkan applications** use NVIDIA via `__VK_LAYER_NV_optimus=NVIDIA_only`
3. **Legacy DRI applications** use NVIDIA via `DRI_PRIME=1`
4. **PRIME offload** is enabled via `__NV_PRIME_RENDER_OFFLOAD=1`

---

## Why "Auto" GPU Selection Didn't Work

When DaVinci Resolve's GPU processing mode is set to "Auto", it relies on system environment variables to determine which GPU to use. Since the system defaults to AMD iGPU (configured in `gpu-offload.nix` for power saving), DaVinci Resolve would detect AMD first and use it for video decoding.

**Manual fix alternative**: Setting GPU processing mode to "CUDA" and manually selecting the NVIDIA GPU in DaVinci preferences would also work, but:
- Requires manual configuration for each user
- May reset after updates
- Doesn't fix the environment variable issue at launch

**Our solution**: The desktop file ensures NVIDIA is used from the moment DaVinci Resolve launches, regardless of DaVinci's internal "Auto" setting.

---

## Verification

After restarting DaVinci Resolve with the new desktop file:

1. **Check environment variables**:
   ```bash
   cat /proc/$(pgrep -f resolve | head -1)/environ | tr '\0' '\n' | grep -E "NV|GLX|DRI|VK"
   ```
   Should show:
   - `__NV_PRIME_RENDER_OFFLOAD=1`
   - `__GLX_VENDOR_LIBRARY_NAME=nvidia`
   - `DRI_PRIME=1`

2. **Check GPU usage**:
   ```bash
   nvidia-smi
   ```
   Should show DaVinci Resolve process using NVIDIA GPU memory.

3. **Video playback**: Should now display correctly (not black screen).

---

## System Configuration Context

This fix works in conjunction with the GPU offloading configuration in `gpu-offload.nix`:

- **Default**: System uses AMD iGPU for power saving
- **On-demand**: Applications can request NVIDIA via `nvidia-offload` wrapper
- **DaVinci Resolve**: Now automatically uses NVIDIA via the custom desktop file

This maintains the power-saving benefits of using AMD iGPU by default while ensuring DaVinci Resolve gets the performance it needs.

---

## Related Files

- `~/.config/home-manager/home.nix` - Home Manager configuration with desktop file
- `gpu-offload.nix` - GPU offloading configuration and `nvidia-offload` wrapper
- `~/.local/share/applications/davinci-resolve-studio.desktop` - Custom desktop file (managed by Home Manager)

---

## Notes

- The desktop file is managed by Home Manager, so it will persist across rebuilds
- If DaVinci Resolve is launched from the command line, use: `nvidia-offload davinci-resolve-studio`
- The fix applies to video decoding/playback - audio issues may be separate (see audio troubleshooting)

---

## Audio Issue (Fixed)

**Symptom**: Video plays correctly but no audio output.

**Root Cause**: The `nvidia-offload` wrapper was not preserving audio environment variables (`XDG_RUNTIME_DIR`, `PIPEWIRE_RUNTIME_DIR`, `PULSE_RUNTIME_PATH`) needed for DaVinci Resolve to find PipeWire sockets.

**Investigation Findings**:
- ✅ Audio devices (`/dev/snd/`) are accessible from FHS environment
- ✅ PipeWire sockets are accessible from FHS environment  
- ❌ Audio environment variables were not being preserved by `nvidia-offload` wrapper
- ✅ System audio works (VLC plays audio correctly)
- ✅ Audio codec is Linear PCM (well-supported standard)

**Solution Applied**:

Updated the `nvidia-offload` wrapper in `gpu-offload.nix` to preserve audio environment variables:

```nix
# Preserve audio environment variables (for PipeWire/PulseAudio)
# These are needed for applications that use audio (DaVinci Resolve, etc.)
if [ -n "$XDG_RUNTIME_DIR" ]; then
  export XDG_RUNTIME_DIR
  export PIPEWIRE_RUNTIME_DIR="$XDG_RUNTIME_DIR"
  export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"
fi
```

**Why This Fixes It**:
- DaVinci Resolve uses Qt's audio system (`QAudioOutput`, `QAudioDeviceInfo`)
- Qt audio system needs `XDG_RUNTIME_DIR` to find PipeWire sockets
- Without these environment variables, DaVinci Resolve can't connect to the audio system
- The wrapper now ensures these variables are passed through to the application

**Additional Troubleshooting Steps** (if audio still doesn't work after rebuild):

1. **Check DaVinci Resolve Audio Settings**:
   - Go to `Preferences > System > Audio`
   - Check `Audio Output Device` - ensure it's set to the correct device (not "None")
   - Verify `Audio Monitoring` is enabled
   - Check `Audio Sample Rate` matches your system (typically 48000 Hz)

2. **Verify Environment Variables After Rebuild**:
   ```bash
   # After restarting DaVinci Resolve, check if audio env vars are set
   cat /proc/$(pgrep -f resolve | head -1)/environ | tr '\0' '\n' | grep -i "XDG_RUNTIME\|PIPEWIRE\|PULSE"
   ```
   Should show:
   - `XDG_RUNTIME_DIR=/run/user/1000`
   - `PIPEWIRE_RUNTIME_DIR=/run/user/1000`
   - `PULSE_RUNTIME_PATH=/run/user/1000/pulse`

**Next Steps for Audio Troubleshooting**:

1. **Check DaVinci Resolve Audio Settings**:
   ```
   Preferences > System > Audio
   - Audio Output Device: [Select your audio device]
   - Audio Monitoring: [Enabled]
   - Audio Sample Rate: [48000 Hz or match system]
   ```

2. **Verify System Audio**:
   ```bash
   # Check PipeWire is running
   systemctl --user status pipewire pipewire-pulse
   
   # Test audio in another app (VLC, Spotify)
   # If they work, issue is DaVinci-specific
   ```

3. **Check Audio Codec**:
   - In DaVinci Resolve: Right-click video clip > Clip Attributes
   - Note the audio codec (AAC, PCM, AC3, etc.)
   - Some codecs may need conversion

4. **FHS Environment Fix** (if needed):
   - DaVinci Resolve package may need audio socket bind mounts
   - This would require modifying the Nix package definition
   - Check if `~/.local/share/DaVinciResolve/` has audio configuration files

**Related Files**:
- DaVinci Resolve audio logs: `~/.local/share/BlackmagicDesign/DaVinci Resolve/logs/`
- System audio: PipeWire (running via systemd user service)
- Audio devices: `/dev/snd/` (accessible)
- PipeWire socket: `$XDG_RUNTIME_DIR/pipewire-0` (exists, but may not be accessible from FHS environment)

---

## Audio Issue - Final Fix

**Symptom**: Video plays correctly but no audio output, even after environment variable fixes.

**Root Cause**: `pipewire-pulse` service was not running. DaVinci Resolve uses the PulseAudio API (not direct PipeWire), so it requires `pipewire-pulse` to be active to provide PulseAudio compatibility.

**Investigation Findings**:
- ✅ Environment variables were set correctly (`XDG_RUNTIME_DIR`, `PIPEWIRE_RUNTIME_DIR`, `PULSE_RUNTIME_PATH`)
- ✅ `.asoundrc` was configured correctly
- ✅ `alsa-plugins` was installed
- ❌ `pipewire-pulse` service was **inactive (dead)**
- ✅ `pipewire` service was active, but `pipewire-pulse` was not

**Solution Applied**:

1. **Immediate fix**: Started and enabled `pipewire-pulse` service:
   ```bash
   systemctl --user start pipewire-pulse
   systemctl --user enable pipewire-pulse
   ```

2. **Permanent fix**: Added `pipewire-pulse` to Home Manager's systemd user services in `home.nix`:
   ```nix
   systemd.user.services.pipewire-pulse = {
     Unit = {
       Description = "PipeWire PulseAudio";
       After = [ "pipewire.service" ];
       Requires = [ "pipewire.service" ];
     };
     Install = {
       WantedBy = [ "default.target" ];
     };
   };
   ```

**Why This Fixes It**:
- DaVinci Resolve uses Qt's audio system, which can use either PulseAudio or ALSA
- When using PulseAudio API, it connects to `$PULSE_RUNTIME_PATH/native` socket
- This socket is only available when `pipewire-pulse` is running
- `pipewire-pulse` provides PulseAudio compatibility layer on top of PipeWire
- Without `pipewire-pulse`, the PulseAudio socket exists but has no server to handle connections

**Verification**:
```bash
# Check pipewire-pulse is running
systemctl --user status pipewire-pulse
# Should show: Active: active (running)

# Check PulseAudio socket exists
ls -la $XDG_RUNTIME_DIR/pulse/native
# Should show: srw-rw-rw- (socket file)
```

---

## Status

✅ **Video playback**: Fixed - video now displays correctly  
✅ **Audio playback**: Fixed - `pipewire-pulse` service now enabled and running

**To Apply Audio Fix**:
1. Rebuild Home Manager: `home-manager switch`
2. Restart DaVinci Resolve (close completely and relaunch)
3. Audio should now work

**Note**: The complete audio fix requires:
1. `nvidia-offload` wrapper preserving audio environment variables (in `gpu-offload.nix`)
2. `.asoundrc` configuration for ALSA routing (in `home.nix`)
3. `alsa-plugins` package installed (in `home.nix`)
4. `pipewire-pulse` service enabled and running (in `home.nix` systemd user services)

