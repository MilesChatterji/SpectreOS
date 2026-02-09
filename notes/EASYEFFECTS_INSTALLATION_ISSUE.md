# EasyEffects Installation Issue Analysis

## Problem Summary

**Issue**: EasyEffects is listed in `home.nix` and appears to be installed (visible in nix store), but:
- ❌ Not accessible via CLI (`which easyeffects` fails)
- ❌ Not showing in application launcher
- ✅ Works fine when run via `nix-shell -p easyeffects`

**Location**: `~/.config/home-manager/home.nix` line 73

---

## Investigation Findings

### 1. Package in Configuration ✅
- EasyEffects is correctly listed in `home.packages` at line 73
- Home Manager version: 25.11-pre
- Latest generation: `/nix/store/93zqslf8xndyvn0rvg4m9psa008bm1gk-home-manager-generation`

### 2. Package Not in User Profile ❌
- `~/.nix-profile` points to: `/nix/store/cvfg748sdswr0z0q7sbfdlqzjbg1b842-user-environment`
- EasyEffects binary **not found** in `~/.nix-profile/bin/`
- EasyEffects **not found** in user environment store path
- No desktop entries found in standard locations

### 3. Why `nix-shell` Works ✅
- `nix-shell -p easyeffects` creates a **temporary environment**
- Adds easyeffects directly to PATH in that shell session
- Uses a fresh evaluation of the package
- Doesn't depend on Home Manager profile

### 4. Why Home Manager Doesn't Work ❌
- Package may not be getting built/installed during `home-manager switch`
- Could be a build error that's being silently ignored
- Could be a profile activation issue
- Could be a PATH issue (not sourcing Home Manager session vars)

---

## Root Cause Analysis

### Most Likely Causes

#### 1. **Home Manager Build/Activation Issue**
**Symptom**: Package in config but not in profile
**Possible reasons**:
- Build error during `home-manager switch` (may be hidden)
- Profile not properly activated
- Package evaluation failing silently

#### 2. **PATH Not Sourced**
**Symptom**: Package exists but `which` can't find it
**Possible reasons**:
- `~/.nix-profile/etc/profile.d/hm-session-vars.sh` not sourced
- Shell not loading Home Manager environment
- PATH not including `~/.nix-profile/bin`

#### 3. **Package Wrapper Issue**
**Symptom**: Package built but binary not accessible
**Possible reasons**:
- EasyEffects might need special wrapping (GTK/GNOME app)
- Desktop entry not being generated
- Binary in non-standard location

#### 4. **Channel/Evaluation Mismatch**
**Symptom**: `nix-shell` works but Home Manager doesn't
**Possible reasons**:
- `nix-shell` uses different nixpkgs evaluation
- Home Manager using cached/stale evaluation
- Channel mismatch between `nix-shell` and Home Manager

---

## Diagnostic Steps

### Step 1: Check Home Manager Build Output
```bash
home-manager switch --show-trace 2>&1 | tee /tmp/hm-switch.log
# Look for easyeffects-related errors
grep -i easyeffects /tmp/hm-switch.log
```

### Step 2: Verify Package is Actually Built
```bash
# Check if package is in the store
nix-store -q --tree ~/.nix-profile | grep easyeffects

# Check Home Manager generation
ls -la /nix/store/93zqslf8xndyvn0rvg4m9psa008bm1gk-home-manager-generation/bin/ | grep easy
```

### Step 3: Check PATH
```bash
# Verify Home Manager session vars are sourced
echo $PATH | tr ':' '\n' | grep nix-profile

# Manually source and check
source ~/.nix-profile/etc/profile.d/hm-session-vars.sh
which easyeffects
```

### Step 4: Check Desktop Entries
```bash
# Find desktop entries
find ~/.local/share/applications ~/.nix-profile/share/applications -name "*easyeffects*"

# Check if desktop database needs update
update-desktop-database ~/.local/share/applications
```

### Step 5: Compare nix-shell vs Home Manager
```bash
# What nix-shell does
nix-shell -p easyeffects --run "which easyeffects"
nix-shell -p easyeffects --run "echo \$PATH"

# What Home Manager should do
ls -la ~/.nix-profile/bin/easyeffects
```

---

## Solutions

### Solution 1: Force Rebuild (Most Likely Fix)

**Try rebuilding Home Manager explicitly**:
```bash
# Remove current generation and rebuild
home-manager switch --impure

# Or rebuild with verbose output
home-manager switch --show-trace --verbose
```

**If that doesn't work, try**:
```bash
# Remove and re-add the package
# Edit home.nix, comment out easyeffects, switch, then uncomment and switch again
```

### Solution 2: Check for Build Errors

**Look for hidden build errors**:
```bash
# Check Home Manager logs
journalctl --user -u home-manager -n 100

# Check nix build logs
nix-store --verify --check-contents ~/.nix-profile 2>&1 | grep -i error
```

### Solution 3: Use `programs.easyeffects` Instead

**If `home.packages` doesn't work, try the program module**:
```nix
# In home.nix, replace:
# home.packages = [ ... easyeffects ... ];

# With:
programs.easyeffects = {
  enable = true;
};
```

**Note**: This may not exist - check if Home Manager has an easyeffects module.

### Solution 4: Manual PATH Fix

**If PATH is the issue**:
```bash
# Add to ~/.zshrc or ~/.bashrc
export PATH="$HOME/.nix-profile/bin:$PATH"

# Or source Home Manager vars
source ~/.nix-profile/etc/profile.d/hm-session-vars.sh
```

### Solution 5: Use Wrapper Script

**Create a wrapper if needed**:
```nix
# In home.nix home.packages
(pkgs.writeScriptBin "easyeffects" ''
  #!${pkgs.bash}/bin/bash
  exec ${pkgs.easyeffects}/bin/easyeffects "$@"
'')
```

---

## Why nix-shell Works But Home Manager Doesn't

### nix-shell Behavior
1. **Fresh evaluation**: Evaluates package on-the-fly
2. **Direct PATH**: Adds package bin directly to PATH
3. **No profile dependency**: Doesn't rely on user profile
4. **Temporary**: Creates isolated environment

### Home Manager Behavior
1. **Profile-based**: Adds to user profile (`~/.nix-profile`)
2. **Requires activation**: Needs `home-manager switch` to update
3. **Session vars**: Relies on `hm-session-vars.sh` being sourced
4. **Persistent**: Should be available in all shells

### Key Difference
- **nix-shell**: `nix-shell -p easyeffects` → temporary environment with easyeffects in PATH
- **Home Manager**: `home-manager switch` → should add to `~/.nix-profile/bin/` → needs PATH to include that

---

## Recommended Action Plan

### Immediate Steps

1. **Check build output**:
   ```bash
   home-manager switch --show-trace 2>&1 | grep -i easyeffects
   ```

2. **Verify package in store**:
   ```bash
   nix-store -q --tree ~/.nix-profile | grep easyeffects
   ```

3. **Check PATH**:
   ```bash
   echo $PATH | grep nix-profile
   source ~/.nix-profile/etc/profile.d/hm-session-vars.sh
   which easyeffects
   ```

4. **Try manual rebuild**:
   ```bash
   # Remove easyeffects from home.nix, switch, add back, switch
   home-manager switch
   ```

### If Still Not Working

1. **Check if it's a GTK/GNOME app issue** - may need special wrapping
2. **Try using the full store path** temporarily to verify it works
3. **Check Home Manager issue tracker** for similar problems
4. **Consider using `nix-env` as a workaround** (not recommended long-term)

---

## Expected Behavior After Fix

After resolving the issue, you should be able to:
- ✅ Run `easyeffects` from any terminal
- ✅ Find it in application launcher (GNOME/Niri)
- ✅ See it in `which easyeffects`
- ✅ See it in `~/.nix-profile/bin/easyeffects`

---

## Additional Notes

- EasyEffects is a GTK application that may require special handling
- It depends on PipeWire/PulseAudio (which you have configured)
- Desktop entries should be automatically generated by Home Manager
- The package is in nixpkgs, so it should work with Home Manager

---

**Last Updated**: Current  
**Status**: Investigation Complete - Ready for Diagnostic Steps

