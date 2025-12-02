# Home Manager Migration Checklist

Quick reference for migrating packages from NixOS to Home Manager.

## Pre-Migration

- [ ] Backup current configuration files
- [ ] Review `HOME_MANAGER_SETUP_ANALYSIS.md`
- [ ] Decide on standalone vs NixOS module mode (recommend standalone)
- [ ] Install Home Manager
- [ ] Create initial `~/.config/home-manager/home.nix`

## Packages to Migrate (User-Level)

### Development Tools
- [ ] `neovim`
- [ ] `git`
- [ ] `wget`
- [ ] `gh`
- [ ] `rustc`
- [ ] `cargo`
- [ ] `pkg-config`
- [ ] `unstable.code-cursor`

### Terminal/TUI Apps
- [ ] `ghostty`
- [ ] `fastfetch`
- [ ] `neofetch`
- [ ] `cmatrix`
- [ ] `btop`
- [ ] `cava`
- [ ] `yazi`
- [ ] `fzf`
- [ ] `fuzzel`
- [ ] `wofi`

### User Applications
- [ ] `unstable.spotify`
- [ ] `thunderbird`
- [ ] `unstable.davinci-resolve-studio`
- [ ] `unstable.darktable`
- [ ] `gimp3`
- [ ] `unstable.omnissa-horizon-client`
- [ ] `signal-desktop`
- [ ] `signal-cli`
- [ ] `zoom-us`

### User Utilities
- [ ] `dropbox-cli`
- [ ] `busybox` (if user-level)
- [ ] `lshw` (if user-level)

### Systemd User Services
- [ ] `systemd.user.services.dropbox` (test carefully)

### Shell Configuration (Optional)
- [ ] Migrate `.zshrc` to Home Manager
- [ ] Test shell functionality

## Packages to KEEP in NixOS (System-Level)

### Core Desktop Environment
- [x] `niri`, `xwayland-satellite`, `unstable.quickshell`, `noctalia-shell`
- [x] `niri-amd-wrapper`, `niri-amd-session`

### Hardware Control
- [x] `brightnessctl`, `bc`, `wlsunset`, `swayidle`
- [x] `auto-brightness-sensor`, `brightnessctl-manual`, `brightness-save-restore`

### Hardware Drivers
- [x] `asus-dialpad-driver`

### GPU Offloading
- [x] `nvidia-offload`, `amd-only`

### Systemd User Services (OS-Level)
- [x] `systemd.user.services.noctalia-shell`
- [x] `systemd.user.services.wlsunset`
- [x] `systemd.user.services.auto-brightness-sensor`
- [x] `systemd.user.timers.auto-brightness-sensor`
- [x] `systemd.user.services.swayidle`
- [x] `systemd.user.services.asus-dialpad-driver`

### System Programs
- [x] `programs.firefox.enable` (or move to Home Manager)
- [x] `fwupd`

## Migration Steps

### Step 1: Install Home Manager
```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```

### Step 2: Create Initial home.nix
Create `~/.config/home-manager/home.nix` with basic structure.

### Step 3: Test Initial Setup
```bash
home-manager switch
```

### Step 4: Migrate Packages Incrementally
1. Add package to `home.nix` `home.packages`
2. Run `home-manager switch`
3. Test package works
4. Remove from `configuration.nix` `environment.systemPackages`
5. Run `sudo nixos-rebuild switch`
6. Verify system still works

### Step 5: Cleanup
- Remove all migrated packages from `configuration.nix`
- Test system rebuild
- Document final state

## Testing After Each Migration

- [ ] Package installed: `which <package-name>`
- [ ] Package works: Run the application
- [ ] System rebuild works: `sudo nixos-rebuild switch`
- [ ] Home Manager rebuild works: `home-manager switch`
- [ ] No broken dependencies
- [ ] Systemd services still work (if applicable)

## Rollback Commands

```bash
# Rollback Home Manager
home-manager switch --rollback

# Rollback NixOS
sudo nixos-rebuild switch --rollback

# Uninstall Home Manager (if needed)
home-manager uninstall
```

## Useful Aliases

Add to your shell config:
```bash
alias hms='home-manager switch'
alias nrs='sudo nixos-rebuild switch'
alias hmg='home-manager generations'
alias hme='home-manager edit'
```

## Notes

- Migrate packages one category at a time
- Test thoroughly after each step
- Keep hardware/system services in NixOS
- Document what's where for future reference

