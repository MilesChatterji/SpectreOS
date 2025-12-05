# Font Management in NixOS

## Current Situation

Your system has fonts configured in different ways, which explains why different applications see different fonts:

### 1. **Noctalia Shell** (Custom Fontconfig)
- **Location**: `niri.nix` lines 480-485
- **Fonts Available**: 
  - Roboto
  - Inter Nerd Font
- **How it works**: Noctalia uses a custom `FONTCONFIG_FILE` that only includes these two fonts. This is why Noctalia sees different fonts than other apps.

### 2. **System-Wide Fonts** (Default NixOS)
- **Location**: `/run/current-system/sw/share/fonts/` (symlinked from Nix store)
- **Fonts Available**: Default NixOS fonts (DejaVu, Liberation, TeX Gyre, etc.)
- **Current Status**: No custom fonts configured - only defaults
- **How to configure**: Add `fonts.packages` to `configuration.nix`

### 3. **User Fonts** (Home Manager)
- **Location**: `~/.local/share/fonts/` or `~/.fonts/`
- **Current Status**: Not configured
- **How to configure**: Add `fonts.fontconfig.enable = true;` to `home.nix`

### 4. **Ghostty Terminal**
- **Config**: `~/.config/ghostty/config`
- **Current Font**: Not specified (using system default, likely DejaVu Sans Mono)
- **Note**: If you're seeing JetBrains Mono, it might be:
  - Bundled with Ghostty itself
  - A fallback font that looks similar
  - Configured elsewhere

## Font Locations in NixOS

```
System-wide fonts:
  /run/current-system/sw/share/fonts/  → Symlinked from Nix store
  Configured via: configuration.nix → fonts.packages

User fonts:
  ~/.local/share/fonts/  → Traditional location
  ~/.fonts/  → Alternative location
  Configured via: home.nix → fonts.fontconfig.enable

Application-specific (Noctalia):
  Custom fontconfig file (FONTCONFIG_FILE env var)
  Configured via: niri.nix → noctalia-shell fontsConf

Nix store fonts:
  /nix/store/*/share/fonts/  → Actual font files
  Accessed via: fontconfig system
```

## How to Fix Font Visibility Issues

### Option 1: Add System-Wide Fonts (Recommended)

Add fonts to `configuration.nix` so all applications can see them:

```nix
# In configuration.nix
fonts = {
  packages = with pkgs; [
    roboto
    inter-nerdfont
    jetbrains-mono  # If available
    # Add other fonts you want system-wide
  ];
  
  fontconfig = {
    enable = true;
    defaultFonts = {
      monospace = [ "JetBrains Mono" "DejaVu Sans Mono" ];
      sansSerif = [ "Roboto" "DejaVu Sans" ];
      serif = [ "DejaVu Serif" ];
    };
  };
};
```

### Option 2: Add User Fonts via Home Manager

Add fonts to `home.nix` for user-specific access:

```nix
# In home.nix
fonts.fontconfig.enable = true;

# Or install fonts as packages
home.packages = with pkgs; [
  jetbrains-mono  # If available
  # Other fonts
];
```

### Option 3: Update Noctalia's Font List

To make more fonts available to Noctalia, update `niri.nix`:

```nix
# In niri.nix, around line 480
fontsConf = pkgs.makeFontsConf {
  fontDirectories = [
    pkgs.roboto
    pkgs.inter-nerdfont
    pkgs.jetbrains-mono  # Add this
    # Add other fonts here
  ];
};
```

## Finding Font Packages

To find available fonts in NixOS:

```bash
# Search for fonts (requires nix-command feature)
nix search nixpkgs font | grep -i jetbrains

# Or browse online:
# https://search.nixos.org/packages?query=jetbrains
# https://search.nixos.org/packages?query=font
```

## Common Font Packages

- `jetbrains-mono` - JetBrains Mono
- `roboto` - Roboto
- `inter-nerdfont` - Inter with Nerd Font icons
- `fira-code` - Fira Code (programming font)
- `source-code-pro` - Adobe Source Code Pro
- `hack` - Hack font
- `iosevka` - Iosevka (highly customizable)

## Verifying Font Installation

After adding fonts, verify they're available:

```bash
# List all available fonts
fc-list : family | sort | uniq

# Check specific font
fc-list | grep -i jetbrains

# Test font in application
# Fonts should appear in font selectors after rebuild
```

## Why Noctalia Sees Different Fonts

Noctalia uses a custom `FONTCONFIG_FILE` environment variable that points to a fontconfig file containing only Roboto and Inter Nerd Font. This is intentional - it ensures Noctalia has the fonts it needs regardless of system configuration.

However, this means:
- ✅ Noctalia always has its required fonts
- ❌ Noctalia can't see system-wide fonts unless added to its fontconfig
- ❌ Other apps can't see Noctalia's fonts (they use system fontconfig)

## Recommendations

1. **Add system-wide fonts** in `configuration.nix` for general use
2. **Keep Noctalia's fontconfig** as-is (it ensures Noctalia works)
3. **Add JetBrains Mono** to system fonts if you want it everywhere
4. **Configure Ghostty** explicitly with `font-family = JetBrains Mono` in its config


