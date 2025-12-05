# Color Profile Management in NixOS

## Overview

Your system uses `colord` (Color Manager) for ICC color profile management. While Niri (Wayland compositor) doesn't directly integrate with colord, profiles configured through GNOME will persist and be applied system-wide through colord's database.

## Current Status

- ✅ `colord` service is running
- ✅ `colormgr` tool is installed
- ⚠️ Display device not yet registered (will be detected when using GNOME)
- ✅ ICC profiles available in `/run/current-system/sw/share/color/icc/colord/`

## Available ICC Profiles

The following standard profiles are available:
- `sRGB.icc` - Standard RGB (most common, good for web content)
- `Rec709.icc` - HDTV standard (good for video content)
- `AdobeRGB1998.icc` - Wide gamut for professional photography
- `WideGamutRGB.icc` - Very wide gamut
- `ProPhotoRGB.icc` - Ultra-wide gamut for professional printing
- Various gamma profiles (5000K, 5500K, 6500K)

## Setting Up Color Profiles

### Method 1: Using GNOME Settings (Recommended)

1. **Log into GNOME session:**
   - At GDM login screen, select "GNOME" session (not Niri)
   - Log in

2. **Open Color Settings:**
   - Open Settings (Activities → Settings)
   - Navigate to **Color** (or search for "Color" in Settings)
   - Your display should appear in the list

3. **Install/Assign Profile:**
   - Click on your display
   - Click the profile dropdown
   - Select an existing profile (e.g., `sRGB` for accurate colors)
   - Or click "Add Profile" to install a custom ICC file
   - The profile will be saved to colord's database

4. **Verify Profile:**
   - The selected profile should show as "Active"
   - You can test by viewing images/videos with known color characteristics

5. **Return to Niri:**
   - Log out and log back into Niri session
   - The profile should persist and be applied automatically

### Method 2: Manual Profile Installation (Command Line)

If you have a custom ICC profile file:

```bash
# Install a profile for your display
colormgr device-add-profile "eDP-1" /path/to/your/profile.icc

# Set it as the default profile
colormgr device-set-default-profile "eDP-1" <profile-id>

# List available devices
colormgr get-devices

# List profiles for a device
colormgr get-profiles <device-id>
```

**Note:** Device names may not be detected until you've logged into GNOME at least once, as GNOME registers displays with colord.

### Method 3: Finding Display-Specific Profiles

For your ASUS display (model appears to be ATNA33AA08-0):

1. **Check ASUS website:**
   - Look for your laptop model's support page
   - Download display ICC profile if available

2. **Use DisplayCAL or ArgyllCMS:**
   - These tools can generate custom profiles using a colorimeter
   - Install via: `nix-env -iA nixos.argyllcms` or add to Home Manager

3. **Use Generic Profiles:**
   - Start with `sRGB.icc` for general use
   - Use `Rec709.icc` if you watch a lot of video content
   - These should improve skin tones compared to an uncalibrated display

## Verifying Profile Application

### Check Active Profile

```bash
# List devices and their profiles
colormgr get-devices --verbose

# Check which profile is active for a device
colormgr device-get-default-profile <device-id>
```

### Visual Testing

1. **YouTube Video Test:**
   - Watch videos with people (skin tones should look natural)
   - Compare before/after profile application
   - Look for overly saturated or shifted colors

2. **Image Test:**
   - Open images with known color characteristics
   - Use a color picker tool to verify RGB values match expectations

3. **Web Browser:**
   - Most modern browsers respect system color profiles
   - Firefox, Chromium, and Brave should all use the profile

## Troubleshooting

### Profile Not Applied in Niri

**Issue:** Profile set in GNOME but colors still look off in Niri.

**Solutions:**
1. **Verify colord is running:**
   ```bash
   systemctl status colord
   ```

2. **Check if device is registered:**
   ```bash
   colormgr get-devices
   ```
   If empty, log into GNOME once to register the display.

3. **Manually trigger profile application:**
   ```bash
   # Restart colord
   sudo systemctl restart colord
   
   # Or reload user session
   systemctl --user daemon-reload
   ```

4. **Check Wayland color management:**
   - Some Wayland compositors (like Niri) may not fully support color management
   - Consider using applications that support color management directly
   - Or use GNOME session for color-critical work

### colormgr Shows No Devices

**Cause:** Display hasn't been registered with colord yet.

**Fix:** Log into GNOME session at least once. GNOME automatically registers displays with colord when it starts.

### Profile Doesn't Persist

**Cause:** Profile may not be saved to colord database.

**Fix:**
1. Use GNOME Settings to assign the profile (most reliable)
2. Or manually save using `colormgr device-set-default-profile`

## Advanced: Custom Profile Generation

If you have a colorimeter (e.g., X-Rite, Datacolor):

1. **Install ArgyllCMS:**
   ```nix
   # Add to Home Manager or system packages
   argyllcms
   ```

2. **Generate Profile:**
   ```bash
   # Follow ArgyllCMS documentation for your specific device
   # This typically involves:
   # - Measuring display patches
   # - Generating ICC profile
   # - Installing the profile
   ```

3. **Install Generated Profile:**
   ```bash
   colormgr import-profile /path/to/generated.icc
   colormgr device-add-profile "eDP-1" <profile-id>
   ```

## Notes

- **Profile Persistence:** Profiles set in GNOME are stored in colord's database (`/var/lib/colord/`) and persist across sessions
- **Wayland Limitations:** Some Wayland compositors have limited color management support compared to X11
- **Application Support:** Not all applications respect system color profiles; professional applications (GIMP, Darktable, etc.) typically have their own color management
- **Multiple Displays:** Each display can have its own profile; colord manages them separately

## Recommended Profiles by Use Case

- **General Use / Web Browsing:** `sRGB.icc`
- **Video Watching:** `Rec709.icc`
- **Photo Editing:** `AdobeRGB1998.icc` or custom calibrated profile
- **Print Work:** `ProPhotoRGB.icc` or custom profile matching printer
- **Gaming:** Usually `sRGB.icc` (games rarely support color management)

## Next Steps

1. ✅ Enable colord service (done in configuration.nix)
2. Log into GNOME and set up a profile via Settings
3. Test with YouTube videos to verify skin tones look correct
4. Adjust profile if needed or generate custom profile for your specific display

