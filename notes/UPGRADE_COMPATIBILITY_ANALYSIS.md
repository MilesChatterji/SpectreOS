# NixOS 25.11 Upgrade Compatibility Analysis
## Review Date: Current
## Target: NixOS 25.11 (from 25.05)

This document analyzes `niri.nix` and related configurations for potential upgrade issues.

---

## ✅ **SAFE TO UPGRADE - Low Risk Items**

### 1. **Core Niri Package** (`pkgs.niri`)
- **Status**: ✅ Should upgrade cleanly
- **Reason**: Uses stable channel package, no custom patches
- **Location**: Line 260
- **Action**: None needed - will auto-upgrade with nixpkgs

### 2. **Systemd User Services**
- **Status**: ✅ Stable across NixOS versions
- **Services**:
  - `noctalia-shell` (lines 289-318)
  - `wlsunset` (lines 323-338)
- **Reason**: Systemd service syntax is stable
- **Action**: None needed

### 3. **Hardware Control Utilities**
- **Status**: ✅ Stable packages
- **Packages**: `brightnessctl`, `wlsunset` (lines 266-267)
- **Reason**: Well-maintained packages in stable channel
- **Action**: None needed

### 4. **Kernel Interface Dependencies**
- **Status**: ✅ Stable (Linux kernel ABI)
- **Paths Used**:
  - `/sys/class/backlight/amdgpu_bl*` (line 21)
  - `/dev/dri/card*` and `/dev/dri/renderD*` (lines 33, 46)
  - `/sys/class/drm/*/device/vendor` (lines 35, 48)
- **Reason**: These are standard Linux kernel interfaces, unlikely to change
- **Action**: Monitor kernel changelog for DRM subsystem changes

### 5. **Display Manager Session Package**
- **Status**: ✅ Stable API
- **Location**: Lines 278-280
- **Reason**: `services.displayManager.sessionPackages` is a stable NixOS option
- **Action**: None needed

---

## ⚠️ **POTENTIAL ISSUES - Medium Risk Items**

### 1. **Unstable Channel Reference** ⚠️ **HIGH PRIORITY**
- **Status**: ⚠️ Could break if channel not configured
- **Location**: Line 8: `unstable = import <unstable> { config.allowUnfree = true; };`
- **Issue**: Uses channel reference `<unstable>` which requires:
  - Channel to be added: `nix-channel --add https://nixos.org/channels/nixos-unstable unstable`
  - Channel to be updated: `nix-channel --update unstable`
- **Risk**: If channel isn't configured, build will fail
- **Dependencies Using Unstable**:
  - `unstable.quickshell` (lines 181, 262)
  - `unstable.code-cursor` (in configuration.nix)
  - `unstable.spotify` (in configuration.nix)
  - `unstable.davinci-resolve-studio` (in configuration.nix)
  - `unstable.darktable` (in configuration.nix)
  - `unstable.omnissa-horizon-client` (in configuration.nix)
- **Recommendation**:
  - **Before upgrade**: Verify unstable channel is configured: `nix-channel --list`
  - **Alternative**: Consider pinning unstable to a specific commit for reproducibility
  - **Action**: Document channel setup in README

### 2. **Noctalia Shell Version Pinning** ⚠️ **MEDIUM PRIORITY**
- **Status**: ⚠️ Pinned to `main` branch with fixed SHA256
- **Location**: Lines 164-169
- **Current**: `rev = "main"`, `sha256 = "sha256-pWz6IWgG614EoVxPY6tlEsurZMznBvbyliI3go1BAuY="`
- **Issue**: 
  - Won't auto-update (good for stability, bad for getting fixes)
  - SHA256 will break if `main` branch changes
  - If upstream changes build process, derivation might fail
- **Risk**: Medium - could break if upstream makes breaking changes
- **Recommendation**:
  - **Before upgrade**: Check if SHA256 needs updating: `nix-prefetch-github noctalia-dev noctalia-shell --rev main`
  - **Consider**: Pinning to a specific release tag instead of `main` for stability
  - **Action**: Update SHA256 if build fails

### 3. **Quickshell Dependency** ⚠️ **MEDIUM PRIORITY**
- **Status**: ⚠️ Depends on unstable channel
- **Location**: Lines 181, 203, 262
- **Issue**: 
  - `unstable.quickshell` is used in multiple places
  - If quickshell API changes, noctalia-shell might break
  - Noctalia-shell links to quickshell binary (line 203)
- **Risk**: Medium - depends on quickshell compatibility
- **Recommendation**:
  - **Before upgrade**: Test that `unstable.quickshell` still works with noctalia-shell
  - **Monitor**: Check noctalia-shell GitHub for compatibility notes
  - **Action**: Update if incompatibility detected

### 4. **Qt6 Dependencies** ⚠️ **LOW-MEDIUM PRIORITY**
- **Status**: ⚠️ Qt6 version might change
- **Location**: Lines 171-177
- **Issue**: 
  - `qt6.wrapQtAppsHook` and `qt6.qtbase` are versioned
  - Qt6 major version changes could break Noctalia
  - Noctalia is built with Qt6/QML
- **Risk**: Low-Medium - Qt6 is relatively stable, but major updates happen
- **Recommendation**:
  - **Before upgrade**: Check Qt6 version in new nixpkgs
  - **Test**: Verify Noctalia still launches and functions correctly
  - **Action**: Update if Qt6 API changes break build

### 5. **Font Configuration** ⚠️ **LOW PRIORITY**
- **Status**: ⚠️ Font packages might change
- **Location**: Lines 193-198
- **Packages**: `pkgs.roboto`, `pkgs.inter-nerdfont`
- **Issue**: Font package names or paths might change
- **Risk**: Low - fonts are stable, but package structure could change
- **Recommendation**: None needed unless build fails

---

## 🔴 **HIGH RISK - Items to Monitor Closely**

### 1. **Kernel Module Compatibility** 🔴 **HIGH PRIORITY**
- **Status**: 🔴 Monitor kernel changes
- **Location**: `hardware-configuration.nix` + GPU detection scripts
- **Issue**: 
  - System uses `pkgs.linuxPackages_latest` (configuration.nix line 27)
  - GPU detection relies on kernel DRM subsystem
  - AMD GPU vendor ID detection (0x1002) should be stable
- **Risk**: Medium-High - Kernel updates could change DRM interfaces
- **Recommendation**:
  - **Before upgrade**: Review kernel changelog for DRM/amdgpu changes
  - **Test**: Verify GPU detection still works after kernel upgrade
  - **Fallback**: Can pin to specific kernel version if issues arise
  - **Action**: Test GPU detection script after upgrade

### 2. **Niri Config File Modification** 🔴 **MEDIUM PRIORITY**
- **Status**: 🔴 Script modifies user config file
- **Location**: Lines 72-80 (niri-amd-wrapper script)
- **Issue**: 
  - Script uses `sed -i` to modify `~/.config/niri/config.kdl`
  - If Niri changes config format, sed pattern might break
  - Pattern: `s|render-drm-device \"/dev/dri/renderD[0-9]*\"|render-drm-device \"/dev/dri/$AMD_RENDER\"|g`
- **Risk**: Medium - depends on Niri maintaining config format
- **Recommendation**:
  - **Before upgrade**: Check Niri changelog for config format changes
  - **Test**: Verify config modification still works
  - **Action**: Update sed pattern if Niri changes config format

### 3. **Environment Variable Usage** 🔴 **LOW-MEDIUM PRIORITY**
- **Status**: 🔴 Wayland/WLR environment variables
- **Location**: Lines 85-141 (wrapper script environment variables)
- **Variables Used**:
  - `WLR_DRM_DEVICES`
  - `WLR_DRM_NO_MODIFIERS`
  - `GBM_BACKEND`
  - `MESA_LOADER_DRIVER_OVERRIDE`
  - `__GLX_VENDOR_LIBRARY_NAME`
  - `DRI_PRIME`
  - `__NV_PRIME_RENDER_OFFLOAD`
- **Issue**: 
  - These are wlroots/Mesa environment variables
  - Could change if wlroots or Mesa update significantly
  - Some are NVIDIA-specific and might change
- **Risk**: Low-Medium - these are relatively stable, but major updates could change them
- **Recommendation**:
  - **Before upgrade**: Check wlroots and Mesa changelogs
  - **Test**: Verify GPU selection still works correctly
  - **Action**: Update if environment variable names change

---

## 📋 **Pre-Upgrade Checklist**

### Before Running `nixos-rebuild switch --upgrade`:

1. ✅ **Verify unstable channel is configured**
   ```bash
   nix-channel --list | grep unstable
   ```
   If missing: `nix-channel --add https://nixos.org/channels/nixos-unstable unstable && nix-channel --update unstable`

2. ✅ **Update Noctalia Shell SHA256** (if needed)
   ```bash
   nix-prefetch-github noctalia-dev noctalia-shell --rev main
   ```
   Update line 168 in `niri.nix` if SHA256 changed

3. ✅ **Test build in dry-run mode**
   ```bash
   nixos-rebuild build --upgrade
   ```
   This builds without applying changes

4. ✅ **Check for breaking changes**
   - Review NixOS 25.11 release notes
   - Check Niri changelog for config format changes
   - Review wlroots/Mesa changelogs if available

5. ✅ **Backup current configuration**
   ```bash
   sudo nixos-rebuild list-generations
   ```
   Note current generation number for rollback

6. ✅ **Test GPU detection script manually**
   ```bash
   /run/current-system/sw/bin/niri-session-amd --help
   ```
   Verify it can detect AMD GPU correctly

---

## 🔄 **Post-Upgrade Verification**

After upgrading, verify:

1. ✅ **Niri launches correctly**
   - Login to Niri session
   - Verify display works (not black screen)

2. ✅ **GPU detection works**
   - Check logs: `journalctl --user -u niri-session-amd` (if service exists)
   - Verify AMD GPU is detected: `ls -la /dev/dri/`
   - Check brightness control works

3. ✅ **Noctalia Shell launches**
   - Verify it starts: `systemctl --user status noctalia-shell`
   - Check widgets work (brightness, WiFi, etc.)

4. ✅ **Hardware controls work**
   - Brightness control (keyboard + software)
   - Nightlight (wlsunset service)
   - Keyboard backlight

5. ✅ **Kernel compatibility**
   - Check kernel version: `uname -r`
   - Verify GPU modules loaded: `lsmod | grep amdgpu`
   - Check for kernel errors: `dmesg | grep -i error`

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

## 📝 **Notes for NixOS 25.11**

- **State Version**: Currently `25.05` (configuration.nix line 224)
- **After upgrade**: Update to `25.11` when stable
- **Kernel**: Using `linuxPackages_latest` - will auto-update
- **Unstable Channel**: Required for several packages - ensure it's configured

---

## 🎯 **Summary**

**Overall Risk Level**: **LOW-MEDIUM**

Most components should upgrade cleanly. Main concerns:
1. Unstable channel configuration (ensure it's set up)
2. Noctalia Shell SHA256 might need updating
3. Kernel/DRM changes could affect GPU detection (unlikely but possible)

**Recommendation**: 
- ✅ Safe to upgrade, but test in a VM or on a test system first if possible
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
nixos-rebuild build --upgrade

# Check for package updates
nix-env -qaP --upgrade

# Verify GPU detection
ls -la /dev/dri/
cat /sys/class/drm/card*/device/vendor
```

---

**Last Updated**: Current
**Next Review**: Before NixOS 25.11 upgrade




