# DaVinci Resolve Audio Conflict - Solution

**Date**: December 21, 2025  
**Issue**: DaVinci Resolve causes PipeWire audio quality degradation that persists even after DaVinci closes  
**Solution**: Restart PipeWire after DaVinci Resolve closes

---

## Problem Summary

1. **When DaVinci Resolve opens**: Audio quality in other applications (Spotify, VLC) degrades
2. **When DaVinci Resolve closes**: Audio quality remains degraded
3. **After PipeWire restart**: Audio quality returns to normal

This indicates DaVinci Resolve is **changing PipeWire's internal state** (likely sample rate or format), and this degraded state persists until PipeWire is restarted.

---

## Root Cause

DaVinci Resolve is likely:
- Opening audio streams with a different sample rate/format than PipeWire's default
- Causing PipeWire to resample all audio, degrading quality
- Leaving PipeWire in this degraded state even after DaVinci closes

---

## Immediate Solution

**Manual Fix** (when audio quality degrades):
```bash
systemctl --user restart pipewire pipewire-pulse
```

This restores normal audio quality immediately.

---

## Automatic Solution Options

### Option 1: Script to Restart PipeWire After DaVinci Closes

Create a script that monitors DaVinci Resolve and restarts PipeWire when it closes:

```bash
#!/usr/bin/env bash
# Monitor DaVinci Resolve and restart PipeWire when it closes
# This fixes audio quality degradation caused by DaVinci Resolve

while true; do
    if pgrep -f resolve > /dev/null; then
        # DaVinci Resolve is running - wait for it to close
        while pgrep -f resolve > /dev/null; do
            sleep 2
        done
        # DaVinci Resolve closed - restart PipeWire to fix audio quality
        echo "DaVinci Resolve closed - restarting PipeWire to fix audio quality"
        systemctl --user restart pipewire pipewire-pulse
    else
        # DaVinci Resolve not running - check every 10 seconds
        sleep 10
    fi
done
```

**Pros**: Simple, automatic  
**Cons**: Requires a background process, slight delay after DaVinci closes

---

### Option 2: PipeWire Configuration to Prevent State Changes

Create a PipeWire config that locks the sample rate and prevents applications from changing it:

```ini
# ~/.config/pipewire/pipewire.conf.d/99-lock-sample-rate.conf
context.properties = {
    # Lock sample rate to prevent applications from changing it
    default.clock.rate = 48000
    default.clock.quantum = 1024
    # Don't allow rate changes that cause quality degradation
    default.clock.allowed-rates = [ 48000 ]
}

pulse.properties = {
    # Lock PulseAudio sample rate
    pulse.default.sample-rate = 48000
    # Prevent applications from requesting different rates
    pulse.min.req = 1024
    pulse.default.req = 1024
    pulse.max.req = 1024
}
```

**Pros**: Prevents the issue at the source  
**Cons**: May break applications that require different sample rates

---

### Option 3: DaVinci Resolve Audio Settings

Configure DaVinci Resolve to use the same sample rate as the system:

1. Open DaVinci Resolve
2. Go to `Preferences > System > Video and Audio I/O`
3. Set **Audio Sample Rate** to **48000 Hz** (match system default)
4. Set **Audio Output Device** to **Manual** and select `pulse` or `default`

**Pros**: Fixes the issue at the source (DaVinci side)  
**Cons**: Requires manual configuration, may reset after updates

---

## Recommended Approach

**For now**: Use the manual restart when needed:
```bash
systemctl --user restart pipewire pipewire-pulse
```

**Long-term**: Try Option 3 first (DaVinci Resolve settings). If that doesn't work, implement Option 1 (automatic script) or Option 2 (PipeWire config).

---

## Testing

After implementing any solution:

1. **Open DaVinci Resolve**
2. **Play audio in Spotify** - check quality
3. **Close DaVinci Resolve**
4. **Check Spotify audio quality** - should remain good (no restart needed)
5. **If quality is still degraded**: The solution didn't work, try another option

---

## Notes

- The issue is **DaVinci Resolve-specific** - other applications don't cause this
- The degradation persists because PipeWire maintains its state across application lifecycles
- Restarting PipeWire is safe and doesn't affect other applications (they reconnect automatically)
- This is a known issue with some applications that request non-standard audio formats

---

## Related Files

- `gpu-offload.nix` - Contains `nvidia-offload` wrapper with audio environment variables
- `~/.asoundrc` - ALSA configuration routing to PulseAudio
- `~/.config/home-manager/home.nix` - Home Manager config

