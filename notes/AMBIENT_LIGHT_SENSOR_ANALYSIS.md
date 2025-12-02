# Ambient Light Sensor Integration Analysis
## Auto Screen & Keyboard Brightness Based on Sensor Input

**Date**: Current  
**Goal**: Implement automatic brightness adjustment for:
- Screen brightness (based on ambient light)
- Keyboard backlight brightness (based on ambient light)

---

## Sensor Detection

### Common Sensor Locations

**Linux iio (Industrial I/O) Sensors**:
- `/sys/class/iio/device*/illuminance*` - Ambient light sensors
- `/sys/class/iio/device*/in_illuminance*` - Light intensity readings
- `/sys/class/iio/device*/name` - Device names (often "als" or "light")

**Backlight Sensors**:
- Some laptops have light sensors integrated with display backlight
- Check: `/sys/class/backlight/*/actual_brightness` (may have sensor data)

**ACPI Sensors**:
- `/sys/class/acpi/*/` - ACPI-based sensors
- `/proc/acpi/*` - Legacy ACPI interface

**D-Bus Sensors**:
- Some systems expose sensors via D-Bus (upower, iio-sensor-proxy)

### Detection Commands

```bash
# Check for iio sensors
ls -la /sys/class/iio/device*/name
cat /sys/class/iio/device*/name

# Check for illuminance sensors
find /sys/class/iio -name "*illuminance*" -o -name "*light*"

# Check available sensor values
for dev in /sys/class/iio/device*; do
  echo "Device: $(cat $dev/name)"
  ls -la $dev/ | grep -E "(illuminance|light|als)"
done

# Check iio-sensor-proxy (if installed)
dbus-send --session --print-reply \
  --dest=net.hadess.SensorProxy \
  /net/hadess/SensorProxy \
  net.hadess.SensorProxy.GetAccelerometerOrientation

# Check upower for ambient light
upower -d | grep -i "illuminance\|light"
```

---

## Implementation Options

### Option 1: iio-sensor-proxy + Script ⭐ **RECOMMENDED**

**Approach**: Use `iio-sensor-proxy` (standard Linux sensor daemon) + custom script

**Pros**:
- ✅ Standard Linux solution
- ✅ Works with most modern laptops
- ✅ D-Bus interface (easy to query)
- ✅ Already packaged in NixOS

**Cons**:
- ⚠️ Requires `iio-sensor-proxy` package
- ⚠️ May need kernel modules enabled
- ⚠️ Some hardware may not be supported

**Implementation**:
```nix
# Add to niri.nix or new sensors.nix
environment.systemPackages = with pkgs; [
  iio-sensor-proxy  # Sensor daemon
  # Script will be created below
];

# Enable iio-sensor-proxy service
services.iio-sensor-proxy.enable = true;

# Create brightness adjustment script
auto-brightness-script = pkgs.writeScriptBin "auto-brightness" ''
  #!${pkgs.bash}/bin/bash
  # Monitor ambient light sensor and adjust brightness
  
  # Get sensor value from D-Bus
  ILLUMINANCE=$(dbus-send --session --print-reply \
    --dest=net.hadess.SensorProxy \
    /net/hadess/SensorProxy \
    net.hadess.SensorProxy.GetAmbientLight 2>/dev/null | \
    grep -oP 'double \K[0-9.]+' || echo "0")
  
  # Map illuminance (lux) to brightness (0-100%)
  # Adjust these values based on your sensor and preferences
  if (( $(echo "$ILLUMINANCE < 10" | bc -l) )); then
    BRIGHTNESS=20  # Very dark
  elif (( $(echo "$ILLUMINANCE < 50" | bc -l) )); then
    BRIGHTNESS=40  # Dark
  elif (( $(echo "$ILLUMINANCE < 200" | bc -l) )); then
    BRIGHTNESS=60  # Dim
  elif (( $(echo "$ILLUMINANCE < 500" | bc -l) )); then
    BRIGHTNESS=80  # Normal
  else
    BRIGHTNESS=100  # Bright
  fi
  
  # Set screen brightness
  brightnessctl set "$BRIGHTNESS%"
  
  # Set keyboard backlight (optional, based on same sensor)
  # Adjust keyboard brightness proportionally
  KBD_BRIGHTNESS=$((BRIGHTNESS / 33))  # Scale 0-100% to 0-3 levels
  brightnessctl --class=leds --device=asus::kbd_backlight set "$KBD_BRIGHTNESS"
'';

# Systemd user service to monitor sensor
systemd.user.services.auto-brightness = {
  description = "Auto brightness based on ambient light sensor";
  wantedBy = [ "graphical-session.target" ];
  after = [ "graphical-session.target" "iio-sensor-proxy.service" ];
  serviceConfig = {
    ExecStart = "${auto-brightness-script}/bin/auto-brightness";
    Restart = "on-failure";
    RestartSec = 5;
  };
};
```

---

### Option 2: Direct iio Interface + Script

**Approach**: Read directly from `/sys/class/iio/device*/in_illuminance*`

**Pros**:
- ✅ No extra daemon needed
- ✅ Direct hardware access
- ✅ Lower overhead

**Cons**:
- ⚠️ Hardware-specific paths
- ⚠️ Need to detect correct device
- ⚠️ May need root permissions for some sensors

**Implementation**:
```nix
# Script to find and read sensor
auto-brightness-direct = pkgs.writeScriptBin "auto-brightness-direct" ''
  #!${pkgs.bash}/bin/bash
  
  # Find ambient light sensor
  SENSOR_PATH=""
  for dev in /sys/class/iio/device*; do
    if [ -f "$dev/in_illuminance_input" ]; then
      SENSOR_PATH="$dev/in_illuminance_input"
      break
    fi
  done
  
  if [ -z "$SENSOR_PATH" ]; then
    echo "No ambient light sensor found"
    exit 1
  fi
  
  # Read sensor value
  ILLUMINANCE=$(cat "$SENSOR_PATH" 2>/dev/null || echo "0")
  
  # Map to brightness (adjust based on your sensor range)
  # Example: Sensor reads 0-10000 lux, map to 20-100% brightness
  BRIGHTNESS=$((20 + (ILLUMINANCE * 80 / 10000)))
  BRIGHTNESS=$((BRIGHTNESS > 100 ? 100 : BRIGHTNESS))
  
  # Set brightness
  brightnessctl set "$BRIGHTNESS%"
  
  # Set keyboard backlight
  KBD_BRIGHTNESS=$((BRIGHTNESS / 33))
  brightnessctl --class=leds --device=asus::kbd_backlight set "$KBD_BRIGHTNESS"
'';

# Systemd timer to poll sensor every few seconds
systemd.user.timers.auto-brightness = {
  description = "Auto brightness timer";
  wantedBy = [ "timers.target" ];
  timerConfig = {
    OnActiveSec = "5s";  # Run immediately
    OnUnitActiveSec = "5s";  # Then every 5 seconds
  };
};

systemd.user.services.auto-brightness = {
  description = "Auto brightness service";
  serviceConfig = {
    ExecStart = "${auto-brightness-direct}/bin/auto-brightness-direct";
    Type = "oneshot";
  };
};
```

---

### Option 3: Noctalia Shell Integration

**Approach**: Add sensor monitoring to Noctalia Shell Control Center

**Pros**:
- ✅ Integrated UI
- ✅ User can enable/disable
- ✅ Settings in Noctalia config
- ✅ Can contribute upstream

**Cons**:
- ❌ Requires code changes
- ❌ More development time
- ❌ Need to maintain fork or get PR merged

**Implementation** (if contributing):
- Add `AmbientLightSensor.qml` service
- Add brightness adjustment logic
- Add UI toggle in Control Center
- Store settings in `gui-settings.json`

---

## Sensor Calibration

### Brightness Mapping

**Screen Brightness**:
- Need to map sensor lux values to brightness percentage
- Typical ranges:
  - Very dark (0-10 lux): 20-30%
  - Dark (10-50 lux): 30-50%
  - Dim (50-200 lux): 50-70%
  - Normal (200-500 lux): 70-90%
  - Bright (500+ lux): 90-100%

**Keyboard Backlight**:
- Usually 0-3 levels (or 0-100%)
- Can map proportionally to screen brightness
- Or use separate thresholds

### Calibration Script

```bash
#!/bin/bash
# Calibration helper - test sensor values and brightness levels

echo "Testing ambient light sensor..."
echo "Move between dark and bright areas"
echo "Press Ctrl+C when done"

while true; do
  # Read sensor
  ILLUMINANCE=$(cat /sys/class/iio/device0/in_illuminance_input 2>/dev/null || echo "0")
  
  # Current brightness
  CURRENT=$(brightnessctl get)
  MAX=$(brightnessctl max)
  PERCENT=$((CURRENT * 100 / MAX))
  
  echo "Lux: $ILLUMINANCE | Brightness: $PERCENT%"
  sleep 1
done
```

---

## Dependencies

### Required Packages

**For iio-sensor-proxy approach**:
- `iio-sensor-proxy` - Sensor daemon (NixOS package)
- `brightnessctl` - Already installed ✅
- `dbus` - Already available ✅
- `bc` or `awk` - For calculations

**For direct iio approach**:
- `brightnessctl` - Already installed ✅
- Kernel iio modules (usually built-in)

**For Noctalia integration**:
- All of the above, plus:
- Noctalia Shell source code
- Qt6/QML development tools

---

## Testing Checklist

### Sensor Detection
- [ ] Identify available sensors on system
- [ ] Verify sensor readings are accurate
- [ ] Check sensor update frequency
- [ ] Test in different lighting conditions

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

### Noctalia Integration (if contributing)
- [ ] Widget appears in Control Center
- [ ] Toggle enable/disable works
- [ ] Settings persist after restart
- [ ] Calibration values adjustable via UI

---

## Configuration Structure

### For External Solution

**NixOS Configuration**:
```nix
{
  # Enable iio-sensor-proxy
  services.iio-sensor-proxy.enable = true;
  
  # Auto brightness service
  systemd.user.services.auto-brightness = {
    # ... service config
  };
  
  # Optional: Config file for calibration
  auto-brightness-config = pkgs.writeText "auto-brightness-config" ''
    # Brightness mapping (lux -> brightness %)
    VERY_DARK=20    # 0-10 lux
    DARK=40         # 10-50 lux
    DIM=60          # 50-200 lux
    NORMAL=80       # 200-500 lux
    BRIGHT=100      # 500+ lux
    
    # Update interval (seconds)
    POLL_INTERVAL=5
    
    # Enable keyboard backlight auto-adjust
    KEYBOARD_AUTO=true
  '';
}
```

### For Noctalia Integration

**Settings File**: `~/.config/noctalia/gui-settings.json`

```json
{
  "ambientLightSensor": {
    "enabled": true,
    "screenBrightness": {
      "veryDark": 20,
      "dark": 40,
      "dim": 60,
      "normal": 80,
      "bright": 100
    },
    "keyboardBrightness": {
      "enabled": true,
      "proportional": true
    },
    "pollInterval": 5,
    "smoothTransition": true
  }
}
```

---

## Hardware Compatibility

### Known Compatible Hardware

**Laptops with Ambient Light Sensors**:
- Most modern laptops (2015+)
- MacBook (via iio-sensor-proxy)
- ThinkPad series
- Dell XPS series
- ASUS ROG/ZenBook series (may vary by model)

**Your System (ASUS)**:
- Check if your specific model has ambient light sensor
- May be integrated with display or separate sensor
- Check BIOS settings for sensor enable/disable

### Verification

```bash
# Check if sensor exists
ls -la /sys/class/iio/device*/name

# Check sensor readings
cat /sys/class/iio/device*/in_illuminance_input

# Check iio-sensor-proxy status
systemctl --user status iio-sensor-proxy

# Check D-Bus interface
dbus-send --session --print-reply \
  --dest=net.hadess.SensorProxy \
  /net/hadess/SensorProxy \
  net.hadess.SensorProxy.GetAmbientLight
```

---

## Implementation Priority

### Phase 1: Sensor Detection
1. Identify available sensors
2. Test sensor readings
3. Verify sensor accuracy

### Phase 2: Basic Implementation
1. Implement brightness adjustment script
2. Create systemd service/timer
3. Test in different lighting conditions
4. Calibrate brightness mapping

### Phase 3: Refinement
1. Add smooth transitions
2. Add manual override handling
3. Integrate with power saving features
4. Fine-tune calibration

### Phase 4: UI Integration (Optional)
1. Add to Noctalia Control Center
2. Add settings panel
3. Submit PR to upstream

---

## Next Steps

1. ✅ **Detect sensors**: Run detection commands to find available sensors
2. ⏭️ **Choose approach**: iio-sensor-proxy (recommended) or direct iio
3. ⏭️ **Implement script**: Create brightness adjustment logic
4. ⏭️ **Test calibration**: Adjust brightness mapping for your hardware
5. ⏭️ **Integrate**: Add systemd service and test
6. ⏭️ **Optional**: Add Noctalia UI integration

---

**Last Updated**: Current  
**Status**: Analysis Complete - Ready for Sensor Detection


