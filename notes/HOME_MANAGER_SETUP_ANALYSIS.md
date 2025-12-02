# Home Manager Setup Analysis for SpectreOS

## Executive Summary

This document analyzes the setup of Home Manager for SpectreOS, identifies what can be migrated, potential difficulties, and provides recommendations for a safe migration path.

**Risk Level**: Low to Medium (with careful planning)
**Recommended Approach**: Standalone Home Manager mode (independent of NixOS system config)
**Estimated Migration Time**: 2-4 hours for initial setup + package migration

---

## Current System State

### Packages Currently in `environment.systemPackages`

#### From `configuration.nix` (lines 142-175):
- **Development Tools**: `neovim`, `git`, `wget`, `gh`, `rustc`, `cargo`, `pkg-config`
- **Terminal/TUI**: `ghostty`, `fastfetch`, `neofetch`, `cmatrix`, `btop`, `cava`, `yazi`, `fzf`, `fuzzel`
- **Applications**: 
  - `unstable.code-cursor` (IDE)
  - `unstable.spotify` (music)
  - `dropbox-cli` (cloud storage)
  - `zoom-us` (video conferencing)
  - `thunderbird` (email)
  - `unstable.davinci-resolve-studio` (video editing)
  - `unstable.darktable` (photo editing)
  - `gimp3` (image editing)
  - `unstable.omnissa-horizon-client` (VMware client)
  - `signal-desktop`, `signal-cli` (messaging)
  - `wofi` (application launcher)
- **System Tools**: `fwupd`, `busybox`, `lshw`

#### From `niri.nix` (lines 442-465):
- **Niri/Noctalia Core**: `niri`, `xwayland-satellite`, `unstable.quickshell`, `noctalia-shell`
- **Hardware Control**: `brightnessctl`, `bc`, `wlsunset`, `swayidle`
- **Custom Scripts**: `niri-amd-wrapper`, `brightness-save-restore`, `auto-brightness-sensor`, `brightnessctl-manual`
- **Optional**: `gpu-screen-recorder` (x86_64-linux only)

#### From `asus-dialpad.nix` (line 99):
- `asus-dialpad-driver` (custom package)

#### From `gpu-offload.nix` (line 114):
- `nvidia-offload`, `amd-only` (wrapper scripts)

### Systemd User Services

#### From `configuration.nix`:
- `systemd.user.services.dropbox` (lines 182-198)

#### From `niri.nix`:
- `systemd.user.services.noctalia-shell` (lines 481-510)
- `systemd.user.services.wlsunset` (lines 515-530)
- `systemd.user.timers.auto-brightness-sensor` (lines 537-545)
- `systemd.user.services.auto-brightness-sensor` (lines 547-559)
- `systemd.user.services.swayidle` (lines 568-596)

#### From `asus-dialpad.nix`:
- `systemd.user.services.asus-dialpad-driver` (line 104)

### System-Level Configurations

- `programs.firefox.enable = true` (configuration.nix line 131)
- `programs.zsh.enable = true` (configuration.nix line 134)
- `users.defaultUserShell = pkgs.zsh` (configuration.nix line 135)

---

## Home Manager Setup Options

### Option 1: Standalone Home Manager (RECOMMENDED)

**Pros**:
- Independent of NixOS system rebuilds
- Faster updates (only rebuilds user environment)
- Can update user packages without system rebuild
- Easier to rollback user changes
- Better for GUI frontend development (can update packages without sudo)

**Cons**:
- Requires separate `home-manager switch` command
- Two separate configuration files to manage
- Slightly more complex initial setup

**Installation**:
```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```

**Configuration Location**: `~/.config/home-manager/home.nix`

### Option 2: NixOS Module Integration

**Pros**:
- Single `nixos-rebuild switch` command
- Unified configuration management
- System and user configs in sync

**Cons**:
- Requires system rebuild for user package changes
- Requires sudo for all updates
- Slower rebuilds (rebuilds entire system)
- Less flexible for GUI frontend

**Installation**: Add to `configuration.nix`:
```nix
imports = [
  <home-manager/nixos>
];

home-manager.users.miles = {
  # ... user config
};
```

---

## Migration Analysis: What Should Move?

### ✅ **SHOULD Move to Home Manager** (User-Level Packages)

These are user applications and tools that don't require system-level privileges:

1. **Development Tools**:
   - `neovim`, `git`, `gh`, `rustc`, `cargo`, `pkg-config`
   - `unstable.code-cursor`

2. **Terminal/TUI Applications**:
   - `ghostty`, `fastfetch`, `neofetch`, `cmatrix`, `btop`, `cava`, `yazi`, `fzf`
   - `fuzzel`, `wofi` (application launchers)

3. **User Applications**:
   - `unstable.spotify`
   - `thunderbird`
   - `unstable.davinci-resolve-studio`
   - `unstable.darktable`
   - `gimp3`
   - `unstable.omnissa-horizon-client`
   - `signal-desktop`, `signal-cli`
   - `zoom-us`

4. **User Utilities**:
   - `dropbox-cli` (user-level cloud sync)
   - `busybox` (if used for user scripts)
   - `lshw` (if used by user)

5. **Systemd User Services** (can be managed in Home Manager):
   - `systemd.user.services.dropbox` (user-level service)

6. **Shell Configuration**:
   - `programs.zsh.enable` (can be managed by Home Manager)
   - Shell dotfiles (`.zshrc`, etc.)

### ❌ **MUST Stay in NixOS** (System-Level)

These require system-level configuration or are core to the OS:

1. **Niri/Noctalia Core** (OS Desktop Environment):
   - `niri`, `xwayland-satellite`, `unstable.quickshell`, `noctalia-shell`
   - `niri-amd-wrapper`, `niri-amd-session`
   - **Reason**: Core desktop environment, needs system-level session management

2. **Hardware Control** (System-Level):
   - `brightnessctl`, `bc`, `wlsunset`, `swayidle`
   - `auto-brightness-sensor`, `brightnessctl-manual`, `brightness-save-restore`
   - **Reason**: Hardware control requires system PATH, udev rules, system-level permissions

3. **Hardware Drivers**:
   - `asus-dialpad-driver`
   - **Reason**: Requires udev rules, system GIDs, system-level permissions

4. **GPU Offloading**:
   - `nvidia-offload`, `amd-only`
   - **Reason**: System-level GPU configuration, requires system PATH

5. **Systemd User Services** (OS-Level):
   - `systemd.user.services.noctalia-shell` (core desktop shell)
   - `systemd.user.services.wlsunset` (system-level nightlight)
   - `systemd.user.services.auto-brightness-sensor` (hardware control)
   - `systemd.user.timers.auto-brightness-sensor` (hardware control)
   - `systemd.user.services.swayidle` (system-level power management)
   - `systemd.user.services.asus-dialpad-driver` (hardware driver)
   - **Reason**: These are OS-level services that need system PATH and system-level binaries

6. **System Programs**:
   - `programs.firefox.enable` (can stay in NixOS or move to Home Manager - your choice)
   - `fwupd` (system firmware updates)

7. **System Configuration**:
   - `users.defaultUserShell` (system-level user configuration)

### ⚠️ **CONSIDER Moving** (Case-by-Case)

- `programs.firefox.enable`: Can be managed in Home Manager if you want user-level Firefox config
- `dropbox-cli`: Already user-level, but the systemd service might need system PATH

---

## Potential Difficulties

### 1. **System PATH Dependencies**

**Issue**: Many of your systemd user services rely on system PATH:
```nix
Environment = [
  "PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
];
```

**Impact**: If you move services to Home Manager, they may not find system binaries unless you:
- Keep the PATH environment variable
- Or ensure system packages are still in system PATH

**Solution**: Keep hardware-related services in NixOS, move only user applications to Home Manager.

### 2. **Unstable Channel References**

**Issue**: You use `unstable` channel in multiple places:
```nix
let 
   unstable = import <unstable> { config.allowUnfree = true; };
in
```

**Impact**: Home Manager needs access to the same `unstable` channel.

**Solution**: 
- In standalone mode: Add unstable channel to Home Manager config
- In NixOS module mode: Pass `unstable` as a parameter

**Example** (standalone):
```nix
# ~/.config/home-manager/home.nix
{ config, pkgs, ... }:
let
  unstable = import <unstable> { config.allowUnfree = true; };
in
{
  # ... config
}
```

### 3. **Systemd User Services Migration**

**Issue**: Systemd user services in Home Manager use slightly different syntax:
```nix
# NixOS
systemd.user.services.dropbox = { ... };

# Home Manager
systemd.user.services.dropbox = { ... };  # Same syntax, but different context
```

**Impact**: Services that depend on system PATH may break.

**Solution**: Only move user-level services (like Dropbox) that don't need system binaries.

### 4. **Shell Configuration Migration**

**Issue**: Home Manager can manage your entire shell config, but you may have existing `.zshrc` customizations.

**Impact**: Need to migrate shell configs to Home Manager format.

**Solution**: 
- Start with Home Manager managing basic shell
- Gradually migrate customizations
- Or keep shell management in NixOS if you prefer

### 5. **Package Availability**

**Issue**: Some packages might be available in NixOS but not in Home Manager (or vice versa).

**Impact**: May need to keep some packages in system config.

**Solution**: Most packages are available in both, but check if specific packages exist.

### 6. **Rebuild Process**

**Issue**: With standalone Home Manager, you'll have two rebuild commands:
- `sudo nixos-rebuild switch` (system)
- `home-manager switch` (user)

**Impact**: Need to remember which command to use.

**Solution**: Create aliases or wrapper scripts:
```bash
alias hms='home-manager switch'
alias nrs='sudo nixos-rebuild switch'
```

### 7. **Configuration File Organization**

**Issue**: With standalone Home Manager, you'll have:
- `configuration.nix` (system)
- `~/.config/home-manager/home.nix` (user)

**Impact**: Two places to manage packages.

**Solution**: Document clearly which packages go where. Consider creating a migration checklist.

### 8. **Initial Setup Complexity**

**Issue**: First-time Home Manager setup requires:
- Installing Home Manager
- Creating initial `home.nix`
- Migrating packages gradually
- Testing each migration step

**Impact**: Time investment upfront.

**Solution**: Start with a minimal `home.nix`, migrate packages incrementally.

---

## Recommended Migration Strategy

### Phase 1: Setup Home Manager (Standalone Mode)

1. **Install Home Manager**:
   ```bash
   nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz home-manager
   nix-channel --update
   nix-shell '<home-manager>' -A install
   ```

2. **Create Initial `~/.config/home-manager/home.nix`**:
   ```nix
   { config, pkgs, ... }:
   let
     unstable = import <unstable> { config.allowUnfree = true; };
   in
   {
     home.username = "miles";
     home.homeDirectory = "/home/miles";
     home.stateVersion = "25.11";
     
     # Allow unfree packages
     nixpkgs.config.allowUnfree = true;
     
     # Initial packages (start minimal)
     home.packages = with pkgs; [
       # Add packages here gradually
     ];
     
     # Programs configuration
     programs = {
       # Add program configs here
     };
   }
   ```

3. **Test Initial Setup**:
   ```bash
   home-manager switch
   ```

### Phase 2: Migrate Packages Incrementally

**Recommended Order**:

1. **Start with Simple Packages** (no dependencies):
   - `neovim`, `git`, `wget`, `gh`
   - `fastfetch`, `neofetch`, `cmatrix`

2. **Move Terminal/TUI Apps**:
   - `ghostty`, `btop`, `cava`, `yazi`, `fzf`

3. **Move Application Launchers**:
   - `fuzzel`, `wofi`

4. **Move User Applications**:
   - `unstable.spotify`
   - `thunderbird`
   - `signal-desktop`, `signal-cli`
   - `zoom-us`

5. **Move Development Tools**:
   - `rustc`, `cargo`, `pkg-config`
   - `unstable.code-cursor`

6. **Move Creative Applications** (if used frequently):
   - `unstable.davinci-resolve-studio`
   - `unstable.darktable`
   - `gimp3`

7. **Move Dropbox Service**:
   - `dropbox-cli` package
   - `systemd.user.services.dropbox` (test carefully - may need system PATH)

### Phase 3: Shell Configuration (Optional)

If you want Home Manager to manage your shell:

1. **Backup existing shell configs**:
   ```bash
   cp ~/.zshrc ~/.zshrc.backup
   ```

2. **Add to `home.nix`**:
   ```nix
   programs.zsh = {
     enable = true;
     # Add your customizations here
   };
   ```

3. **Test and migrate customizations gradually**

### Phase 4: Cleanup

1. **Remove migrated packages from `configuration.nix`**
2. **Test system rebuild**: `sudo nixos-rebuild switch`
3. **Verify all packages still work**
4. **Document what's where**

---

## Testing Checklist

After each migration step, verify:

- [ ] Package is installed: `which <package-name>`
- [ ] Package works: Run the application/command
- [ ] System rebuild still works: `sudo nixos-rebuild switch`
- [ ] Home Manager rebuild works: `home-manager switch`
- [ ] No broken dependencies
- [ ] Systemd user services still work (if applicable)

---

## Rollback Plan

If something goes wrong:

1. **Rollback Home Manager**:
   ```bash
   home-manager switch --rollback
   ```

2. **Rollback NixOS** (if system changes):
   ```bash
   sudo nixos-rebuild switch --rollback
   ```

3. **Remove Home Manager** (if needed):
   ```bash
   home-manager uninstall
   ```

---

## Benefits After Migration

1. **Faster Updates**: Update user packages without system rebuild
2. **Better for GUI Frontend**: Can update packages without sudo
3. **Cleaner Separation**: System packages vs user packages
4. **Easier Testing**: Test user package changes without affecting system
5. **Better for Multi-User**: Each user can have their own Home Manager config

---

## Recommendations

### ✅ **DO**:
- Use standalone Home Manager mode
- Start with minimal `home.nix`
- Migrate packages incrementally
- Test after each migration step
- Keep hardware/system services in NixOS
- Document what's where

### ❌ **DON'T**:
- Migrate everything at once
- Move hardware control packages to Home Manager
- Move Niri/Noctalia core to Home Manager
- Move systemd services that need system PATH
- Skip testing after migration steps

---

## Next Steps

1. **Review this analysis** and decide on approach
2. **Backup current configs** before starting
3. **Install Home Manager** in standalone mode
4. **Create minimal `home.nix`** and test
5. **Migrate packages one category at a time**
6. **Test thoroughly** after each step
7. **Document final state** for future reference

---

## Questions to Consider

1. **Do you want Home Manager to manage your shell config?**
   - Yes: More control, but need to migrate existing configs
   - No: Keep shell in NixOS, simpler migration

2. **How important is the GUI frontend?**
   - Very: Standalone Home Manager is better (no sudo needed)
   - Not critical: Either approach works

3. **Do you want to update user packages frequently?**
   - Yes: Standalone Home Manager is better
   - No: NixOS module integration might be simpler

---

## Estimated Time Investment

- **Initial Setup**: 30-60 minutes
- **Package Migration**: 1-2 hours (depending on testing)
- **Shell Config Migration** (optional): 30-60 minutes
- **Testing & Verification**: 30-60 minutes
- **Total**: 2.5-4.5 hours

---

## Conclusion

Home Manager setup is **low to medium risk** with careful planning. The recommended approach is **standalone Home Manager mode** for flexibility and faster updates. Keep hardware/system-level packages in NixOS, move user applications to Home Manager incrementally, and test thoroughly after each step.

The main difficulties are:
1. Managing system PATH dependencies (keep hardware services in NixOS)
2. Unstable channel references (add to Home Manager config)
3. Incremental migration process (take it slow, test often)

With this approach, you'll have a clean separation between system and user packages, making it easier to update user packages without system rebuilds and better suited for GUI frontend development.

