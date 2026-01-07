# DaVinci Resolve Audio Troubleshooting Guide

**Date**: December 21, 2025  
**Issue**: Audio stopped working after DaVinci Resolve update  
**Version**: 20.3.0.0010

---

## System Configuration Status

✅ **System audio configuration is correct**:
- Environment variables set correctly (`XDG_RUNTIME_DIR`, `PIPEWIRE_RUNTIME_DIR`, `PULSE_RUNTIME_PATH`, `PULSE_SERVER`)
- `.asoundrc` configured to route ALSA through PulseAudio
- `alsa-plugins` installed
- `pipewire-pulse` service running
- `ALSA_PLUGIN_DIR` set in `nvidia-offload` wrapper

**Since audio worked before the update, the issue is likely in DaVinci Resolve's internal audio settings.**

---

## DaVinci Resolve Audio Settings Checklist

### 1. **Audio Output Device Selection**

**Location**: `Preferences > System > Video and Audio I/O`

1. Open DaVinci Resolve
2. Go to `DaVinci Resolve > Preferences` (or `Edit > Preferences` on Linux)
3. Navigate to `System > Video and Audio I/O`
4. Check **Audio Output Device**:
   - **If set to "Use System Setting"**: Try switching to **"Manual"** and select your audio device explicitly
   - **If set to "Manual"**: Verify the correct device is selected (not "None")
   - Common device names: `pulse`, `default`, or your specific audio device name

5. **Restart DaVinci Resolve** after changing this setting

---

### 2. **Bus Output Assignments**

**Location**: `Edit` or `Fairlight` tab > `Index` panel

1. Open your project in DaVinci Resolve
2. Go to the **Edit** or **Fairlight** tab
3. Open the **Index** panel (usually on the left side)
4. Select **Tracks** view
5. For each audio track:
   - Check the **Bus Outputs** column
   - Ensure **Bus 1** is assigned to each track
   - If Bus 1 is missing, add it by clicking the bus output dropdown and selecting Bus 1

**Why this matters**: If tracks aren't assigned to Bus 1, audio won't route to the main output.

---

### 3. **Patch Input/Output Settings**

**Location**: `Fairlight` menu > `Patch Input/Output`

1. In DaVinci Resolve, go to the **Fairlight** tab
2. Open the **Fairlight** menu (top menu bar)
3. Select **Patch Input/Output**
4. In the **Output** section:
   - Verify **Bus 1 Left** is patched to your audio output device
   - Verify **Bus 1 Right** is patched to your audio output device
   - If not patched correctly, assign them manually

**Why this matters**: This ensures Bus 1 outputs to your selected audio device.

---

### 4. **Audio Monitoring Settings**

**Location**: `Preferences > System > Video and Audio I/O`

1. In DaVinci Resolve Preferences (`System > Video and Audio I/O`)
2. Check **Audio Monitoring**:
   - Ensure it's **enabled**
   - Verify the **Audio Monitoring Device** is set correctly
   - Check **Audio Sample Rate** matches your system (typically 48000 Hz)

---

### 5. **Timeline Audio Settings**

**Location**: Timeline > Right-click audio track

1. In your timeline, right-click on an audio track
2. Check **Track Output** settings
3. Ensure tracks are outputting to **Bus 1** (or your main output bus)

---

## Common Issues After Updates

### Issue 1: Audio Output Device Reset to "None"

**Symptom**: After update, audio output device is set to "None" or "Use System Setting" doesn't work

**Solution**:
1. Go to `Preferences > System > Video and Audio I/O`
2. Change **Audio Output Device** from "Use System Setting" to **"Manual"**
3. Select your audio device explicitly (try `pulse` or `default` first)
4. Restart DaVinci Resolve

---

### Issue 2: Bus Outputs Not Assigned

**Symptom**: Audio tracks exist but no sound plays

**Solution**:
1. Check `Index > Tracks` panel
2. Ensure all audio tracks have **Bus 1** in their Bus Outputs
3. If missing, add Bus 1 to each track

---

### Issue 3: Patch Settings Changed

**Symptom**: Audio plays but only from one channel or wrong device

**Solution**:
1. Go to `Fairlight > Patch Input/Output`
2. Verify Bus 1 Left and Right are patched correctly
3. Re-patch if necessary

---

## Diagnostic Steps

### Step 1: Verify System Audio Works

```bash
# Test audio in another application
vlc /path/to/video/with/audio.mp4
# Or
pactl list sinks short  # Should show your audio device
```

**If system audio works but DaVinci doesn't**: Issue is in DaVinci Resolve settings.

---

### Step 2: Check DaVinci Resolve Audio Preferences

1. Open DaVinci Resolve
2. `Preferences > System > Video and Audio I/O`
3. Note the current settings:
   - Audio Output Device: [What is it set to?]
   - Audio Monitoring: [Enabled/Disabled?]
   - Audio Sample Rate: [What value?]

---

### Step 3: Check Project Audio Settings

1. In your project, go to `Fairlight` tab
2. Check `Index > Tracks`:
   - Are tracks assigned to Bus 1?
   - Are there any tracks without bus assignments?

---

### Step 4: Test with New Project

1. Create a new test project
2. Import a video file with audio
3. Check if audio plays in the new project
4. If yes: Issue is with your specific project settings
5. If no: Issue is with DaVinci Resolve global settings

---

## Reset DaVinci Resolve Audio Settings

If nothing else works, you can reset DaVinci Resolve's audio configuration:

1. **Close DaVinci Resolve completely**
2. **Backup your configuration**:
   ```bash
   cp -r ~/.local/share/DaVinciResolve ~/.local/share/DaVinciResolve.backup
   ```
3. **Reset audio preferences** (optional - only if needed):
   - Delete or rename: `~/.local/share/DaVinciResolve/configs/`
   - DaVinci Resolve will recreate default configs on next launch
   - **Warning**: This will reset all preferences, not just audio

---

## Version-Specific Notes

### DaVinci Resolve 20.3.0.0010

- This version may have changed how it handles audio device selection
- Some users report that "Use System Setting" no longer works reliably
- **Recommendation**: Use "Manual" audio device selection and explicitly select your device

---

## Next Steps

1. **First**: Check `Preferences > System > Video and Audio I/O` and set Audio Output Device to "Manual" with explicit device selection
2. **Second**: Verify Bus 1 assignments in `Index > Tracks`
3. **Third**: Check Patch Input/Output settings in Fairlight
4. **If still not working**: Check DaVinci Resolve logs for audio-related errors

---

## Related Files

- DaVinci Resolve configs: `~/.local/share/DaVinciResolve/configs/`
- DaVinci Resolve logs: `~/.local/share/BlackmagicDesign/DaVinci Resolve/logs/`
- System audio config: `~/.asoundrc`
- Wrapper script: `/run/current-system/sw/bin/nvidia-offload`

---

## Summary

Since audio worked before the update, this is most likely a **DaVinci Resolve configuration issue**, not a system configuration problem. The most common fixes after updates are:

1. ✅ Set Audio Output Device to "Manual" instead of "Use System Setting"
2. ✅ Verify Bus 1 is assigned to all audio tracks
3. ✅ Check Patch Input/Output settings
4. ✅ Ensure Audio Monitoring is enabled

Our system configuration (PipeWire, ALSA, environment variables) is correct - the issue is in DaVinci Resolve's internal audio routing.

