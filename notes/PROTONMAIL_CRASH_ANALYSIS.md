# ProtonMail Desktop Crash Analysis

## Issue Summary
ProtonMail Desktop (Electron app) is experiencing multiple segmentation faults (SIGSEGV) when launched. Additionally, MESA loader warnings appear when using the `amd-only` wrapper, but these are harmless and the app functions correctly.

## Crash Details

### Crash Frequency
- **4 crashes** on Dec 3, 2025 (15:01, 15:02, 15:11, 15:13)
- All crashes are **SIGSEGV** (segmentation fault)
- All crashes occur at similar memory addresses (0x...3ac4)

### Technical Details
- **Electron Version**: `electron-unwrapped-38.7.1`
- **ProtonMail Version**: `protonmail-desktop-1.9.1`
- **Signal**: SIGSEGV (11)
- **Architecture**: AMD x86-64
- **Command**: `/nix/store/.../electron /nix/store/.../protonmail-desktop-1.9.1/share/proton-mail/app.asar`

### Coredump Information
```
PID: 5346 (electron)
UID: 1000 (miles)
Signal: 11 (SEGV)
Timestamp: Wed 2025-12-03 15:12:32 PST
Executable: /nix/store/wzvbll6v8b8g6nrk20gs70mxxywr93xi-electron-unwrapped-38.7.1/libexec/electron/electron
Stack trace: #0  0x000056497dae3ac4 n/a (n/a + 0x0)
```

## Potential Causes

### 1. GPU/Rendering Issue (Most Likely)
- Electron may be auto-detecting NVIDIA GPU
- GPU driver incompatibility or initialization failure
- Wayland compositor (Niri) GPU selection conflicts

### 2. Wayland Compatibility
- Electron 38.7.1 may have Wayland-specific bugs
- Missing or incorrect Wayland environment variables
- Xwayland compatibility issues

### 3. Electron Version Bug
- Known issue in Electron 38.7.1
- May require updating to newer Electron version
- May require downgrading to stable version

## Recommended Solutions

### Solution 1: Force AMD GPU (Recommended) ✅ IMPLEMENTED
Use the `amd-only` wrapper to force ProtonMail to use AMD iGPU:

```bash
amd-only proton-mail
```

**Note**: The executable name is `proton-mail`, not `protonmail-desktop`.

**MESA Loader Warnings**: When using `amd-only`, you may see MESA loader errors about `/dev/dri/renderD129` (NVIDIA). These are **harmless** - MESA probes all render nodes at startup, and the NVIDIA probe fails (which is expected). The app will still work correctly using the AMD GPU.

The `amd-only` wrapper has been updated with:
- `MESA_LOADER_DRIVER_OVERRIDE=radeonsi` (forces AMD driver)
- `DRI_PRIME=0` (forces AMD iGPU)
- `__GLX_VENDOR_LIBRARY_NAME=mesa` (forces Mesa drivers)
- `CHROMIUM_FLAGS="--use-gl=egl --disable-gpu-sandbox"` (forces EGL rendering)
- **Note**: `GBM_BACKEND` was removed - MESA was misinterpreting it and constructing invalid library paths

**If crashes persist after rebuild**, try disabling GPU acceleration entirely:
```bash
ELECTRON_DISABLE_GPU=1 proton-mail
```

### Solution 2: Add Electron Environment Variables
Add Electron-specific environment variables to prevent GPU detection issues:

```nix
# In home.nix or configuration.nix
systemd.user.services.protonmail-desktop = {
  Service = {
    Environment = [
      "__GLX_VENDOR_LIBRARY_NAME=mesa"
      "DRI_PRIME=0"
      "__NV_PRIME_RENDER_OFFLOAD=0"
      "ELECTRON_DISABLE_SANDBOX=1"
      "ELECTRON_USE_ANGLE=0"
      "CHROMIUM_FLAGS=--use-gl=egl --disable-gpu-sandbox"
    ];
  };
};
```

### Solution 3: Update Electron Version
Check if a newer version of `protonmail-desktop` is available with a newer Electron version:

```bash
nix search nixpkgs protonmail-desktop
```

### Solution 4: Use Web Version
As a temporary workaround, use ProtonMail web interface in Brave browser.

## Diagnostic Commands

### Check for more crashes:
```bash
coredumpctl list electron
journalctl --since "24 hours ago" | grep -i "electron.*dumped core"
```

### Test with AMD-only wrapper:
```bash
amd-only proton-mail
```

**Expected Output**: The app should start successfully. You may see MESA loader warnings about `/dev/dri/renderD129` - these are harmless and can be ignored. The app will use the AMD GPU correctly.

### Check Electron version:
```bash
nix-store -q --references $(which proton-mail) | grep electron
```

### Monitor logs while launching:
```bash
journalctl --user -f &
proton-mail
```

## Next Steps

### Immediate Workarounds
1. **Use ProtonMail Web**: Access via browser (Brave, Firefox, etc.) - fully functional
2. **Check for updates**: `protonmail-desktop` may have a newer version with a fixed Electron
3. **Try AppImage/Flatpak**: Alternative packaging might work better

### Technical Solutions (if needed)
1. **Patch Electron package**: Add libcurl to Electron's dependencies (complex, requires Nix packaging knowledge)
2. **Use different Electron version**: Override `protonmail-desktop` to use a different Electron version
3. **Report bug**: This appears to be an Electron 38.7.1 bug on NixOS/Wayland

### Current Status
- ❌ **All attempted fixes failed**: GPU disabled, crashpad disabled, X11 mode, amd-only wrapper
- ⚠️ **Root cause**: Likely an Electron 38.7.1 bug or missing dependency in the Nix package
- ✅ **Workaround available**: Use ProtonMail web interface

## Status
- ✅ `amd-only` wrapper updated (removed `GBM_BACKEND` - was causing invalid path construction)
- ❌ **SIGSEGV crashes persist** - app starts but crashes shortly after initialization
- ❌ **GPU is NOT the issue** - crashes persist even with `ELECTRON_DISABLE_GPU=1`
- ❌ **Crashpad is NOT the issue** - crashes persist even with `ELECTRON_DISABLE_CRASH_REPORTER=1`
- ❌ **X11 mode doesn't help** - crashes persist with `ELECTRON_OZONE_PLATFORM=x11`
- ⚠️ **Crashpad errors detected**: Missing `libcurl` libraries (warnings only, not causing crash)
- 🔍 **Root cause**: Likely an Electron 38.7.1 bug or missing dependency in the Nix package
- 📝 MESA loader warnings are harmless - the crash happens after app initialization
- 💡 **Recommendation**: Use ProtonMail web interface until package is fixed or updated

## New Findings
- Crashpad (crash reporting) is failing to load libcurl libraries
- This might be causing the segfault if crashpad initialization fails
- Testing with `ELECTRON_DISABLE_CRASH_REPORTER=1` to see if this resolves the issue

