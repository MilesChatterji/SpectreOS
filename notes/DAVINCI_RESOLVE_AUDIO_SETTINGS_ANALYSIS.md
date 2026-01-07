# DaVinci Resolve Audio Settings Analysis

**Date**: December 21, 2025  
**Status**: Investigating - No actions taken  
**User Settings**: Same as previous working configuration

---

## Current DaVinci Resolve Audio Settings (from screenshot)

**Location**: `Preferences > System > Video and Audio I/O`

### Audio I/O Section:
- **I/O Engine**: `System Audio` (selected, dropdown shows "System Audio" and "Desktop Video")
- **Output device**: `Default` (dropdown)
- **Input device**: `Default` (dropdown)
- **Automatic speaker configuration**: ✅ Checked
- **Playback processing buffer size**: (empty/default)
- **Record buffer size**: (empty/default)

### Video I/O Section:
- **Capture device**: `None`
- **Monitor device**: `None`
- **Release video device when not in focus**: ❌ Unchecked

---

## Key Observations

1. **Settings Interface is Different**: The actual interface doesn't have the "Audio Output Device" with "Manual" option that I was expecting. Instead, it has:
   - **I/O Engine** dropdown (System Audio vs Desktop Video)
   - **Output device** dropdown (set to "Default")
   - **Input device** dropdown (set to "Default")

2. **Settings Haven't Changed**: User confirms these are the same settings that worked before today's issues.

3. **"System Audio" Selected**: The I/O Engine is set to "System Audio", which should route through PipeWire/PulseAudio.

4. **"Default" Output Device**: This should use the system default audio device (PipeWire).

---

## What Changed Today

Since these settings worked before, something else changed:

1. **DaVinci Resolve Update**: User mentioned it worked before a recent update
2. **System Configuration Changes**: We made several changes today:
   - Added `ALSA_PLUGIN_DIR` to `nvidia-offload` wrapper
   - Added `LD_LIBRARY_PATH` to `nvidia-offload` wrapper
   - Enabled `pipewire-pulse` service
   - Created `.asoundrc` configuration
   - Added `alsa-plugins` package

3. **PipeWire State**: We discovered PipeWire gets into a degraded state when DaVinci Resolve runs

---

## Investigation Points for Tomorrow

### 1. Check if "Default" Output Device is Actually Working

**Test**: Try changing the "Output device" dropdown from "Default" to see if other options appear:
- Look for `pulse`, `pulseaudio`, or specific device names
- Check if selecting a different device makes audio work

### 2. Check I/O Engine Options

**Test**: The dropdown shows "System Audio" and "Desktop Video":
- What happens if "Desktop Video" is selected?
- Is "System Audio" the correct choice for PipeWire?

### 3. Verify Environment Variables Are Being Used

**Check**: Even though settings are "Default", DaVinci Resolve should still use:
- `ALSA_PCM_NAME=pulse` (from `nvidia-offload` wrapper)
- `PULSE_SERVER=unix:/run/user/1000/pulse/native`
- `ALSA_PLUGIN_DIR` and `LD_LIBRARY_PATH`

**Verify**: Check if DaVinci Resolve process has these variables:
```bash
RESOLVE_PID=$(pgrep -f resolve | head -1)
cat /proc/$RESOLVE_PID/environ | tr '\0' '\n' | grep -E "ALSA|PULSE|LD_LIBRARY"
```

### 4. Check DaVinci Resolve Logs

**Location**: `~/.local/share/BlackmagicDesign/DaVinci Resolve/logs/`

**Look for**:
- Audio initialization errors
- ALSA/PulseAudio connection errors
- Device enumeration issues
- Sample rate conflicts

### 5. Test Audio Device Selection

**Possible Issue**: "Default" might not be resolving correctly in the FHS environment.

**Test**: 
- Try manually selecting a device from the "Output device" dropdown
- Check if any devices are listed (might be empty if DaVinci can't enumerate them)

### 6. Check if Audio Works in Other DaVinci Resolve Projects

**Test**: 
- Create a new test project
- Import a video with audio
- Check if audio plays in the new project
- This helps determine if it's project-specific or global

---

## Potential Root Causes

### Hypothesis 1: "Default" Device Not Resolving in FHS Environment

**Issue**: DaVinci Resolve's FHS environment might not be able to resolve "Default" to the actual PulseAudio device.

**Solution**: Manually select the audio device instead of "Default".

### Hypothesis 2: ALSA Plugin Not Loading

**Issue**: Despite `ALSA_PLUGIN_DIR` and `LD_LIBRARY_PATH` being set, DaVinci Resolve might not be finding the PulseAudio ALSA plugin.

**Check**: Verify the plugin is accessible from within the FHS environment.

### Hypothesis 3: DaVinci Resolve Update Changed Audio Behavior

**Issue**: The update might have changed how DaVinci Resolve handles "System Audio" or "Default" device selection.

**Solution**: Check DaVinci Resolve release notes or try different I/O Engine settings.

### Hypothesis 4: PipeWire State Issue

**Issue**: Even though we restart PipeWire, DaVinci Resolve might be opening audio with incompatible parameters.

**Check**: Monitor PipeWire state while DaVinci Resolve is running.

---

## Next Steps (Tomorrow)

1. **Check Output Device Dropdown**: See what options are available when clicking "Output device"
2. **Try Manual Device Selection**: If options exist, try selecting one explicitly
3. **Check DaVinci Resolve Logs**: Look for audio-related errors
4. **Verify Environment Variables**: Confirm they're present in the DaVinci Resolve process
5. **Test with New Project**: See if issue is project-specific
6. **Check I/O Engine Options**: Understand what "Desktop Video" does vs "System Audio"

---

## Related Files

- `gpu-offload.nix` - Contains `nvidia-offload` wrapper with audio environment variables
- `~/.asoundrc` - ALSA configuration
- `~/.config/home-manager/home.nix` - Home Manager config
- `notes/DAVINCI_RESOLVE_AUDIO_SOLUTION.md` - PipeWire restart solution

---

## Additional Observation: Microphone Activity

**User Report**: Microphone was active/armed when DaVinci Resolve was open, even though not recording.

**Implications**:
- DaVinci Resolve is accessing **both input and output audio devices** on startup
- This could explain the audio quality degradation (holding both devices)
- This could explain why audio doesn't work (conflict with input/output access)
- DaVinci Resolve might be opening audio devices in a way that affects PipeWire state

**Investigation Points**:
1. Check if DaVinci Resolve is opening input device unnecessarily
2. Check "Input device" setting - currently set to "Default"
3. See if disabling input device or setting it to "None" helps
4. Check if DaVinci Resolve has an option to not access input until recording starts

---

## Notes

- User's settings worked before today
- Interface is different than expected (no "Manual" option visible)
- "System Audio" + "Default" should work with PipeWire, but isn't
- Need to investigate why "Default" isn't resolving correctly
- May need to manually select audio device instead of using "Default"
- **Microphone is being accessed even when not recording** - this could be the root cause

