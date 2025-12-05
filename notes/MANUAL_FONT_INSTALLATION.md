# Manual Font Installation in NixOS

## Quick Answer

**GNOME Fonts app works perfectly!** It installs fonts to `~/.local/share/fonts/`, which fontconfig automatically scans. This works for:
- ✅ Most applications (Ghostty, browsers, editors, etc.)
- ✅ GNOME applications
- ✅ Wayland applications
- ❌ **Noctalia** (uses custom fontconfig, won't see these fonts)

## How GNOME Fonts App Works

When you install a font via GNOME Fonts:
1. Font file is copied to `~/.local/share/fonts/`
2. Fontconfig automatically detects it (no rebuild needed!)
3. Most apps can use it immediately
4. Works across all sessions (GNOME, Niri, etc.)

**This is the easiest method** and works great for manual font installation.

## Font Installation Methods

### Method 1: GNOME Fonts App (Easiest - Recommended)

1. **Open GNOME Fonts** (install via `gnome-font-viewer` if needed)
2. **Drag & drop** font files (.ttf, .otf) into the app
3. **Done!** Fonts are available immediately

**Location**: `~/.local/share/fonts/`
**Works for**: All apps except Noctalia
**No rebuild needed**: Fontconfig auto-detects

### Method 2: Manual Copy (Command Line)

```bash
# Create fonts directory if it doesn't exist
mkdir -p ~/.local/share/fonts

# Copy font files
cp /path/to/fonts/*.ttf ~/.local/share/fonts/
cp /path/to/fonts/*.otf ~/.local/share/fonts/

# Update font cache (optional - fontconfig does this automatically)
fc-cache -fv ~/.local/share/fonts/
```

**Location**: `~/.local/share/fonts/`
**Works for**: All apps except Noctalia
**No rebuild needed**: Fontconfig auto-detects

### Method 3: Symlinking (Works with Nix Store)

If you want to symlink fonts from a Nix store location:

```bash
# Create fonts directory
mkdir -p ~/.local/share/fonts

# Symlink from Nix store (example)
ln -s /nix/store/xxxxx-jetbrains-mono-xxx/share/fonts/truetype/* ~/.local/share/fonts/

# Or symlink entire directory
ln -s /nix/store/xxxxx-jetbrains-mono-xxx/share/fonts/truetype ~/.local/share/fonts/jetbrains-mono
```

**Note**: Symlinks to Nix store work, but fonts installed via Nix packages are better managed declaratively.

### Method 4: Declarative (NixOS Way - Best for Reproducibility)

Add to `configuration.nix` for system-wide:

```nix
fonts = {
  packages = with pkgs; [
    jetbrains-mono
    fira-code
    # Add other font packages
  ];
  
  fontconfig = {
    enable = true;
  };
};
```

Or to `home.nix` for user-level:

```nix
home.packages = with pkgs; [
  jetbrains-mono
  fira-code
];
```

**Requires**: `nixos-rebuild switch` or `home-manager switch`
**Works for**: All apps (including Noctalia if added to its fontconfig)

## Font Directories Fontconfig Checks

Fontconfig automatically scans these directories (in order):

1. `~/.local/share/fonts/` ← **GNOME Fonts installs here**
2. `~/.fonts/` (legacy, but still works)
3. `/run/current-system/sw/share/fonts/` (system-wide Nix fonts)
4. `/nix/store/*/share/fonts/` (Nix store fonts)

**You don't need to configure anything** - fontconfig finds fonts in these locations automatically!

## Verifying Font Installation

After installing fonts (via any method):

```bash
# List all fonts
fc-list : family | sort | uniq

# Check specific font
fc-list | grep -i "jetbrains\|font-name"

# Test in application
# Font should appear in font selectors
```

## Why Noctalia Doesn't See User Fonts

Noctalia uses a custom `FONTCONFIG_FILE` that only includes:
- Roboto
- Inter Nerd Font

This is intentional - it ensures Noctalia always has its required fonts. To add fonts to Noctalia, you need to update `niri.nix` (see FONT_MANAGEMENT.md).

## Recommendations

### For Most Users (Easiest)
1. **Use GNOME Fonts app** - drag & drop, works immediately
2. Fonts go to `~/.local/share/fonts/`
3. Works for all apps except Noctalia

### For NixOS Purity (Declarative)
1. **Add fonts to `configuration.nix`** or `home.nix`
2. Rebuild system
3. Works everywhere, including Noctalia (if added to its fontconfig)

### Hybrid Approach (Best of Both)
1. **Common fonts** → Install via Nix (declarative)
2. **One-off fonts** → Install via GNOME Fonts (quick & easy)
3. **Noctalia fonts** → Keep separate in `niri.nix`

## Symlinking from Nix Store

If you want to symlink fonts from Nix packages you've installed:

```bash
# Find font package location
nix-store --query --references $(which some-app) | grep fonts

# Or find specific font package
nix-store --query --references $(nix-build '<nixpkgs>' -A jetbrains-mono --no-out-link)

# Symlink to user fonts directory
mkdir -p ~/.local/share/fonts
ln -s /nix/store/xxxxx-jetbrains-mono-xxx/share/fonts/truetype/* ~/.local/share/fonts/
```

**However**, this is not recommended because:
- Nix store paths change on updates
- Better to install fonts declaratively or copy them
- Symlinks can break after `nix-collect-garbage`

## Summary

✅ **GNOME Fonts app works great** - use it for manual installation
✅ **No rebuild needed** - fontconfig auto-detects fonts in `~/.local/share/fonts/`
✅ **Works for all apps** except Noctalia (which uses custom fontconfig)
✅ **Symlinking works** but copying is more reliable
✅ **Declarative is best** for reproducibility, but manual is fine for one-off fonts

**Bottom line**: Just use GNOME Fonts app - it's the easiest and works perfectly with NixOS!

