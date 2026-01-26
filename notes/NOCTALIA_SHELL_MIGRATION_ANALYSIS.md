# Noctalia Shell Migration Analysis
## Migrating from Custom Derivation to `unstable.noctalia-shell`

**Date**: Current  
**Objective**: Simplify `niri.nix` by using `unstable.noctalia-shell` from nixpkgs instead of custom derivation, while maintaining all functionality.

---

## Current State Analysis

### Custom Derivation in `niri.nix` (Lines 452-513)

**What it does:**
- Fetches from GitHub (`v4.0.0` tag)
- Builds with Qt6 (qtbase, qtmultimedia)
- Creates symlink: `$out/bin/noctalia-shell` → `quickshell/bin/qs`
- Installs to: `$out/share/noctalia-shell/`
- Wraps with Qt6 apps hook
- Includes runtime dependencies: quickshell, brightnessctl, cava, cliphist, ddcutil, matugen, wlsunset, wl-clipboard, gpu-screen-recorder
- Configures fonts: Roboto, Inter Nerd Font

### References to `noctalia-shell` Variable

1. **Line 291, 293** - `swayidle-start` script:
   ```nix
   '${unstable.quickshell}/bin/qs -p ${noctalia-shell}/share/noctalia-shell ipc call lockScreen lock'
   ```
   - **Critical**: Uses `${noctalia-shell}/share/noctalia-shell` path
   - **Action**: Must verify `unstable.noctalia-shell` has same structure

2. **Line 621** - `environment.systemPackages`:
   ```nix
   noctalia-shell
   ```
   - **Action**: Replace with `unstable.noctalia-shell`

3. **Line 662** - `systemd.user.services.noctalia-shell`:
   ```nix
   ExecStart = "${noctalia-shell}/bin/noctalia-shell";
   ```
   - **Action**: Replace with `unstable.noctalia-shell`

4. **Line 680-691** - `systemd.user.services.noctalia-shell` PATH:
   ```nix
   "PATH=/run/wrappers/bin:${pkgs.lib.makeBinPath (with pkgs; [
     unstable.quickshell
     brightnessctl
     cava
     cliphist
     ddcutil
     matugen
     wlsunset
     wl-clipboard
   ] ++ pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
     gpu-screen-recorder
   ])}:..."
   ```
   - **Note**: This PATH includes runtime dependencies
   - **Action**: Check if `unstable.noctalia-shell` includes these in its wrapper, or if we still need this explicit PATH

---

## Migration Options

### Option 1: Full Migration (Recommended if nixpkgs package is compatible)

**Steps:**
1. Add `unstable.noctalia-shell` to `configuration.nix` `environment.systemPackages`
2. Remove custom derivation from `niri.nix` (lines 452-513)
3. Update all references from `noctalia-shell` to `unstable.noctalia-shell`
4. Verify `swayidle-start` script path works with nixpkgs package
5. Check if systemd service PATH needs adjustment

**Pros:**
- ✅ Simplifies `niri.nix` significantly (~60 lines removed)
- ✅ Automatic updates via unstable channel
- ✅ Less maintenance (no manual SHA256 updates)
- ✅ Uses official nixpkgs package (likely better tested)

**Cons:**
- ⚠️ Need to verify package structure matches (especially `/share/noctalia-shell` path)
- ⚠️ May need to adjust systemd service PATH if nixpkgs package handles dependencies differently
- ⚠️ Version controlled by unstable channel (less control over exact version)

**Risks:**
- **Medium**: If nixpkgs package structure differs, `swayidle-start` IPC path may break
- **Low**: Systemd service should work if binary path is correct
- **Low**: Runtime dependencies should be handled by nixpkgs package wrapper

---

### Option 2: Hybrid Approach (Safer, More Control)

**Steps:**
1. Keep custom derivation but simplify it
2. Use `unstable.noctalia-shell` as base, override only if needed
3. Or: Use `unstable.noctalia-shell` but keep custom PATH in systemd service

**Pros:**
- ✅ More control over exact version
- ✅ Can customize if nixpkgs package lacks features
- ✅ Easier to debug issues

**Cons:**
- ❌ Still requires maintenance
- ❌ Doesn't fully simplify configuration

---

### Option 3: Conditional Migration (Test First)

**Steps:**
1. Add `unstable.noctalia-shell` alongside custom derivation
2. Test with a separate systemd service
3. Once verified, migrate fully

**Pros:**
- ✅ Safest approach
- ✅ Can test without breaking current setup

**Cons:**
- ❌ Temporary duplication
- ❌ More complex during transition

---

## Detailed Migration Plan (Option 1)

### Step 1: Add to `configuration.nix`

**Location**: After line 343 (in `environment.systemPackages`)

```nix
environment.systemPackages = with pkgs; [
  # ... existing packages ...
  unstable.noctalia-shell  # Add here
];
```

**OR** (if you want it in a more specific location):

Add a new section after imports, or in a dedicated packages section.

**Recommendation**: Add it in `configuration.nix` line 343 area, since it's a system-wide package that should be available to all users.

---

### Step 2: Update `niri.nix` References

#### 2a. Update `swayidle-start` script (Lines 291, 293)

**Current:**
```nix
timeout 300 '${unstable.quickshell}/bin/qs -p ${noctalia-shell}/share/noctalia-shell ipc call lockScreen lock'
```

**New:**
```nix
timeout 300 '${unstable.quickshell}/bin/qs -p ${unstable.noctalia-shell}/share/noctalia-shell ipc call lockScreen lock'
```

**⚠️ CRITICAL CHECK**: Verify that `unstable.noctalia-shell` has `/share/noctalia-shell` directory. If not, this will break.

---

#### 2b. Update `environment.systemPackages` (Line 621)

**Current:**
```nix
noctalia-shell
```

**New:**
```nix
# noctalia-shell  # Removed - now in configuration.nix
```

**OR** if you want to keep it here for clarity:
```nix
unstable.noctalia-shell  # Now from nixpkgs
```

---

#### 2c. Update `systemd.user.services.noctalia-shell` (Line 662)

**Current:**
```nix
ExecStart = "${noctalia-shell}/bin/noctalia-shell";
```

**New:**
```nix
ExecStart = "${unstable.noctalia-shell}/bin/noctalia-shell";
```

---

#### 2d. Review `systemd.user.services.noctalia-shell` PATH (Lines 680-691)

**Current PATH includes:**
- `unstable.quickshell`
- `brightnessctl`
- `cava`
- `cliphist`
- `ddcutil`
- `matugen`
- `wlsunset`
- `wl-clipboard`
- `gpu-screen-recorder` (x86_64 only)

**Action**: 
- Check if `unstable.noctalia-shell` wrapper already includes these in PATH
- If yes: Can simplify or remove this explicit PATH
- If no: Keep the PATH as-is, but reference `unstable.noctalia-shell` dependencies if available

**Recommendation**: Keep the PATH initially, test, then simplify if nixpkgs package handles it.

---

### Step 3: Remove Custom Derivation

**Remove lines 452-513** (the entire `noctalia-shell` derivation)

**Also remove:**
- Line 8 comment about "official package.nix approach" (no longer relevant)
- Any comments specific to the custom build process

---

### Step 4: Update `unstable` Import (if needed)

**Current in `niri.nix` line 8:**
```nix
unstable = import <unstable> { config.allowUnfree = true; };
```

**Action**: Keep this - it's still needed for:
- `unstable.quickshell` (line 620, 291, 293, 680)
- `unstable.noctalia-shell` (new)

**Note**: `configuration.nix` also has this import (line 7), which is fine for modularity.

---

## Verification Checklist

Before removing the custom derivation, verify:

- [ ] `unstable.noctalia-shell` exists in unstable channel
- [ ] `unstable.noctalia-shell/bin/noctalia-shell` exists and is executable
- [ ] `unstable.noctalia-shell/share/noctalia-shell` directory exists (for IPC path)
- [ ] `unstable.noctalia-shell` includes required runtime dependencies
- [ ] Test `swayidle-start` script with new path
- [ ] Test systemd service starts correctly
- [ ] Test IPC lock screen functionality
- [ ] Verify fonts are available (Roboto, Inter Nerd Font)
- [ ] Check if any custom build flags/patches are needed

---

## Potential Issues & Solutions

### Issue 1: Package Structure Mismatch

**Problem**: `unstable.noctalia-shell/share/noctalia-shell` path doesn't exist

**Solution Options:**
1. Check actual path: `nix-store -qR $(nix-build '<unstable>' -A noctalia-shell)`
2. Update `swayidle-start` to use correct path
3. Or: Keep custom derivation if structure is critical

---

### Issue 2: Missing Runtime Dependencies

**Problem**: nixpkgs package doesn't include all runtime deps in wrapper

**Solution**: Keep the explicit PATH in systemd service (lines 680-691)

---

### Issue 3: Font Configuration

**Problem**: nixpkgs package may use different fonts or font configuration

**Solution**: 
- Check if fonts are included in nixpkgs package
- If not, may need to add font packages to systemPackages
- Or: Keep font configuration if needed

---

### Issue 4: Version Mismatch

**Problem**: nixpkgs package might be different version than v4.0.0

**Solution**: 
- Check version: `nix eval '<unstable>#noctalia-shell.version'`
- If older: May need to wait for update or use overlay
- If newer: Test for compatibility

---

## Recommended Approach

### Phase 1: Preparation (No Changes)
1. Verify `unstable.noctalia-shell` exists and check its structure
2. Document current working state
3. Create backup/commit of current config

### Phase 2: Testing (Minimal Changes)
1. Add `unstable.noctalia-shell` to `configuration.nix` systemPackages
2. Keep custom derivation temporarily
3. Test if nixpkgs package works alongside custom one
4. Test IPC path: `qs -p ${unstable.noctalia-shell}/share/noctalia-shell ipc call lockScreen lock`

### Phase 3: Migration (Full Changes)
1. Update all references in `niri.nix` to use `unstable.noctalia-shell`
2. Remove custom derivation
3. Test thoroughly
4. Simplify systemd PATH if possible

---

## Files to Modify

### `configuration.nix`
- **Add**: `unstable.noctalia-shell` to `environment.systemPackages` (line ~343)

### `niri.nix`
- **Update**: `swayidle-start` script paths (lines 291, 293)
- **Update**: `environment.systemPackages` (line 621) - remove or update
- **Update**: `systemd.user.services.noctalia-shell` ExecStart (line 662)
- **Review**: `systemd.user.services.noctalia-shell` PATH (lines 680-691)
- **Remove**: Custom derivation (lines 452-513)
- **Update**: Comments if needed

---

## Summary

**Best Approach**: Option 1 (Full Migration) with careful verification

**Key Considerations**:
1. ✅ Package structure compatibility (especially `/share/noctalia-shell` path)
2. ✅ Runtime dependencies handling
3. ✅ Font configuration
4. ✅ Version compatibility

**Estimated Simplification**:
- **Lines removed**: ~60 lines (custom derivation)
- **Maintenance reduced**: No more manual SHA256 updates
- **Complexity reduced**: One less custom package to manage

**Risk Level**: **Medium** - Depends on nixpkgs package structure matching expectations

---

## Next Steps

1. **Verify nixpkgs package structure** before making changes
2. **Test in a safe environment** if possible
3. **Keep custom derivation as backup** during initial migration
4. **Document any differences** found between custom and nixpkgs versions

---

**Last Updated**: Current  
**Status**: Analysis Complete - Ready for Implementation Review

