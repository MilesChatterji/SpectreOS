# GPU Performance Issue Analysis
## Date: Current
## Issue: AMD GPU dumping logs, high load, slow performance after suspend/resume

---

## Root Cause Identified

### Primary Issue: Excessive DRM Debug Logging

**Location**: `configuration.nix` line 215
```nix
boot.kernelParams = [
  "drm.debug=0x1e"  # Enable comprehensive DRM debug output for MST troubleshooting
];
```

**Problem**: 
- `drm.debug=0x1e` enables **all** DRM debug flags (MST, connector/encoder, atomic/state debug)
- This causes **extremely verbose logging** - every atomic state change, plane update, and DRM operation is logged
- The logs show hundreds of amdgpu atomic state messages per second
- This is what you saw "dumping logs" on screen during suspend
- **This is causing significant performance degradation** - the kernel is spending CPU/GPU time logging instead of rendering

**Evidence from logs**:
- Boot logs show excessive `amdgpu` atomic state logging
- Every frame update generates multiple log entries
- System is spending resources on debug output

---

## Secondary Issues Found

### 1. Niri DRM Access Errors After Resume

**Log entries**:
```
niri[3093]: WARN niri::backend::tty: error adding device: DRM access error: 
  Error loading resource handles on device `Some("/dev/dri/card1")` 
  (Operation not supported (os error 95))
```

**Problem**: 
- After resume, Niri has trouble accessing the AMD GPU
- Error 95 = "Operation not supported"
- This suggests GPU might not be fully initialized after resume
- Could be related to the debug logging interfering with initialization

**Timing**: Errors occur right after resume (18:25:35)

---

### 2. AMDGPU DisplayPort Aux Retries

**Log entries**:
```
amdgpu 0000:c5:00.0: [drm:drm_dp_dpcd_access] AMDGPU DM aux hw bus 1-8: 
  Too many retries, giving up. First error: -5
```

**Problem**:
- GPU is trying to communicate with DisplayPort devices
- All 8 aux buses failing with error -5 (I/O error)
- This happens after resume and during boot
- Could indicate display connection issues or GPU initialization problems

---

### 3. Cava Segfault

**Log entry**:
```
cava[3493]: segfault at 0 ip 00007f1dabe8eac1 sp 00007ffe34e77f00 error 6 
  in libc.so.6
```

**Problem**:
- Audio visualizer (cava) crashed with segfault
- Could be related to GPU access issues or system instability
- Happened after resume (18:26:06)

---

### 4. System Performance Degradation

**Symptoms**:
- Slow boot times
- `fastfetch` takes several seconds
- General system sluggishness

**Cause**: 
- Excessive debug logging (`drm.debug=0x1e`) is consuming CPU/GPU resources
- Kernel is spending time logging instead of processing
- I/O overhead from constant log writes

---

## Recommended Solutions

### Solution 1: Remove/Reduce DRM Debug (IMMEDIATE FIX)

**Option A: Remove completely** (Recommended)
```nix
boot.kernelParams = [
  # Removed drm.debug=0x1e - was causing excessive logging and performance issues
  # If MST debugging needed, use lower verbosity: drm.debug=0x04
];
```

**Option B: Reduce to minimal MST debugging only**
```nix
boot.kernelParams = [
  "drm.debug=0x04"  # MST debug only (much less verbose)
];
```

**Why**: 
- The debug flag was added for MST troubleshooting
- If MST is working, you don't need this level of debugging
- Even if MST issues occur, you can temporarily enable it when needed

---

### Solution 2: Check GPU Initialization After Resume

**Action**: After removing debug flag, monitor resume behavior:
```bash
journalctl --since "1 hour ago" | grep -i "amdgpu\|drm\|resume" | tail -20
```

**If issues persist**:
- May need to add GPU reset parameters
- Check if GPU power management is working correctly

---

### Solution 3: Monitor System Performance

**After removing debug flag**:
1. Rebuild and reboot
2. Test boot time
3. Test `fastfetch` speed
4. Test suspend/resume cycle
5. Check if GPU stats load correctly

---

## Action Plan

### Immediate (Before Rebuild)

1. **Backup current configuration**
   ```bash
   sudo cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.backup
   ```

2. **Check available Nix generations** (you mentioned you have some saved)
   ```bash
   sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
   ```

### Step 1: Remove Debug Flag

**File**: `configuration.nix`  
**Line**: 215  
**Change**: Remove or comment out `"drm.debug=0x1e"`

### Step 2: Rebuild and Test

```bash
sudo nixos-rebuild switch
sudo reboot
```

### Step 3: Verify Fix

After reboot:
```bash
# Check boot time
systemd-analyze

# Test fastfetch speed
time fastfetch

# Check GPU access
ls -la /dev/dri/

# Test suspend/resume
# (suspend system, then check logs after resume)
journalctl --since "10 minutes ago" | grep -i "amdgpu\|drm\|error"
```

---

## If Issues Persist After Removing Debug Flag

### Check GPU State
```bash
# Check GPU info
lspci | grep -i amd
cat /sys/class/drm/card*/device/power_state

# Check GPU utilization
nvidia-smi  # For NVIDIA
# Or use radeontop for AMD (if installed)
```

### Check Kernel Version
```bash
uname -r
# Current: 6.18.8
# Consider rolling back if issues persist
```

### Rollback Options

If performance doesn't improve:
1. **Rollback to previous Nix generation**:
   ```bash
   sudo nixos-rebuild switch --rollback
   ```

2. **Or boot from previous generation**:
   - Reboot and select older generation from boot menu
   - Then rebuild current generation without debug flag

---

## Expected Results After Fix

1. ✅ **No more log dumping** during suspend/resume
2. ✅ **Faster boot times** (less logging overhead)
3. ✅ **Faster system performance** (fastfetch should be instant)
4. ✅ **GPU stats should load** (less interference from debug logging)
5. ✅ **Reduced GPU load** (not spending resources on logging)

---

## Additional Notes

### Why Debug Flag Was Added

From `configuration.nix` comments:
- Added for DisplayPort Multi-Stream Transport (MST) troubleshooting
- Helps with daisy-chained monitors via USB-C -> DP

### When to Re-enable (If Needed)

If MST issues occur in the future:
- Temporarily enable: `drm.debug=0x04` (MST only, less verbose)
- Or: `drm.debug=0x08` (connector/encoder only)
- **Never use `0x1e` in production** - it's too verbose

### Alternative: Runtime Debug Control

Instead of kernel parameter, you can enable debug at runtime:
```bash
# Enable MST debug only (less impact)
echo 0x04 | sudo tee /sys/module/drm/parameters/debug

# Disable
echo 0 | sudo tee /sys/module/drm/parameters/debug
```

---

## Summary

**Primary Issue**: `drm.debug=0x1e` causing excessive logging and performance degradation

**Fix**: Remove or reduce to `drm.debug=0x04` (MST only)

**Expected Impact**: Significant performance improvement, no more log dumping

**Risk**: Low - debug flag was for troubleshooting, not required for normal operation

---

**Last Updated**: Current  
**Status**: Ready for Implementation

