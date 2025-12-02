# fwupd (Firmware Update Daemon) Guide for ASUS Systems

**Date**: 2025-12-01  
**System**: NixOS 25.11 on ASUS PX13  
**Status**: Configured and Ready

---

## Overview

`fwupd` is a daemon that allows you to update firmware on supported devices, including:
- BIOS/UEFI firmware
- Embedded controllers (EC)
- Thunderbolt controllers
- USB-C controllers
- Other hardware components

**Your Configuration:**
- ✅ `services.fwupd.enable = true;` (enabled in configuration.nix)
- ✅ `fwupd` package installed
- ✅ `hardware.enableAllFirmware = true;` (enables firmware blobs)

---

## Basic Usage

### 1. Check for Available Updates

```bash
# Refresh metadata from LVFS (Linux Vendor Firmware Service)
fwupdmgr refresh

# Check for available firmware updates
fwupdmgr get-updates
```

### 2. View Supported Devices

```bash
# List all devices that fwupd can manage
fwupdmgr get-devices

# Get detailed information about a specific device
fwupdmgr get-devices --show-all
```

### 3. Update Firmware

```bash
# Update all devices with available firmware
fwupdmgr update

# Update a specific device (use device ID from get-devices)
fwupdmgr update --device <DEVICE_ID>

# Update with automatic reboot (if required)
fwupdmgr update --force
```

### 4. Check Update History

```bash
# View firmware update history
fwupdmgr get-history

# View detailed history
fwupdmgr get-history --json
```

---

## ASUS-Specific Considerations

### Supported ASUS Devices

ASUS has good support for fwupd through LVFS. Common supported devices include:
- **BIOS/UEFI firmware** - Most modern ASUS laptops
- **Embedded Controller (EC)** - Power management and hardware control
- **Thunderbolt controllers** - If your device has Thunderbolt
- **USB-C controllers** - For USB-C PD and data

### ASUS PX13 Specific Notes

Your PX13 should support:
- BIOS/UEFI updates
- EC firmware updates
- Possibly Thunderbolt/USB-C controller updates

### Important Warnings

⚠️ **BIOS/UEFI Updates:**
- **ALWAYS** ensure your laptop is plugged into AC power
- **DO NOT** interrupt the update process (don't close lid, don't power off)
- Updates may require a reboot and can take 5-10 minutes
- Some updates may require entering BIOS setup after reboot

⚠️ **Embedded Controller Updates:**
- Usually safer than BIOS updates
- May require reboot
- Should not interrupt normal operation

---

## Step-by-Step Update Process

### Safe Update Workflow

1. **Check current firmware versions:**
   ```bash
   fwupdmgr get-devices
   ```

2. **Refresh metadata:**
   ```bash
   fwupdmgr refresh
   ```

3. **Check for updates:**
   ```bash
   fwupdmgr get-updates
   ```

4. **Review what will be updated:**
   - Read the update descriptions
   - Check if updates are critical or recommended
   - Note any special requirements (AC power, reboot, etc.)

5. **Ensure safe conditions:**
   - ✅ Laptop plugged into AC power
   - ✅ Battery at least 50% charged (if possible)
   - ✅ No critical work in progress
   - ✅ System is stable (not overheating, no errors)

6. **Perform the update:**
   ```bash
   # For BIOS/UEFI updates, use --force to allow reboot
   fwupdmgr update --force
   
   # For other devices, regular update is fine
   fwupdmgr update
   ```

7. **Follow on-screen instructions:**
   - Some updates may require manual reboot
   - Some may reboot automatically
   - Some may require entering BIOS setup

8. **Verify update success:**
   ```bash
   fwupdmgr get-devices
   fwupdmgr get-history
   ```

---

## Advanced Usage

### Check Firmware Security Status

```bash
# Check for security issues
fwupdmgr security --force

# Get detailed security report
fwupdmgr security --force --json
```

### Enable/Disable Automatic Updates

```bash
# Check current auto-update status
fwupdmgr get-config

# Enable automatic updates (updates on next refresh)
fwupdmgr enable-remote <REMOTE_NAME>

# Disable automatic updates
fwupdmgr disable-remote <REMOTE_NAME>
```

### Offline Updates

If you need to update without internet:

```bash
# Download firmware files manually
fwupdmgr download <DEVICE_ID>

# Install from local file
fwupdmgr install <FIRMWARE_FILE.cab>
```

### Debugging

```bash
# Enable verbose output
fwupdmgr --verbose get-updates

# Check daemon status
systemctl status fwupd

# View daemon logs
journalctl -u fwupd -f
```

---

## Troubleshooting

### fwupd Service Not Running

```bash
# Check service status
systemctl status fwupd

# Start the service
sudo systemctl start fwupd

# Enable auto-start
sudo systemctl enable fwupd
```

### No Devices Detected

- Ensure `hardware.enableAllFirmware = true;` is set
- Check if your device is supported: https://fwupd.org/lvfs/devices/
- Some devices require specific kernel modules or udev rules

### Update Fails

- Check logs: `journalctl -u fwupd -n 100`
- Ensure AC power is connected
- Try updating one device at a time
- Check if device is in a safe state (not suspended, not in use)

### Metadata Refresh Fails

```bash
# Clear cache and refresh
fwupdmgr clear-offline
fwupdmgr refresh --force
```

---

## Best Practices

1. **Regular Checks**: Run `fwupdmgr refresh && fwupdmgr get-updates` monthly
2. **Read Release Notes**: Always review what the update fixes before applying
3. **Backup First**: For BIOS updates, consider backing up current settings
4. **Stable Environment**: Only update when system is stable and not in use
5. **One at a Time**: For multiple updates, apply them one at a time
6. **Verify After Update**: Always verify the update was successful

---

## Useful Commands Reference

```bash
# Quick check for updates
fwupdmgr refresh && fwupdmgr get-updates

# Full device information
fwupdmgr get-devices --show-all

# Update everything (with auto-reboot if needed)
fwupdmgr update --force

# Check security status
fwupdmgr security --force

# View update history
fwupdmgr get-history

# Check daemon status
systemctl status fwupd

# View logs
journalctl -u fwupd -n 50
```

---

## Additional Resources

- **LVFS (Linux Vendor Firmware Service)**: https://fwupd.org/
- **ASUS Device Support**: https://fwupd.org/lvfs/devices/
- **fwupd Documentation**: https://fwupd.org/docs/
- **NixOS fwupd Module**: https://search.nixos.org/options?query=services.fwupd

---

## Notes for Your System

- **Service**: Enabled via `services.fwupd.enable = true;`
- **Package**: `fwupd` installed in systemPackages
- **Firmware**: `hardware.enableAllFirmware = true;` enables firmware blobs
- **Auto-start**: fwupd service should start automatically on boot

---

**Last Updated**: 2025-12-01  
**Status**: Ready for use when firmware updates are needed

