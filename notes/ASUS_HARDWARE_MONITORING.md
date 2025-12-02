# ASUS Hardware Monitoring Tools and Firmware Notes

**Date**: 2025-12-01  
**System**: NixOS 25.11 on ASUS PX13  
**Purpose**: Reference for ASUS-specific hardware monitoring and firmware management

---

## Overview

This document tracks ASUS-specific hardware monitoring capabilities, tools, and firmware requirements for optimal hardware information access.

---

## Current Status

### Firmware Management
- ✅ **fwupd enabled**: `services.fwupd.enable = true;`
- ✅ **All firmware enabled**: `hardware.enableAllFirmware = true;`
- ✅ **fwupd package installed**: Available in systemPackages
- ✅ **Current firmware status**: All devices up to date (checked 2025-12-01)

### Hardware Monitoring
- ✅ **Standard battery info**: Available via `/sys/class/power_supply/BAT0/`
- ✅ **Noctalia Shell**: Supports battery monitoring (v3.3.0+)
- ⚠️ **ASUS-specific tools**: `asus-battery` not currently installed

---

## Noctalia Shell Battery Monitoring

**Version**: Noctalia Shell 3.3.0+ (you're using main branch, which may have newer features)

**Capabilities**:
- Battery charge level monitoring
- Power profile management
- Sleep prevention options
- Battery health metrics (when available)

**Note**: Noctalia Shell can use ASUS-specific tools like `asus-battery` for enhanced battery health monitoring if available.

---

## ASUS-Specific Hardware Monitoring Tools

### asus-battery (ASUS Linux Drivers)

**Purpose**: Provides detailed battery health information for ASUS laptops, including:
- Battery cycle count
- Battery health percentage
- Design capacity vs. current capacity
- Charge/discharge rate
- Temperature monitoring

**Status**: Not currently installed

**Installation** (when needed):
```nix
# Check if available in nixpkgs
# May need to add asus-linux or asusctl package
environment.systemPackages = with pkgs; [
  # asus-battery or asusctl (if available)
];
```

**Alternative**: Check if available via:
- `asus-linux` project (GitHub)
- `asusctl` package (if in nixpkgs)
- Direct compilation from source

### Standard Linux Battery Info

**Location**: `/sys/class/power_supply/BAT0/`

**Available Information**:
```bash
# Current capacity
cat /sys/class/power_supply/BAT0/capacity

# Battery status (Charging/Discharging/Full)
cat /sys/class/power_supply/BAT0/status

# Battery health (if available)
cat /sys/class/power_supply/BAT0/health

# Design capacity
cat /sys/class/power_supply/BAT0/energy_full_design

# Current full capacity
cat /sys/class/power_supply/BAT0/energy_full

# Current capacity
cat /sys/class/power_supply/BAT0/energy_now

# Charge/discharge rate
cat /sys/class/power_supply/BAT0/power_now

# Voltage
cat /sys/class/power_supply/BAT0/voltage_now
```

**Your System**:
- Battery device: `BAT0`
- Current capacity: 100% (as of 2025-12-01)
- Path: `/sys/class/power_supply/BAT0/`

---

## Firmware and Hardware Monitoring Relationship

### Why Firmware Updates Matter

1. **Enhanced Hardware Access**: Newer firmware often exposes more hardware information via ACPI/sysfs
2. **Battery Health Data**: Updated EC (Embedded Controller) firmware may provide better battery health metrics
3. **Sensor Access**: Firmware updates can improve sensor accuracy and availability
4. **Compatibility**: Tools like `asus-battery` may require specific firmware versions to function properly

### Recommended Practice

**Before implementing ASUS-specific monitoring tools:**
1. ✅ Ensure firmware is up to date: `fwupdmgr refresh && fwupdmgr get-updates`
2. ✅ Check if tools are available in nixpkgs or need custom build
3. ✅ Verify hardware compatibility (some tools are model-specific)
4. ✅ Test with standard sysfs interfaces first

---

## Future Integration with Noctalia Shell

### Current Capabilities
- Noctalia Shell can read standard battery information
- Supports power profile management
- Can integrate with ASUS-specific tools if available

### Potential Enhancements
When `asus-battery` or similar tools are available:
- Battery cycle count display
- Health percentage (design vs. current capacity)
- Charge/discharge rate monitoring
- Temperature-based warnings
- Battery wear estimation

### Implementation Notes
- Noctalia Shell uses IPC (Inter-Process Communication) for hardware queries
- Tools need to be available in PATH or explicitly referenced
- May need to add tools to Noctalia Shell's runtime dependencies

---

## Checking for ASUS-Specific Tools

### Available Packages to Check

```bash
# Check if asusctl or asus-linux tools are in nixpkgs
nix search nixpkgs asusctl
nix search nixpkgs asus-linux
nix search nixpkgs asus-battery

# Or check online:
# - https://github.com/asus-linux/asusctl
# - https://github.com/asus-linux/asus-nb-ctrl
```

### Manual Installation (if needed)

If tools aren't in nixpkgs, you may need to:
1. Create a custom Nix derivation (similar to `asus-dialpad-driver`)
2. Build from source
3. Add to `environment.systemPackages`
4. Ensure proper permissions (may need udev rules)

---

## Quick Reference Commands

### Check Firmware Status
```bash
fwupdmgr refresh && fwupdmgr get-updates
fwupdmgr get-devices
```

### Check Battery Info (Standard)
```bash
# Quick status
cat /sys/class/power_supply/BAT0/capacity
cat /sys/class/power_supply/BAT0/status

# Detailed info
cat /sys/class/power_supply/BAT0/uevent

# Health (if available)
cat /sys/class/power_supply/BAT0/health 2>/dev/null || echo "Health info not available"
```

### Check for ASUS Tools
```bash
which asus-battery
which asusctl
asusctl --version 2>/dev/null || echo "Not installed"
```

---

## Notes for Your System

### Current Configuration
- **Firmware**: Up to date, fwupd enabled
- **Battery Monitoring**: Standard sysfs interface available
- **Noctalia Shell**: Can use battery info, may support asus-battery in future
- **ASUS Tools**: Not currently installed, but can be added when needed

### When to Update Firmware
- Before implementing new hardware monitoring features
- When ASUS releases firmware updates (check monthly)
- If hardware monitoring tools report compatibility issues
- When experiencing hardware-related issues

### When to Add ASUS-Specific Tools
- When Noctalia Shell updates require them
- When you need detailed battery health information
- When you want to monitor additional ASUS-specific hardware
- When firmware updates enable new monitoring capabilities

---

## Resources

- **fwupd Guide**: See `FWUPD_ASUS_GUIDE.md`
- **ASUS Linux Drivers**: https://github.com/asus-linux
- **asusctl**: https://github.com/asus-linux/asusctl
- **Noctalia Shell**: https://github.com/noctalia-dev/noctalia-shell
- **LVFS (Firmware Updates)**: https://fwupd.org/lvfs/devices/

---

**Last Updated**: 2025-12-01  
**Status**: Firmware up to date, ready for enhanced monitoring when tools are available

