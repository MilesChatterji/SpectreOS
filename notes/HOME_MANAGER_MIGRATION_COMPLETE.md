# Home Manager Migration Complete

**Date**: December 2, 2025  
**NixOS Version**: 25.11  
**Home Manager Version**: 25.11

## Migration Summary

Successfully migrated user-level packages from NixOS system configuration to Home Manager standalone mode. This allows for faster user package updates without system rebuilds and better separation between system and user packages.

---

## System Packages (NixOS - `/etc/nixos/configuration.nix`)

These packages remain at the system level for TTY/recovery access and multi-user availability:

- **`neovim`** (binary: `nvim`) - TTY/recovery editing
- **`git`** - Version control in TTY/recovery
- **`wget`** - Downloads in TTY/recovery
- **`fwupd`** - System firmware updates
- **`busybox`** - System utilities
- **`lshw`** - Hardware information (system-level)
- **`firefox`** - Browser (via `programs.firefox.enable`)

**Location**: `configuration.nix` → `environment.systemPackages`

---

## Home Manager Packages (`~/.config/home-manager/home.nix`)

All user-level packages have been migrated to Home Manager:

### Simple System Info Tools
- `fastfetch`
- `neofetch`
- `cmatrix`

### Terminal/TUI Applications
- `ghostty`
- `btop`
- `cava`
- `yazi`
- `fzf`

### Application Launchers
- `fuzzel`

### User Applications
- `unstable.spotify`
- `signal-desktop`
- `signal-cli`
- `zoom-us`

### Development Tools
- `gh`
- `rustc`
- `cargo`
- `pkg-config`
- `unstable.code-cursor` (binary: `cursor`)

### Creative Applications
- `unstable.davinci-resolve-studio`
- `unstable.darktable`
- `gimp3`

### Remaining Utilities
- `unstable.omnissa-horizon-client` (binary: `horizon-client`)

### Dropbox
- `dropbox-cli` (package)
- `systemd.user.services.dropbox` (service)

**Location**: `~/.config/home-manager/home.nix` → `home.packages` and `systemd.user.services`

---

## Packages Removed (Not Migrated)

These packages were removed from the system configuration and should be manually removed if no longer needed:

- `wofi` - Application launcher (not in use)
- `thunderbird` - Email client (not in use)

---

## Configuration Files

### System Configuration
- **File**: `/etc/nixos/configuration.nix`
- **Rebuild**: `sudo nixos-rebuild switch`
- **Contains**: System-level packages, hardware config, services

### Home Manager Configuration
- **File**: `~/.config/home-manager/home.nix`
- **Rebuild**: `home-manager switch`
- **Contains**: User-level packages, user services, dotfiles

---

## Usage

### Update System Packages
```bash
sudo nixos-rebuild switch
```

### Update User Packages (Home Manager)
```bash
home-manager switch
```

### Rollback System
```bash
sudo nixos-rebuild switch --rollback
```

### Rollback Home Manager
```bash
home-manager switch --rollback
```

### View Home Manager Generations
```bash
home-manager generations
```

---

## Benefits Achieved

1. **Faster Updates**: User packages can be updated without system rebuild
2. **No Sudo Required**: Home Manager updates don't require root access
3. **Better Separation**: Clear distinction between system and user packages
4. **Easier Testing**: Test user package changes without affecting system
5. **GUI Frontend Ready**: Can build GUI that updates packages without sudo

---

## Verification

All packages verified working after migration:

- ✅ System packages available in `/run/current-system/sw/bin/`
- ✅ Home Manager packages available in `~/.nix-profile/bin/`
- ✅ Dropbox service configured in Home Manager
- ✅ System rebuild successful
- ✅ All packages functional

---

## Notes

- The `neovim` package provides the `nvim` binary (not `neovim`)
- The `unstable.code-cursor` package provides the `cursor` binary
- The `unstable.omnissa-horizon-client` package provides the `horizon-client` binary
- Dropbox service uses system paths for Qt plugins (configured correctly)
- All system packages remain available in TTY/recovery mode

---

## Future Maintenance

- Add new user packages to `~/.config/home-manager/home.nix`
- Add new system packages to `/etc/nixos/configuration.nix`
- Keep system packages minimal (only what's needed for recovery/TTY)
- Use Home Manager for all user-level applications and tools

