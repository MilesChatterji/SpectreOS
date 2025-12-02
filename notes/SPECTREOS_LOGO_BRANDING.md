# SpectreOS Logo Branding Guide

## Overview

This guide explains how to replace the Noctalia owl icon in the control center bar widget with the SpectreOS ghost logo.

## Icon Location and Detection

### How Noctalia Detects the Logo

The control center widget uses `HostService.osLogo`, which is automatically detected from `/etc/os-release`:

1. **Detection Process**:
   - Reads `/etc/os-release` and looks for the `LOGO` field
   - Searches for the logo in standard icon paths (see below)
   - Falls back to empty string if not found

2. **Standard Icon Paths Searched** (in order):
   ```
   /usr/share/pixmaps/{LOGO}.svg
   /usr/share/pixmaps/{LOGO}.png
   /usr/share/icons/hicolor/scalable/apps/{LOGO}.svg
   /usr/share/icons/hicolor/{SIZE}/apps/{LOGO}.{svg|png}
   /run/current-system/sw/share/icons/hicolor/scalable/apps/{LOGO}.svg
   /run/current-system/sw/share/icons/hicolor/{SIZE}/apps/{LOGO}.{svg|png}
   ```

   Where `{SIZE}` can be: `512x512`, `256x256`, `128x128`, `64x64`, `48x48`, `32x32`, `24x24`, `22x22`, `16x16`

### Current Noctalia Owl Icon Specifications

**File**: `/nix/store/.../Assets/noctalia.svg` (in source)

**Dimensions**:
- **viewBox**: `0 0 67.733334 67.733334` (~68x68 units)
- **Display size**: `256x256` (width/height attributes)
- **Format**: SVG (scalable vector graphics)
- **Aspect ratio**: 1:1 (square)

**Design Notes**:
- White fill (`#ffffff`) with dark blue stroke (`#0e0e43`)
- Yellow accent (`#fff59b`) for the owl body
- Light purple accent (`#a9aefe`) for details
- Designed to work with the colorize shader

## SpectreOS Logo Requirements

### Recommended Specifications

1. **Format**: SVG (preferred) or PNG
2. **Dimensions**: 
   - **SVG viewBox**: Square (e.g., `0 0 100 100` or similar)
   - **Display size**: 256x256 (for consistency)
   - **Aspect ratio**: 1:1 (square)
3. **Design Considerations**:
   - **Simple silhouette**: The shader will colorize it, so a simple outline/silhouette works best
   - **High contrast**: Should work well when converted to grayscale/intensity
   - **Transparent background**: Use transparent background (no fill)
   - **Stroke-based design**: Works better with the colorize shader than complex fills

### Shader Behavior

The control center uses **"distro mode"** (colorizeMode = 2.0) which:
- Extracts brightness/luminance from the icon
- Applies the target color (from theme: `Color.mOnSurface` or `Color.mSurfaceVariant`)
- Boosts brightness by 1.5x
- Normalizes intensity for better contrast
- Preserves alpha channel

**What this means for your logo**:
- Dark areas become the theme color at low intensity
- Light areas become the theme color at high intensity
- The logo will automatically adapt to light/dark themes
- A simple, high-contrast design works best

## Implementation Options

### Option 1: System-Wide Icon (Recommended)

Place your SpectreOS logo in the standard icon paths so it's detected automatically.

**Steps**:
1. Create your SpectreOS ghost logo SVG (or PNG)
2. Add it to your NixOS configuration:

```nix
# In configuration.nix or a separate branding module
environment.etc."os-release".text = ''
  # ... existing os-release content ...
  LOGO=spectreos
'';

# Add the logo to system icon paths
environment.systemPackages = with pkgs; [
  # ... other packages ...
];

# Create a custom package for the logo
spectreos-logo = pkgs.stdenvNoCC.mkDerivation {
  pname = "spectreos-logo";
  version = "1.0.0";
  src = ./assets/spectreos-logo.svg;  # Your logo file
  
  installPhase = ''
    mkdir -p $out/share/icons/hicolor/scalable/apps
    cp $src $out/share/icons/hicolor/scalable/apps/spectreos.svg
  '';
};
```

### Option 2: Widget Settings (Per-User)

Configure the logo via Noctalia widget settings (doesn't require system changes).

**Steps**:
1. Create your SpectreOS ghost logo SVG
2. Place it in `~/.config/noctalia/` or another accessible location
3. Configure the widget via Noctalia settings:
   - Right-click the control center widget → Widget Settings
   - Set `customIconPath` to your logo file path
   - Enable `colorizeDistroLogo` if you want the shader applied

### Option 3: Override in NixOS Configuration

Modify the Noctalia package to include your logo by default.

**Steps**:
1. Fork or patch the Noctalia source
2. Replace `Assets/noctalia.svg` with your SpectreOS logo
3. Update the package derivation in `niri.nix`

## File Locations Reference

### Shader Files
- **Source shader**: `Shaders/frag/appicon_colorize.frag`
- **Compiled shader**: `Shaders/qsb/appicon_colorize.frag.qsb`
- **Location in store**: `/nix/store/.../noctalia-shell/Shaders/`

### Widget Files
- **ControlCenter widget**: `Modules/Bar/Widgets/ControlCenter.qml`
- **HostService**: `Services/System/HostService.qml`
- **Location in store**: `/nix/store/.../noctalia-shell/`

### Current Icon
- **Source**: `Assets/noctalia.svg` (in Noctalia source repository)
- **Dimensions**: 256x256 display, 67.733334x67.733334 viewBox

## Display Size in Widget

The icon is displayed at:
- **Size**: `root.width * 0.8` (80% of widget width)
- **Widget base size**: `Style.capsuleHeight` (typically matches bar height)
- **Typical bar height**: ~40-60px (depends on density settings)
- **Typical icon size**: ~32-48px (80% of bar height)

**Recommendation**: Design your logo to look good at small sizes (32-64px), as that's where it will be displayed.

## Testing Your Logo

1. **Create your logo** following the specifications above
2. **Place it** in one of the standard paths or configure via widget settings
3. **Restart Noctalia**: `systemctl --user restart noctalia-shell`
4. **Check the widget**: The control center button should show your logo
5. **Test colorization**: Toggle `colorizeDistroLogo` in widget settings to see with/without shader

## Quick Reference: Logo Specs Summary

```
Format: SVG (preferred) or PNG
Aspect Ratio: 1:1 (square)
ViewBox: Square (e.g., 0 0 100 100)
Display Size: 256x256
Design: Simple silhouette, high contrast
Background: Transparent
Color: Will be colorized by shader (theme-aware)
Display Size in Widget: ~32-48px (80% of bar height)
```

## Next Steps

1. Design your SpectreOS ghost logo following these specifications
2. Choose an implementation option (Option 1 recommended for system-wide branding)
3. Add the logo to your NixOS configuration
4. Rebuild and test: `sudo nixos-rebuild switch`
5. Restart Noctalia: `systemctl --user restart noctalia-shell`





