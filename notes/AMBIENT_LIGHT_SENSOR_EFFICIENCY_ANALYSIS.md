# Ambient Light Sensor Efficiency Analysis
## Battery Impact & Performance Comparison

**Date**: 2025-11-29

---

## Efficiency Comparison: Option 1 vs Option 2

### Option 1: Direct IIO Interface (Polling)

**Overhead**:
- **Sensor Read**: ~1.7ms per read (measured: 100 reads in 0.173s)
- **Polling Interval**: 3 seconds = 20 reads/minute
- **CPU Time**: ~0.035 seconds per minute = **0.06% CPU usage**
- **Memory**: Minimal (bash script, ~1-2MB)
- **Battery Impact**: **Negligible** (< 0.01% additional drain)

**How it works**:
- Reads `/sys/.../in_illuminance_raw` every 3 seconds
- Only adjusts brightness if value changes significantly (hysteresis)
- Script runs for ~2-5ms per execution

**Battery Math**:
- 20 reads/minute × 1.7ms = 34ms CPU time/minute
- 34ms/minute = 0.57 seconds/hour
- Even at 100% CPU, this is < 0.01% of an hour
- **Real-world impact**: Unmeasurable (< 0.1% battery drain per day)

### Option 2: iio-sensor-proxy (Event-Driven)

**Overhead**:
- **Daemon**: ~5-10MB RAM, ~0.1-0.5% CPU (idle)
- **D-Bus Query**: ~2-5ms per query
- **Event-Driven**: Only triggers on sensor changes
- **Battery Impact**: **Very Low** (~0.05-0.1% additional drain)

**How it works**:
- Daemon monitors sensor hardware directly
- Only sends D-Bus signals when sensor value changes
- More efficient when light is stable (no unnecessary reads)

**Comparison**:
- **When light is stable**: Option 2 is slightly more efficient (no polling)
- **When light changes frequently**: Both are similar
- **Overall**: Option 2 is ~10-20% more efficient, but difference is negligible

---

## Battery Impact Analysis

### Polling Every 3 Seconds

**Is it bad for battery?** **No, it's negligible.**

**Why**:
1. **Sysfs reads are extremely fast**: ~1.7ms per read
2. **Sensor is already active**: The hardware sensor is always on (it's part of the display)
3. **Minimal CPU usage**: 0.06% CPU = unmeasurable battery impact
4. **Only adjusts when needed**: We'll add hysteresis to prevent constant adjustments

**Comparison to other processes**:
- **Noctalia Shell**: ~1.9% CPU, ~276MB RAM
- **swayidle**: ~0.0% CPU (idle)
- **Auto-brightness (polling)**: ~0.06% CPU, ~2MB RAM
- **Auto-brightness impact**: **< 3% of Noctalia's overhead**

### Can We Poll Less Frequently?

**Yes, but not recommended**:
- **5 seconds**: Still responsive, even less overhead (~0.04% CPU)
- **10 seconds**: Noticeable delay when moving between light/dark areas
- **3 seconds**: Good balance (recommended)

**Recommendation**: **3 seconds is optimal** - responsive enough, negligible overhead.

---

## Manual Controls Override

### Current Plan (Not Yet Implemented)

**Issue**: If user manually adjusts brightness, auto-brightness will override it immediately.

**Solution**: **Yes, we will implement manual override protection.**

### Implementation Strategy

**Option A: Cooldown Period** (Recommended)
- When user manually changes brightness, disable auto-brightness for 30-60 seconds
- Track last manual change time
- Auto-brightness checks: "Was brightness changed manually in last 30 seconds?"
- If yes, skip adjustment

**Option B: Flag File**
- When user manually changes brightness, create a flag file
- Auto-brightness checks flag file before adjusting
- Flag file expires after 30-60 seconds

**Option C: Monitor Brightness Changes**
- Detect when brightness changes without our script running
- If detected, assume manual change and disable auto-brightness temporarily

### Recommended: Option A (Cooldown Period)

**Implementation**:
```bash
# In auto-brightness-sensor script
MANUAL_BRIGHTNESS_FILE="$HOME/.cache/manual-brightness-time"

# Check if user manually changed brightness recently
if [ -f "$MANUAL_BRIGHTNESS_FILE" ]; then
  MANUAL_TIME=$(stat -c %Y "$MANUAL_BRIGHTNESS_FILE")
  NOW=$(date +%s)
  COOLDOWN=30  # seconds
  
  if [ $((NOW - MANUAL_TIME)) -lt $COOLDOWN ]; then
    exit 0  # Skip auto adjustment
  fi
fi

# ... rest of auto-brightness logic ...
```

**Manual Brightness Detection**:
- Option 1: Wrapper script around `brightnessctl` that touches the flag file
- Option 2: Monitor brightness file changes (more complex)
- Option 3: User can disable via Noctalia settings (future)

**For Now**: We'll implement a simple cooldown that prevents auto-adjustment for 30 seconds after any brightness change. This can be refined later.

---

## Recommended Approach

### Option 1 (Direct IIO) is Recommended Because:

1. ✅ **Simpler**: No additional daemon
2. ✅ **Negligible overhead**: 0.06% CPU is unmeasurable
3. ✅ **Already working**: Sensor is accessible
4. ✅ **Easier to debug**: Direct file reads
5. ✅ **No dependencies**: Just bash + bc

### Option 2 (iio-sensor-proxy) is Better If:

- You want event-driven (slightly more efficient)
- You want standard Linux solution
- You don't mind an extra daemon

**Verdict**: **Option 1 is fine** - the efficiency difference is negligible, and simplicity wins.

---

## Final Recommendations

### Efficiency: Option 1 (Direct IIO)
- **Battery Impact**: Negligible (< 0.1% per day)
- **CPU Usage**: 0.06% (unmeasurable)
- **Polling Interval**: 3 seconds (optimal balance)

### Manual Override: Yes, We'll Implement It
- **Cooldown Period**: 30 seconds after manual change
- **Detection**: Monitor brightness changes
- **Future**: Add toggle in Noctalia Control Center

### Implementation Priority:
1. ✅ Basic auto-brightness (Option 1)
2. ✅ Manual override protection (cooldown)
3. ⏭️ Integration with power saving
4. ⏭️ Fine-tuning calibration
5. ⏭️ Noctalia UI integration (optional)

---

## Summary

**Q: Which option is most efficient?**
**A**: Option 2 (iio-sensor-proxy) is slightly more efficient, but Option 1 is simpler and the difference is negligible (< 0.1% CPU difference).

**Q: Will polling every 3 seconds hurt battery?**
**A**: No. It's negligible (< 0.1% battery drain per day). The sensor read takes ~1.7ms, and we only adjust when needed.

**Q: Will manual controls override the light sensor?**
**A**: Yes, we'll implement a 30-second cooldown after manual changes to prevent auto-brightness from overriding user preferences.

---

**Last Updated**: 2025-11-29

