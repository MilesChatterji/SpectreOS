# Noctalia Shell Integration TODOs
## Power Saving, Auto Brightness, and Keyboard Backlight UI Integration

**Date**: Current  
**Status**: Backend Complete - UI Integration Pending

---

## Current Status

### ✅ Backend Implementation Complete

1. **Power Saving Features** (`niri.nix` lines 287-294, 683-711)
   - ✅ `swayidle` service configured and running
   - ✅ Auto-dim screen after 3 minutes of inactivity
   - ✅ Auto-lock screen after 5 minutes (via Noctalia Shell IPC)
   - ✅ Auto-suspend after 15 minutes
   - ✅ Brightness save/restore on dim/resume
   - ✅ Keyboard backlight save/restore on dim/resume
   - ✅ Integration with auto-brightness (pauses during power saving)

2. **Auto Brightness** (`niri.nix` lines 46-154, 652-674)
   - ✅ Ambient light sensor integration
   - ✅ Dynamic sensor discovery (handles device number changes)
   - ✅ Lux-to-brightness mapping with hysteresis
   - ✅ Manual override detection (30-second cooldown)
   - ✅ Keyboard backlight integration (inverted: dark = keyboard on, bright = keyboard off)
   - ✅ Power saving integration (pauses when screen is dimmed)

3. **Keyboard Backlight Control** (`niri.nix`)
   - ✅ Keybind controls (XF86KbdBrightnessUp/Down, Mod+Shift+B)
   - ✅ Integrated into auto-brightness script
   - ✅ Save/restore during power saving dimming

### ❌ Missing: Noctalia Shell UI Integration

**Current Limitation**: All features work via backend services, but there's **no GUI control** in Noctalia Shell Control Center.

---

## TODO: Noctalia Shell Control Center Widgets

### Priority 1: Power Management Widget

**Goal**: Add a Control Center card for power saving settings

**Features to Implement**:
- [ ] **Enable/Disable Toggle**: Turn power saving on/off
- [ ] **Screen Dim Timeout Slider**: Adjust timeout (default: 3 minutes / 180 seconds)
- [ ] **Screen Lock Timeout Slider**: Adjust timeout (default: 5 minutes / 300 seconds)
- [ ] **Suspend Timeout Slider**: Adjust timeout (default: 15 minutes / 900 seconds)
- [ ] **Dim Brightness Level Slider**: Adjust dim brightness (default: 10%)
- [ ] **Status Indicator**: Show current power saving state (active/idle/dimmed/locked)
- [ ] **Settings Persistence**: Save to `~/.config/noctalia/gui-settings.json`

**Backend Integration**:
- Manage `swayidle` process (start/stop/restart with new settings)
- Read/write settings from `gui-settings.json`
- Communicate with systemd for suspend operations
- Monitor brightness state for status indicator

**Implementation Location**:
- Widget: `Modules/Bar/Widgets/PowerManagement.qml`
- Service: `Services/System/PowerManagementService.qml`
- Settings Schema: Add to `gui-settings.json` structure

---

### Priority 2: Auto Brightness Widget

**Goal**: Add a Control Center card for auto brightness settings

**Features to Implement**:
- [ ] **Enable/Disable Toggle**: Turn auto brightness on/off
- [ ] **Current Lux Reading Display**: Show real-time ambient light sensor reading
- [ ] **Brightness Mapping Presets**: 
   - Very Dark (0-1 lux) → 20%
   - Dark (1-10 lux) → 35%
   - Dim (10-50 lux) → 50%
   - Normal (50-200 lux) → 70%
   - Bright (200-500 lux) → 85%
   - Very Bright (500+ lux) → 100%
- [ ] **Manual Override Indicator**: Show when manual brightness is active (30s cooldown)
- [ ] **Hysteresis Threshold Slider**: Adjust sensitivity (default: 5%)
- [ ] **Settings Persistence**: Save to `~/.config/noctalia/gui-settings.json`

**Backend Integration**:
- Control `auto-brightness-sensor` timer service (enable/disable)
- Read sensor values for display
- Update brightness mapping thresholds
- Monitor manual override state

**Implementation Location**:
- Widget: `Modules/Bar/Widgets/AutoBrightness.qml`
- Service: `Services/System/AutoBrightnessService.qml`
- Settings Schema: Add to `gui-settings.json` structure

---

### Priority 3: Keyboard Backlight Widget

**Goal**: Add a Control Center card for keyboard backlight settings

**Features to Implement**:
- [ ] **Toggle Switch**: Turn keyboard backlight on/off
- [ ] **Brightness Slider**: Adjust brightness level (0-3 levels, or 0-100%)
- [ ] **Auto Mode Toggle**: Enable/disable automatic control via auto-brightness
- [ ] **Timeout Settings**: 
   - Always on
   - Turn off after 10s/30s/1min/5min of inactivity
- [ ] **Status Indicator**: Show current state (on/off/auto)
- [ ] **Settings Persistence**: Save to `~/.config/noctalia/gui-settings.json`

**Backend Integration**:
- Control keyboard backlight via `brightnessctl --class=leds --device=asus::kbd_backlight`
- Integrate with `swayidle` for timeout functionality
- Coordinate with auto-brightness service for auto mode
- Monitor current brightness level

**Implementation Location**:
- Widget: `Modules/Bar/Widgets/KeyboardBacklight.qml`
- Service: `Services/System/KeyboardBacklightService.qml`
- Settings Schema: Add to `gui-settings.json` structure

---

## Implementation Approach

### Option A: Fork and Contribute (Recommended)

**Steps**:
1. Fork `noctalia-dev/noctalia-shell` on GitHub
2. Clone locally
3. Create widgets and services (see structure above)
4. Test thoroughly
5. Submit PR to upstream

**Benefits**:
- Contributes to open source project
- Upstream maintenance
- Community feedback

**Time Estimate**: 4-8 hours

---

### Option B: Local Fork (Quick Implementation)

**Steps**:
1. Fork `noctalia-dev/noctalia-shell` on GitHub
2. Clone locally
3. Create widgets and services
4. Build custom package in `niri.nix` (point to fork)
5. Use locally without upstream PR

**Benefits**:
- Faster iteration
- No PR process
- Full control

**Time Estimate**: 4-8 hours (same development, no PR overhead)

---

## Technical Details

### Noctalia Shell Structure

Based on package analysis:
- **Settings File**: `~/.config/noctalia/gui-settings.json`
- **Widgets Location**: `Modules/Bar/Widgets/`
- **Services Location**: `Services/System/`
- **Control Center**: Card-based UI system
- **IPC**: Uses Quickshell IPC for system calls

### Settings File Schema

**Proposed Structure**:
```json
{
  "powerManagement": {
    "enabled": true,
    "dimTimeout": 180,
    "lockTimeout": 300,
    "suspendTimeout": 900,
    "dimBrightness": 10
  },
  "autoBrightness": {
    "enabled": true,
    "hysteresis": 5,
    "mapping": {
      "veryDark": { "maxLux": 1, "brightness": 20 },
      "dark": { "maxLux": 10, "brightness": 35 },
      "dim": { "maxLux": 50, "brightness": 50 },
      "normal": { "maxLux": 200, "brightness": 70 },
      "bright": { "maxLux": 500, "brightness": 85 },
      "veryBright": { "maxLux": 999999, "brightness": 100 }
    }
  },
  "keyboardBacklight": {
    "enabled": true,
    "brightness": 1,
    "autoMode": true,
    "timeout": 0,
    "autoOff": false
  }
}
```

### Backend Service Integration

**Power Management Service**:
- Start/stop/restart `swayidle` with updated config
- Read settings from `gui-settings.json`
- Write settings to `gui-settings.json`
- Monitor systemd service status

**Auto Brightness Service**:
- Enable/disable `auto-brightness-sensor` timer
- Read sensor values from `/sys/devices/.../in_illuminance_raw`
- Update brightness mapping
- Monitor manual override state

**Keyboard Backlight Service**:
- Control via `brightnessctl` commands
- Integrate with `swayidle` for timeout
- Coordinate with auto-brightness for auto mode
- Read current state

### QML Widget Structure (Estimated)

```qml
// PowerManagement.qml
Item {
  // Card container
  // Toggle switch for enable/disable
  // Timeout sliders
  // Brightness level selector
  // Status indicator
  // Connect to PowerManagementService
}

// PowerManagementService.qml
QtObject {
  property bool enabled: false
  property int dimTimeout: 180
  property int lockTimeout: 300
  property int suspendTimeout: 900
  property int dimBrightness: 10
  
  function startIdleDaemon() {
    // Launch swayidle with current settings
  }
  
  function stopIdleDaemon() {
    // Stop swayidle process
  }
  
  function updateSettings() {
    // Write to gui-settings.json
  }
}
```

---

## Testing Checklist

### Power Management Widget
- [ ] Widget appears in Control Center
- [ ] Enable/disable toggle works
- [ ] Timeout sliders update `swayidle` configuration
- [ ] Settings persist after restart
- [ ] Status indicator shows correct state
- [ ] No conflicts with existing brightness controls

### Auto Brightness Widget
- [ ] Widget appears in Control Center
- [ ] Enable/disable toggle works
- [ ] Lux reading updates in real-time
- [ ] Brightness mapping presets work
- [ ] Manual override indicator shows correctly
- [ ] Settings persist after restart
- [ ] No conflicts with power saving dimming

### Keyboard Backlight Widget
- [ ] Widget appears in Control Center
- [ ] Toggle switch works
- [ ] Brightness slider works
- [ ] Auto mode coordinates with auto-brightness
- [ ] Timeout settings work
- [ ] Settings persist after restart
- [ ] No conflicts with keybind controls

---

## Dependencies

### Required Packages (Already Installed)
- ✅ `swayidle` - Wayland idle daemon
- ✅ `brightnessctl` - Brightness and keyboard backlight control
- ✅ `bc` - Floating point calculations (for auto-brightness)
- ✅ `systemd` - Service management

### Development Dependencies (For Widget Development)
- Qt6 development tools
- QML knowledge
- Noctalia Shell source code
- Git (for forking/cloning)

---

## Next Steps

1. ⏭️ **Decide on approach**: Fork and contribute vs. local fork
2. ⏭️ **Fork Noctalia Shell**: Clone repository locally
3. ⏭️ **Start with Power Management Widget**: Implement basic widget and service
4. ⏭️ **Test thoroughly**: Ensure backend integration works
5. ⏭️ **Add Auto Brightness Widget**: Implement second widget
6. ⏭️ **Add Keyboard Backlight Widget**: Implement third widget
7. ⏭️ **Update niri.nix**: Point to custom fork if using local approach
8. ⏭️ **Submit PR** (if contributing): Submit to upstream

---

## Notes

- All backend services are already working and tested
- This is purely a UI integration task
- Widgets should follow Noctalia Shell's design patterns
- Settings should integrate with existing `gui-settings.json` structure
- Consider contributing back to upstream for community benefit

---

**Last Updated**: Current  
**Status**: Backend Complete - Ready for UI Development

