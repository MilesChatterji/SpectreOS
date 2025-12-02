# Ambient Light Sensor Implementation Plan
## PX13 Auto Brightness Based on Sensor Input

**Date**: 2025-11-29  
**Status**: ✅ **IMPLEMENTED AND WORKING** - May need calibration adjustments after extended testing

---

## Sensor Detection Results

### ✅ Sensor Found

**Device**: HID Ambient Light Sensor (ALS)  
**Location**: `/sys/devices/0020:1022:0001.0009/HID-SENSOR-200041.6.auto/iio:device2/`  
**Device Name**: `als`  
**Interface**: IIO (Industrial I/O)

### Sensor Properties

- **Raw Value Path**: `/sys/devices/0020:1022:0001.0009/HID-SENSOR-200041.6.auto/iio:device2/in_illuminance_raw`
- **Scale Factor**: `0.1` (read from `in_illuminance_scale`)
- **Calculation**: `lux = raw_value * scale`
- **Example**: Raw value `3` = `3 * 0.1 = 0.3 lux` (very dark)

### Additional Sensor Data Available

- `in_illuminance_offset` - Offset value
- `in_illuminance_sampling_frequency` - Update rate
- `in_illuminance_hysteresis` - Hysteresis threshold
- `in_chromaticity_*` - Color temperature data (optional)
- `in_colortemp_*` - Color temperature (optional)

---

## Implementation Options

### Option 1: Direct IIO Interface + Script ⭐ **RECOMMENDED**

**Approach**: Read directly from `/sys/.../iio:device2/in_illuminance_raw` and adjust brightness

**Pros**:
- ✅ No additional daemon needed
- ✅ Direct hardware access (low overhead)
- ✅ Sensor already detected and working
- ✅ Simple implementation

**Cons**:
- ⚠️ Hardware-specific path (but we can detect it dynamically)
- ⚠️ Need to poll sensor (every 2-5 seconds)

**Implementation Steps**:
1. Create script to read sensor and calculate lux
2. Map lux values to brightness percentages
3. Set screen and keyboard brightness
4. Create systemd timer to poll every 2-5 seconds
5. Add smooth transitions to avoid flickering

---

### Option 2: iio-sensor-proxy + D-Bus

**Approach**: Use `iio-sensor-proxy` daemon and query via D-Bus

**Pros**:
- ✅ Standard Linux solution
- ✅ D-Bus interface (easy to query)
- ✅ Event-driven (no polling needed)
- ✅ Already packaged in NixOS

**Cons**:
- ⚠️ Requires installing `iio-sensor-proxy` package
- ⚠️ Additional daemon running
- ⚠️ May need configuration

**Implementation Steps**:
1. Install `iio-sensor-proxy` package
2. Enable `services.iio-sensor-proxy.enable = true;`
3. Create script to query D-Bus for illuminance
4. Map to brightness and adjust
5. Create systemd service or timer

---

## Recommended Implementation (Option 1)

### Phase 1: Sensor Reading Script

**Script**: `auto-brightness-sensor`

```bash
#!/bin/bash
# Auto brightness based on ambient light sensor

# Find sensor device dynamically
SENSOR_BASE="/sys/devices/0020:1022:0001.0009/HID-SENSOR-200041.6.auto/iio:device2"
RAW_FILE="$SENSOR_BASE/in_illuminance_raw"
SCALE_FILE="$SENSOR_BASE/in_illuminance_scale"

# Read sensor values
RAW=$(cat "$RAW_FILE" 2>/dev/null || echo "0")
SCALE=$(cat "$SCALE_FILE" 2>/dev/null || echo "0.1")

# Calculate lux
LUX=$(echo "$RAW * $SCALE" | bc -l)

# Map lux to brightness (adjust these thresholds based on testing)
if (( $(echo "$LUX < 1" | bc -l) )); then
  BRIGHTNESS=20   # Very dark (0-1 lux)
elif (( $(echo "$LUX < 10" | bc -l) )); then
  BRIGHTNESS=35   # Dark (1-10 lux)
elif (( $(echo "$LUX < 50" | bc -l) )); then
  BRIGHTNESS=50   # Dim (10-50 lux)
elif (( $(echo "$LUX < 200" | bc -l) )); then
  BRIGHTNESS=70   # Normal (50-200 lux)
elif (( $(echo "$LUX < 500" | bc -l) )); then
  BRIGHTNESS=85   # Bright (200-500 lux)
else
  BRIGHTNESS=100  # Very bright (500+ lux)
fi

# Set screen brightness
brightnessctl --class=backlight set "$BRIGHTNESS%"

# Set keyboard backlight proportionally (0-3 levels)
KBD_BRIGHTNESS=$((BRIGHTNESS / 33))
KBD_BRIGHTNESS=$((KBD_BRIGHTNESS > 3 ? 3 : KBD_BRIGHTNESS))
brightnessctl --class=leds --device=asus::kbd_backlight set "$KBD_BRIGHTNESS"
```

### Phase 2: NixOS Configuration

**Add to `niri.nix`**:

```nix
# Auto brightness script
auto-brightness-sensor = pkgs.writeScriptBin "auto-brightness-sensor" ''
  #!${pkgs.bash}/bin/bash
  # Auto brightness based on ambient light sensor
  
  # Find sensor device dynamically
  SENSOR_BASE="/sys/devices/0020:1022:0001.0009/HID-SENSOR-200041.6.auto/iio:device2"
  RAW_FILE="$SENSOR_BASE/in_illuminance_raw"
  SCALE_FILE="$SENSOR_BASE/in_illuminance_scale"
  
  # Read sensor values
  RAW=$(cat "$RAW_FILE" 2>/dev/null || echo "0")
  SCALE=$(cat "$SCALE_FILE" 2>/dev/null || echo "0.1")
  
  # Calculate lux
  LUX=$(echo "$RAW * $SCALE" | ${pkgs.bc}/bin/bc -l)
  
  # Map lux to brightness (adjust these thresholds based on testing)
  if (( $(echo "$LUX < 1" | ${pkgs.bc}/bin/bc -l) )); then
    BRIGHTNESS=20   # Very dark (0-1 lux)
  elif (( $(echo "$LUX < 10" | ${pkgs.bc}/bin/bc -l) )); then
    BRIGHTNESS=35   # Dark (1-10 lux)
  elif (( $(echo "$LUX < 50" | ${pkgs.bc}/bin/bc -l) )); then
    BRIGHTNESS=50   # Dim (10-50 lux)
  elif (( $(echo "$LUX < 200" | ${pkgs.bc}/bin/bc -l) )); then
    BRIGHTNESS=70   # Normal (50-200 lux)
  elif (( $(echo "$LUX < 500" | ${pkgs.bc}/bin/bc -l) )); then
    BRIGHTNESS=85   # Bright (200-500 lux)
  else
    BRIGHTNESS=100  # Very bright (500+ lux)
  fi
  
  # Set screen brightness
  ${pkgs.brightnessctl}/bin/brightnessctl --class=backlight set "$BRIGHTNESS%"
  
  # Set keyboard backlight proportionally (0-3 levels)
  KBD_BRIGHTNESS=$((BRIGHTNESS / 33))
  KBD_BRIGHTNESS=$((KBD_BRIGHTNESS > 3 ? 3 : KBD_BRIGHTNESS))
  ${pkgs.brightnessctl}/bin/brightnessctl --class=leds --device=asus::kbd_backlight set "$KBD_BRIGHTNESS"
'';

# Systemd timer to poll sensor every 3 seconds
systemd.user.timers.auto-brightness-sensor = {
  description = "Auto brightness sensor timer";
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnActiveSec = "3s";      # Run immediately
    OnUnitActiveSec = "3s";  # Then every 3 seconds
    AccuracySec = "1s";
  };
};

systemd.user.services.auto-brightness-sensor = {
  description = "Auto brightness based on ambient light sensor";
  serviceConfig = {
    ExecStart = "${auto-brightness-sensor}/bin/auto-brightness-sensor";
    Type = "oneshot";
  };
};
```

### Phase 3: Calibration

**Calibration Script** (for testing):

```bash
#!/bin/bash
# Calibration helper - test sensor values and brightness levels

echo "Testing ambient light sensor..."
echo "Move between dark and bright areas"
echo "Press Ctrl+C when done"

SENSOR_BASE="/sys/devices/0020:1022:0001.0009/HID-SENSOR-200041.6.auto/iio:device2"
RAW_FILE="$SENSOR_BASE/in_illuminance_raw"
SCALE_FILE="$SENSOR_BASE/in_illuminance_scale"

while true; do
  RAW=$(cat "$RAW_FILE" 2>/dev/null || echo "0")
  SCALE=$(cat "$SCALE_FILE" 2>/dev/null || echo "0.1")
  LUX=$(echo "$RAW * $SCALE" | bc -l)
  
  CURRENT=$(brightnessctl --class=backlight get)
  MAX=$(brightnessctl --class=backlight max)
  PERCENT=$((CURRENT * 100 / MAX))
  
  echo "Raw: $RAW | Scale: $SCALE | Lux: $LUX | Brightness: $PERCENT%"
  sleep 1
done
```

---

## Integration with Existing Features

### Power Saving Features

**Current Behavior**:
- Auto-dim to 10% after 3 minutes
- Auto-lock after 5 minutes
- Auto-suspend after 15 minutes

**With Auto Brightness**:
- Auto brightness should **pause** when screen is dimmed by power saving
- Auto brightness should **resume** when user input is detected
- Need to coordinate between `swayidle` and `auto-brightness-sensor`

**Solution**: Add a flag file to disable auto brightness during power saving dim:
```bash
# In swayidle-start: Create flag file when dimming
timeout 180 '... && touch /tmp/auto-brightness-disabled'

# In auto-brightness-sensor: Check flag file
if [ -f /tmp/auto-brightness-disabled ]; then
  exit 0  # Skip adjustment
fi

# In swayidle resume: Remove flag file
resume '... && rm -f /tmp/auto-brightness-disabled'
```

### Manual Brightness Override

**Issue**: User manually adjusts brightness, but auto brightness keeps overriding

**Solution**: Track last manual adjustment time, disable auto brightness for 30 seconds after manual change:
```bash
# When user manually changes brightness, touch a timestamp file
# Auto brightness script checks if file is newer than 30 seconds
if [ -f ~/.cache/manual-brightness-time ]; then
  MANUAL_TIME=$(stat -c %Y ~/.cache/manual-brightness-time)
  NOW=$(date +%s)
  if [ $((NOW - MANUAL_TIME)) -lt 30 ]; then
    exit 0  # Skip auto adjustment
  fi
fi
```

---

## Testing Checklist

### Sensor Detection
- [x] Sensor found and accessible
- [x] Can read raw values
- [x] Scale factor known
- [ ] Test in different lighting conditions
- [ ] Verify sensor update frequency

### Brightness Adjustment
- [ ] Test screen brightness adjustment
- [ ] Test keyboard backlight adjustment
- [ ] Verify smooth transitions (no flickering)
- [ ] Test calibration curves
- [ ] Verify manual override still works

### Integration
- [ ] Test with power saving features (auto-dim)
- [ ] Verify no conflicts with manual brightness
- [ ] Test on resume from suspend
- [ ] Verify settings persist

---

## Configuration Options

### Brightness Mapping (Lux → Brightness %)

**Default Thresholds** (adjustable):
- Very dark (0-1 lux): 20%
- Dark (1-10 lux): 35%
- Dim (10-50 lux): 50%
- Normal (50-200 lux): 70%
- Bright (200-500 lux): 85%
- Very bright (500+ lux): 100%

### Polling Interval

**Default**: 3 seconds  
**Options**: 1-10 seconds (shorter = more responsive, more CPU)

### Keyboard Backlight Mapping

**Default**: Proportional to screen brightness (0-100% → 0-3 levels)  
**Options**: 
- Proportional (current)
- Independent thresholds
- Always off in bright light
- Always on in dark

---

## Dependencies

### Required Packages
- `brightnessctl` - Already installed ✅
- `bc` - For floating point calculations (needs to be added)
- `bash` - Already available ✅

### Optional Packages
- `iio-sensor-proxy` - Only if using Option 2 (D-Bus approach)

---

## Next Steps

1. ✅ **Sensor Detection** - Complete
2. ⏭️ **Implement Script** - Create auto-brightness-sensor script
3. ⏭️ **Add to niri.nix** - Configure systemd timer/service
4. ⏭️ **Test Calibration** - Adjust brightness mapping thresholds
5. ⏭️ **Integrate with Power Saving** - Coordinate with swayidle
6. ⏭️ **Add Manual Override** - Prevent auto adjustment after manual change
7. ⏭️ **Fine-tune** - Adjust polling interval and thresholds

---

## Sensor Path Reference

**Current Path**: `/sys/devices/0020:1022:0001.0009/HID-SENSOR-200041.6.auto/iio:device2/`

**Key Files**:
- `in_illuminance_raw` - Raw sensor reading
- `in_illuminance_scale` - Scale factor (0.1)
- `in_illuminance_offset` - Offset value
- `name` - Device name ("als")

**Note**: Path may change after reboot. Consider dynamic detection:
```bash
# Find sensor dynamically
SENSOR_PATH=$(find /sys/devices -path "*/HID-SENSOR-*/iio:device*/name" -exec grep -l "als" {} \; 2>/dev/null | head -1 | xargs dirname)
```

---

---

## Implementation Status

**✅ COMPLETED**: 2025-11-29

### What Was Implemented

- ✅ Direct IIO interface script (`auto-brightness-sensor`)
- ✅ Systemd timer (polls every 3 seconds)
- ✅ Manual override protection (30-second cooldown)
- ✅ Power saving integration (pauses when screen dimmed)
- ✅ Screen brightness auto-adjustment (20% dark → 100% bright)
- ✅ Keyboard backlight auto-adjustment (inverted logic: bright screen = dim keyboard, dim screen = bright keyboard)

### Current Brightness Mapping (Screen)

| Light Condition | Lux Range | Screen Brightness |
|----------------|-----------|-------------------|
| Very dark      | 0-1       | 20%               |
| Dark           | 1-10      | 35%               |
| Dim            | 10-50     | 50%               |
| Normal         | 50-200    | 70%               |
| Bright         | 200-500   | 85%               |
| Very bright    | 500+      | 100%              |

### Keyboard Backlight Mapping

- **Status**: ✅ **CALIBRATED AND COMPLETE** (2025-11-29)
- **Logic**: Inverted (opposite of screen brightness)
- **Dark conditions** (screen 20-50%): Keyboard = Level 1 (bright)
- **Normal/Bright conditions** (screen 70-100%): Keyboard = Level 0 (off)
- **User preference**: Level 1 for dark conditions, never use brightest settings

| Light Condition | Screen Brightness | Keyboard Backlight |
|----------------|-------------------|-------------------|
| Very dark      | 20%               | Level 1 (bright)  |
| Dark           | 35%               | Level 1 (bright)  |
| Dim            | 50%               | Level 1 (bright)  |
| Normal         | 70%               | Level 0 (off)      |
| Bright         | 85%               | Level 0 (off)      |
| Very bright    | 100%              | Level 0 (off)      |

### Calibration Complete

✅ Keyboard brightness calibration completed and working as expected with inverted logic.

---

**Last Updated**: 2025-11-29  
**Status**: ✅ Implemented and Working - Monitoring for calibration adjustments

