# NixOS 25.11 (Xantusia) Pre-Upgrade Compatibility Check
## Review Date: 2024-12-01
## Status: ✅ **UPGRADE COMPLETED** - See `NIXOS_25.11_UPGRADE_COMPLETED.md` for details

This document analyzed the NixOS 25.11 release notes against your current configuration to identify potential breakage issues before upgrading.

### Upgrade Status
- **Upgrade Date**: 2024-12-01
- **Status**: ✅ **COMPLETED SUCCESSFULLY**
- **Current Version**: 25.11 (Xantusia)
- **Kernel**: 6.17.9 (using `linuxPackages_latest`)
- **Channels Configured**:
  - `nixos https://nixos.org/channels/nixos-25.11`
  - `unstable https://nixos.org/channels/nixpkgs-unstable`

**📋 For complete upgrade details, see**: `NIXOS_25.11_UPGRADE_COMPLETED.md`

---

## ⚠️ **ACTUAL BREAKING CHANGES ENCOUNTERED** (Not in release notes)

The following breaking changes were **NOT** mentioned in the release notes but caused upgrade failures:

1. **services.logind.extraConfig → services.logind.settings.Login** (String → Attribute Set)
2. **services.xserver.displayManager.gdm → services.displayManager.gdm**
3. **services.xserver.desktopManager.gnome → services.desktopManager.gnome**
4. **Python package: systemd → systemd-python** (Package renamed)
5. **users.groups GID enforcement** (System GIDs required for udev)

**Note**: These option renamings make upgrades difficult for non-technical users. Consider documenting these changes more prominently in release notes.

---

### Previous System State (Pre-Upgrade)
- **NixOS Version**: 25.05
- **Kernel**: 6.17.8 (using `linuxPackages_latest`)
- **Channels Configured**:
  - `nixos https://nixos.org/channels/nixos-25.05`
  - `unstable https://nixos.org/channels/nixpkgs-unstable`
- **Note**: Already on a newer kernel (6.17.8) than the NixOS 25.11 default (6.12), which reduced upgrade risk.

---

## 🔴 **CRITICAL BREAKING CHANGES - Action Required**

### 1. **AMD GPU Driver Changes** 🔴 **HIGH PRIORITY**
- **Release Note**: `hardware.amdgpu.amdvlk` and the `amdvlk` package have been removed, as they have been deprecated by AMD.
- **Your Config**: 
  - Using `hardware-configuration.nix` (need to check if `hardware.amdgpu.amdvlk` is enabled)
  - GPU detection in `niri.nix` uses vendor ID `0x1002` (AMD) - should be fine
  - Using `MESA_LOADER_DRIVER_OVERRIDE=radeonsi` (Mesa driver, not AMDVLK)
- **Risk**: **LOW** - You're using Mesa/radeonsi, not AMDVLK
- **Action**: 
  - ✅ Verify `hardware-configuration.nix` doesn't enable `hardware.amdgpu.amdvlk`
  - ✅ If it does, remove it before upgrading
  - ✅ Your Mesa-based setup should work fine

### 2. **NetworkManager VPN Plugins** 🔴 **MEDIUM PRIORITY**
- **Release Note**: The NetworkManager module does not ship with a default set of VPN plugins anymore. All required VPN plugins must now be explicitly configured in `networking.networkmanager.plugins`.
- **Your Config**: 
  - `networking.networkmanager.enable = true` in `configuration.nix` (line 59)
  - No explicit VPN plugin configuration found
- **Risk**: **LOW-MEDIUM** - Only affects you if you use VPN plugins
- **Action**: 
  - ✅ If you use VPN (OpenVPN, WireGuard, etc.), add explicit plugin configuration:
    ```nix
    networking.networkmanager.plugins = with pkgs; [
      networkmanager-openvpn
      networkmanager-wireguard
      # Add others as needed
    ];
    ```
  - ✅ If you don't use VPN, no action needed

### 3. **Kernel Update** ⚠️ **LOW PRIORITY**
- **Release Note**: The default kernel package has been updated from 6.6 to 6.12.
- **Your Config**: 
  - `boot.kernelPackages = pkgs.linuxPackages_latest;` in `configuration.nix` (line 27)
  - **Current kernel**: 6.17.8 (already ahead of default)
  - GPU detection scripts in `niri.nix` rely on DRM subsystem
- **Risk**: **LOW** - You're using `linuxPackages_latest`, so you're already on a newer kernel (6.17.8) than the new default (6.12)
- **Action**: 
  - ✅ You'll continue getting the latest kernel with `linuxPackages_latest`
  - ✅ Monitor GPU detection after upgrade (though unlikely to have issues since you're already on a newer kernel)
  - ✅ Test that AMD GPU is still detected correctly
  - ✅ Verify brightness control still works
  - ✅ Check `dmesg` for any GPU-related errors

### 4. **GCC Update: 13 → 14** ⚠️ **LOW-MEDIUM PRIORITY**
- **Release Note**: GCC has been updated from GCC 13 to GCC 14. This introduces some backwards-incompatible changes.
- **Your Config**: 
  - Custom derivations in `niri.nix` (noctalia-shell, scripts)
  - No explicit compiler flags found
- **Risk**: **LOW** - Your custom derivations are simple and should compile fine
- **Action**: 
  - ✅ If build fails, check GCC 14 porting guide: https://gcc.gnu.org/gcc-14/porting_to.html
  - ✅ Most likely no action needed

### 5. **LLVM Update: 16/18 → 19** ⚠️ **LOW PRIORITY**
- **Release Note**: LLVM has been updated from LLVM 16 (on Darwin) and LLVM 18 (on other platforms) to LLVM 19.
- **Your Config**: 
  - No explicit LLVM dependencies found
  - Rust tools (rustc, cargo) may use LLVM internally
- **Risk**: **LOW** - Should not affect your configuration
- **Action**: 
  - ✅ Monitor Rust builds if you compile Rust code
  - ✅ Most likely no action needed

---

## ⚠️ **POTENTIAL ISSUES - Monitor Closely**

### 1. **nixos-rebuild-ng Enabled by Default** ⚠️ **LOW PRIORITY**
- **Release Note**: `nixos-rebuild-ng`, a full rewrite of `nixos-rebuild` in Python, is enabled by default from this release.
- **Your Config**: No explicit configuration found
- **Risk**: **LOW** - Should be transparent, but new tool might have different behavior
- **Action**: 
  - ✅ Test `nixos-rebuild switch --upgrade` as usual
  - ✅ If issues occur, can disable with `system.rebuild.enableNg = false;`
  - ✅ Report any issues to NixOS

### 2. **Systemd User Services** ⚠️ **LOW PRIORITY**
- **Release Note**: No specific systemd changes mentioned, but systemd version will update
- **Your Config**: 
  - Multiple systemd user services in `niri.nix`:
    - `noctalia-shell`
    - `wlsunset`
    - `auto-brightness-sensor` (timer + service)
    - `swayidle`
- **Risk**: **LOW** - Systemd user service syntax is stable
- **Action**: 
  - ✅ Verify all services start correctly after upgrade
  - ✅ Check `systemctl --user status` for any failures
  - ✅ Most likely no action needed

### 3. **Wayland/WLroots Updates** ⚠️ **LOW PRIORITY**
- **Release Note**: No specific Wayland/wlroots changes mentioned, but packages will update
- **Your Config**: 
  - Niri Wayland compositor
  - Environment variables: `WLR_DRM_DEVICES`, `WLR_DRM_NO_MODIFIERS`, etc.
  - Noctalia Shell (Qt6/QML)
- **Risk**: **LOW** - Wayland environment variables are stable
- **Action**: 
  - ✅ Test Niri session launches correctly
  - ✅ Verify GPU selection still works
  - ✅ Test Noctalia Shell widgets (brightness, WiFi, etc.)

### 4. **Qt6 Updates** ⚠️ **LOW PRIORITY**
- **Release Note**: No specific Qt6 changes mentioned, but Qt6 version will update
- **Your Config**: 
  - Noctalia Shell uses Qt6 (`qt6.qtbase`, `qt6.wrapQtAppsHook`)
  - Font configuration with `makeFontsConf`
- **Risk**: **LOW** - Qt6 is relatively stable, but minor API changes possible
- **Action**: 
  - ✅ Test Noctalia Shell launches and functions correctly
  - ✅ Verify all widgets work (brightness, WiFi, nightlight, etc.)
  - ✅ Check for any Qt6 deprecation warnings

---

## ✅ **SAFE TO UPGRADE - Low Risk Items**

### 1. **Core Packages**
- ✅ `brightnessctl` - Stable package, no breaking changes expected
- ✅ `swayidle` - Stable package, no breaking changes expected
- ✅ `wlsunset` - Stable package, no breaking changes expected
- ✅ `bc` - Stable package, no breaking changes expected

### 2. **Unstable Channel Packages**
- ✅ `unstable.quickshell` - Will update with unstable channel
- ✅ `unstable.code-cursor` - Will update with unstable channel
- ✅ `unstable.spotify` - Will update with unstable channel
- ✅ Other unstable packages - Will update with unstable channel
- **Note**: Ensure unstable channel is configured before upgrade

### 3. **Noctalia Shell**
- ✅ Pinned to `main` branch with SHA256
- ✅ SHA256 might need updating if `main` branch moved
- **Action**: Check SHA256 before upgrade (see checklist)

### 4. **Custom Scripts**
- ✅ `brightness-save-restore` - Simple bash script, no dependencies
- ✅ `auto-brightness-sensor` - Simple bash script, uses stable tools
- ✅ `brightnessctl-manual` - Simple wrapper script
- ✅ `swayidle-start` - Simple shell script
- ✅ `niri-amd-wrapper` - Simple bash script with stable kernel interfaces

### 5. **System Configuration**
- ✅ `system.stateVersion = "25.05"` - Will need to update to `"25.11"` after upgrade
- ✅ Bootloader configuration - Stable
- ✅ Power management (`services.power-profiles-daemon`) - Stable
- ✅ Logind configuration - Stable
- ✅ Pipewire configuration - Stable

---

## 📋 **Pre-Upgrade Checklist**

### Before Running `nixos-rebuild switch --upgrade`:

1. ✅ **Verify unstable channel is configured**
   ```bash
   nix-channel --list
   ```
   **Your Current Channels**:
   - ✅ `nixos https://nixos.org/channels/nixos-25.05` (configured)
   - ✅ `unstable https://nixos.org/channels/nixpkgs-unstable` (configured)
   
   **Note**: Your config uses `<unstable>` which references the `unstable` channel. Ensure it stays updated:
   ```bash
   nix-channel --update unstable
   ```

2. ✅ **Check for AMDVLK in hardware-configuration.nix**
   ```bash
   grep -i "amdvlk" /etc/nixos/hardware-configuration.nix
   ```
   If found, remove it before upgrading

3. ✅ **Update Noctalia Shell SHA256** (if needed)
   ```bash
   nix-prefetch-github noctalia-dev noctalia-shell --rev main
   ```
   Update line 168 in `niri.nix` if SHA256 changed

4. ✅ **Add VPN plugins** (if you use VPN)
   Add to `configuration.nix`:
   ```nix
   networking.networkmanager.plugins = with pkgs; [
     networkmanager-openvpn  # If using OpenVPN
     networkmanager-wireguard  # If using WireGuard
     # Add others as needed
   ];
   ```

5. ✅ **Test build in dry-run mode**
   ```bash
   sudo nixos-rebuild build --upgrade
   ```
   This builds without applying changes

6. ✅ **Backup current configuration**
   ```bash
   sudo nixos-rebuild list-generations
   ```
   Note current generation number for rollback

7. ✅ **Check current kernel version**
   ```bash
   uname -r
   ```
   **Your Current Kernel**: 6.17.8 (already newer than NixOS 25.11 default of 6.12)
   Note for comparison after upgrade

---

## 🔄 **Post-Upgrade Verification**

After upgrading, verify:

1. ✅ **System boots correctly**
   - Login to Niri session
   - Verify display works (not black screen)

2. ✅ **GPU detection works**
   - Check logs: `journalctl --user -u niri-session-amd` (if service exists)
   - Verify AMD GPU is detected: `ls -la /dev/dri/`
   - Check brightness control works

3. ✅ **Noctalia Shell launches**
   - Verify it starts: `systemctl --user status noctalia-shell`
   - Check widgets work (brightness, WiFi, nightlight, etc.)

4. ✅ **Hardware controls work**
   - Brightness control (keyboard + software)
   - Keyboard backlight
   - Nightlight (wlsunset service)
   - Auto-brightness sensor

5. ✅ **Power management works**
   - Auto-dim after 3 minutes
   - Screen lock after 5 minutes
   - Suspend after 15 minutes
   - Brightness restore on input

6. ✅ **Kernel compatibility**
   - Check kernel version: `uname -r` (you're using `linuxPackages_latest`, so may be newer than 6.12)
   - Verify GPU modules loaded: `lsmod | grep amdgpu`
   - Check for kernel errors: `dmesg | grep -i error`

7. ✅ **Systemd services**
   - Check all user services: `systemctl --user status`
   - Verify timers are active: `systemctl --user list-timers`

8. ✅ **Update stateVersion**
   - After successful upgrade, update `configuration.nix`:
     ```nix
     system.stateVersion = "25.11";
     ```
   - Rebuild to apply: `sudo nixos-rebuild switch`

---

## 🛠️ **Rollback Plan**

If upgrade breaks things:

1. **Rollback to previous generation**
   ```bash
   sudo nixos-rebuild switch --rollback
   ```

2. **Or boot into specific generation**
   - Reboot and select previous generation from boot menu
   - Or: `sudo nixos-rebuild boot --rollback`

3. **Pin to specific generation**
   ```bash
   sudo nixos-rebuild switch -I nixpkgs=/nix/var/nix/profiles/system-<generation>-link/nixpkgs
   ```

---

## 📝 **Summary**

**Overall Risk Level**: **LOW** (reduced from LOW-MEDIUM due to already being on newer kernel)

**Main Concerns**:
1. ✅ AMDVLK removal (check hardware-configuration.nix) - **VERIFIED: Not using AMDVLK**
2. ✅ NetworkManager VPN plugins (add if using VPN) - **Only if you use VPN**
3. ✅ Kernel update - **LOW RISK: Already on 6.17.8 (newer than 6.12 default)**
4. ✅ Noctalia Shell SHA256 might need updating

**Recommendation**: 
- ✅ **Safe to upgrade**, but follow the checklist above
- ✅ Test in a VM or on a test system first if possible
- ✅ Keep current generation available for rollback
- ✅ Monitor logs after upgrade for any issues
- ✅ Update Noctalia SHA256 proactively if `main` branch has moved

---

## 🔗 **Useful Commands**

```bash
# Check current NixOS version
nixos-version

# List available generations
sudo nixos-rebuild list-generations

# Check unstable channel
nix-channel --list

# Update unstable channel
nix-channel --update unstable

# Dry-run upgrade
sudo nixos-rebuild build --upgrade

# Perform upgrade
sudo nixos-rebuild switch --upgrade

# Check GPU detection
ls -la /dev/dri/
cat /sys/class/drm/card*/device/vendor

# Check systemd user services
systemctl --user status
systemctl --user list-timers

# Check kernel version
uname -r

# Check for errors
dmesg | grep -i error
journalctl --user -u noctalia-shell
journalctl --user -u swayidle
journalctl --user -u auto-brightness-sensor
```

---

**Last Updated**: $(date +%Y-%m-%d)
**Next Review**: After NixOS 25.11 upgrade

