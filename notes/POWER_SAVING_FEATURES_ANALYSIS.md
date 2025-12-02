# Power Saving Features Analysis
## Auto-Dim Screen & Auto-Suspend Implementation Options

**Date**: Current  
**Goal**: Implement GNOME-like power saving features:
- Auto-dim screen after 3 minutes of inactivity
- Return to set brightness on input (trackpad/keyboard)
- Auto-suspend after 15 minutes of inactivity

---

## Current Power Management Setup

### ✅ Already Configured

1. **power-profiles-daemon** (configuration.nix line 35)
   - Enabled for power profile management
   - Works with both GNOME and Niri
   - Provides power modes (balanced, performance, power-save)

2. **systemd-logind** (configuration.nix lines 38-46)
   - Configured for lid switch suspend
   - Power key handling
   - **Missing**: Idle timeout suspend configuration

3. **Hardware Controls** (niri.nix)
   - `brightnessctl` available for brightness control
   - Keyboard backlight control working (via keybinds)
   - No automatic dimming configured

---

## Implementation Options

### Option 1: External Systemd Service + swayidle ⭐ **RECOMMENDED**

**Approach**: Use `swayidle` (Wayland idle daemon) with systemd service

**Pros**:
- ✅ Works independently of Noctalia Shell
- ✅ No code changes needed
- ✅ Standard Wayland solution (used by Sway, Hyprland, etc.)
- ✅ Can be configured via NixOS
- ✅ Handles input detection automatically
- ✅ Can trigger brightness changes and suspend

**Cons**:
- ⚠️ Requires `swayidle` package (not currently installed)
- ⚠️ No GUI control (would need Noctalia widget for settings)
- ⚠️ Separate from Noctalia Control Center

**Implementation**:
```nix
# Add to niri.nix or new power-management.nix
environment.systemPackages = with pkgs; [
  swayidle  # Wayland idle daemon
];

systemd.user.services.swayidle = {
  description = "swayidle - Wayland idle management daemon";
  wantedBy = [ "graphical-session.target" ];
  after = [ "graphical-session.target" ];
  serviceConfig = {
    ExecStart = ''
      ${pkgs.swayidle}/bin/swayidle -w \
        timeout 180 'brightnessctl set 10%' \
        resume 'brightnessctl set $(cat /tmp/brightness-backup)' \
        timeout 900 'systemctl suspend' \
        before-sleep 'brightnessctl get > /tmp/brightness-backup'
    '';
    Restart = "on-failure";
    PassEnvironment = [ "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" ];
  };
};
```

**Features**:
- `timeout 180`: After 3 minutes, dim to 10%
- `resume`: On input, restore previous brightness
- `timeout 900`: After 15 minutes, suspend
- `before-sleep`: Save current brightness before suspend

**Configuration File Alternative**:
Could also use a config file for easier management:
```nix
# Create swayidle config
swayidle-config = pkgs.writeText "swayidle-config" ''
  timeout 180 'brightnessctl set 10%' \
    resume 'brightnessctl set $(cat /tmp/brightness-backup)'
  timeout 900 'systemctl suspend' \
    before-sleep 'brightnessctl get > /tmp/brightness-backup'
'';

# Then in service:
ExecStart = "${pkgs.swayidle}/bin/swayidle -w -f ${swayidle-config}";
```

---

### Option 2: systemd Timers + Scripts

**Approach**: Use systemd user timers to check idle time and act

**Pros**:
- ✅ Pure systemd solution (no extra packages)
- ✅ Can be configured via NixOS
- ✅ Integrates with systemd-logind

**Cons**:
- ❌ More complex (requires idle detection mechanism)
- ❌ Wayland doesn't have built-in idle detection (need logind or other)
- ❌ Less elegant than swayidle
- ❌ Input detection requires additional tools

**Implementation Complexity**: High - would need to:
1. Use `loginctl` to check session idle time
2. Create systemd timers that check periodically
3. Script brightness changes
4. Handle input detection separately

**Not Recommended** - swayidle is better for Wayland.

---

### Option 3: Add to Noctalia Shell Control Center ⭐ **FOR CONTRIBUTION**

**Approach**: Clone Noctalia Shell repo and add power management widgets

**Pros**:
- ✅ Integrated UI in Control Center
- ✅ User-friendly settings panel
- ✅ Consistent with Noctalia design
- ✅ Could contribute back to upstream
- ✅ Can add keyboard backlight controls too

**Cons**:
- ❌ Requires code changes to Noctalia Shell
- ❌ Need to maintain fork or get PR merged
- ❌ More development time
- ❌ Still needs backend (swayidle or similar)

**Architecture Analysis**:

Based on Noctalia Shell structure (from package.nix):
- **Location**: `~/.config/noctalia/gui-settings.json` (settings file)
- **Widgets**: `Modules/Bar/Widgets/` (QML widgets)
- **Control Center**: Card-based UI system
- **Services**: `Services/System/` (system integration)

**What Would Need to be Added**:

1. **Power Management Widget** (`PowerManagement.qml`)
   - Card in Control Center
   - Settings for:
     - Screen dim timeout (default: 3 minutes)
     - Suspend timeout (default: 15 minutes)
     - Dim brightness level (default: 10%)
     - Enable/disable toggle

2. **Power Management Service** (`PowerManagementService.qml`)
   - Backend service that:
     - Manages swayidle process
     - Reads/writes settings from `gui-settings.json`
     - Handles brightness state
     - Communicates with systemd for suspend

3. **Settings Panel Integration**
   - Add power management section to Settings Panel
   - Allow fine-tuning of timeouts and brightness levels

4. **Keyboard Backlight Widget** (bonus)
   - Toggle on/off
   - Brightness slider
   - Timeout settings (turn off after X seconds of inactivity)

**Implementation Steps** (if contributing):

1. Fork `noctalia-dev/noctalia-shell` on GitHub
2. Clone locally
3. Create new widget: `Modules/Bar/Widgets/PowerManagement.qml`
4. Create service: `Services/System/PowerManagementService.qml`
5. Add settings schema to `gui-settings.json` structure
6. Integrate into Control Center card system
7. Test with swayidle backend
8. Submit PR to upstream

**Code Structure** (estimated):
```qml
// PowerManagement.qml - Widget card
Item {
  // Toggle for enable/disable
  // Timeout sliders
  // Brightness level selector
  // Status indicator
}

// PowerManagementService.qml - Backend
QtObject {
  property bool enabled: false
  property int dimTimeout: 180  // seconds
  property int suspendTimeout: 900  // seconds
  property int dimBrightness: 10  // percent
  
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

## Recommendation: Hybrid Approach

### Phase 1: Quick Implementation (External)
**Use Option 1 (swayidle + systemd)** for immediate functionality:
- ✅ Fast to implement (5-10 minutes)
- ✅ Works immediately
- ✅ No code changes needed
- ✅ Can test and refine timeouts

**Implementation**:
- Add `swayidle` to system packages
- Create systemd user service
- Configure timeouts (3 min dim, 15 min suspend)
- Test and adjust as needed

### Phase 2: UI Integration (Contribution)
**Add Option 3 (Noctalia Control Center)** for better UX:
- Clone Noctalia Shell repo
- Add Power Management widget
- Add Keyboard Backlight widget
- Integrate with swayidle backend
- Submit PR to upstream

**Benefits**:
- Users get GUI control
- Settings persist in Noctalia config
- Consistent with Noctalia design
- Contributes to open source project

---

## Technical Details

### How GNOME Does It

GNOME uses:
1. **gnome-settings-daemon**: Handles screen dimming via D-Bus
2. **systemd-logind**: Handles suspend via `IdleAction` and `IdleActionUSec`
3. **D-Bus communication**: Between components

**GNOME Configuration** (for reference):
```ini
# /etc/systemd/logind.conf
[Login]
IdleAction=suspend
IdleActionUSec=15min
```

**Wayland Equivalent**:
- `swayidle` replaces gnome-settings-daemon for idle detection
- `systemd-logind` still handles suspend (but needs manual trigger)
- No D-Bus needed (direct command execution)

### Input Detection

**swayidle** automatically detects:
- Keyboard input
- Mouse/trackpad movement
- Touch input

When input is detected, `resume` command runs, restoring brightness.

### Brightness Management

**Current Setup**:
- `brightnessctl` is available and working
- Can get current brightness: `brightnessctl get`
- Can set brightness: `brightnessctl set 10%`
- Can save/restore: `brightnessctl get > /tmp/backup && brightnessctl set $(cat /tmp/backup)`

**swayidle Integration**:
```bash
# Save current brightness before dimming
brightnessctl get > /tmp/brightness-backup

# Dim to 10%
brightnessctl set 10%

# On resume, restore saved brightness
brightnessctl set $(cat /tmp/brightness-backup)
```

---

## Keyboard Backlight Control

### Current Status
- ✅ Keyboard backlight control works via keybinds (niri.nix)
- ✅ Uses `brightnessctl --class=leds --device=asus::kbd_backlight`
- ❌ No automatic timeout (always on when enabled)
- ❌ No GUI control in Noctalia

### Adding to Noctalia Control Center

**Widget Features**:
1. **Toggle Switch**: On/Off
2. **Brightness Slider**: 0-3 levels (or 0-100%)
3. **Timeout Settings**: 
   - Always on
   - Turn off after 10s/30s/1min/5min of inactivity
4. **Status Indicator**: Current state

**Backend Implementation**:
- Use `brightnessctl` commands (already available)
- Could use swayidle for timeout: `timeout 30 'brightnessctl --class=leds --device=asus::kbd_backlight set 0'`
- Or implement custom timer in QML service

**Integration**:
- Add as separate card in Control Center
- Or combine with Power Management card
- Settings stored in `gui-settings.json`

---

## Comparison: External vs. Integrated

| Feature | External (swayidle) | Integrated (Noctalia) |
|---------|-------------------|----------------------|
| **Implementation Time** | 10 minutes | 4-8 hours |
| **User Experience** | CLI/config file | GUI in Control Center |
| **Maintenance** | Low (standard tool) | Medium (custom code) |
| **Upstream Contribution** | N/A | Yes (PR to Noctalia) |
| **Settings Persistence** | Systemd service | Noctalia config file |
| **Flexibility** | High (scriptable) | Medium (QML constraints) |
| **Testing** | Easy (command line) | Requires rebuild |

---

## Recommended Implementation Plan

### Step 1: Quick Win (Today)
1. Add `swayidle` to system packages
2. Create systemd user service with basic config
3. Test auto-dim and auto-suspend
4. Adjust timeouts as needed

**Time**: ~15 minutes  
**Result**: Working power management

### Step 2: Refinement (This Week)
1. Create config file for easier management
2. Add brightness backup/restore logic
3. Test edge cases (lid close, manual suspend, etc.)
4. Document in configuration

**Time**: ~30 minutes  
**Result**: Polished external solution

### Step 3: UI Integration (Future - Contribution)
1. Fork Noctalia Shell
2. Design Power Management widget
3. Implement backend service
4. Add Keyboard Backlight widget
5. Test and submit PR

**Time**: 4-8 hours  
**Result**: Upstream contribution + better UX

---

## Configuration File Structure

### For External Solution (swayidle)

**Location**: Could be in NixOS config or separate file

**Structure**:
```nix
# In niri.nix or power-management.nix
swayidle-config = pkgs.writeText "swayidle-config" ''
  # Screen dimming: 3 minutes
  timeout 180 'brightnessctl get > /tmp/brightness-backup && brightnessctl set 10%' \
    resume 'brightnessctl set $(cat /tmp/brightness-backup)'
  
  # Suspend: 15 minutes
  timeout 900 'systemctl suspend' \
    before-sleep 'brightnessctl get > /tmp/brightness-backup'
  
  # Optional: Lock screen before suspend
  # timeout 870 'swaylock'  # 14.5 minutes (30s before suspend)
'';

systemd.user.services.swayidle = {
  # ... service config using swayidle-config
};
```

### For Noctalia Integration

**Settings File**: `~/.config/noctalia/gui-settings.json`

**Structure** (estimated):
```json
{
  "powerManagement": {
    "enabled": true,
    "dimTimeout": 180,
    "suspendTimeout": 900,
    "dimBrightness": 10,
    "lockBeforeSuspend": false
  },
  "keyboardBacklight": {
    "enabled": true,
    "brightness": 3,
    "timeout": 0,
    "autoOff": false
  }
}
```

---

## Dependencies

### Required Packages

**For External Solution**:
- `swayidle` - Wayland idle daemon (not currently installed)
- `brightnessctl` - Already installed ✅
- `systemd` - Already available ✅

**For Noctalia Integration**:
- All of the above, plus:
- Noctalia Shell source code
- Qt6 development tools (for building)
- QML knowledge

---

## Testing Checklist

### External Solution (swayidle)
- [ ] Install swayidle
- [ ] Create systemd service
- [ ] Test screen dimming after 3 minutes
- [ ] Test brightness restore on input
- [ ] Test suspend after 15 minutes
- [ ] Test brightness restore after suspend
- [ ] Test with lid close (should suspend immediately)
- [ ] Test manual suspend (should work normally)

### Noctalia Integration
- [ ] Widget appears in Control Center
- [ ] Settings persist after restart
- [ ] Timeout changes take effect immediately
- [ ] Toggle enable/disable works
- [ ] Keyboard backlight widget works
- [ ] No conflicts with existing brightness controls

---

## Conclusion

**Best Approach**: **Hybrid - Start External, Add UI Later**

1. **Immediate**: Implement swayidle + systemd service (15 min)
   - Gets power management working today
   - No code changes needed
   - Easy to test and adjust

2. **Future**: Add Noctalia Control Center widgets (contribution)
   - Better user experience
   - Contributes to open source
   - Makes settings accessible via GUI

**Recommendation**: Start with Option 1 (external), then consider Option 3 (contribution) when you have time for a proper implementation and PR.

---

## Next Steps

1. ✅ Review this analysis
2. ⏭️ Decide: External only, or External + Contribution
3. ⏭️ If external: Implement swayidle service
4. ⏭️ If contribution: Fork Noctalia Shell and start widget development
5. ⏭️ Test thoroughly
6. ⏭️ Document final configuration

---

**Last Updated**: Current  
**Status**: Analysis Complete - Ready for Implementation Decision


