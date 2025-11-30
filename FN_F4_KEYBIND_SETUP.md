# Fn+F4 Keyboard Backlight Toggle Setup

## Goal
Configure Fn+F4 (factory hardware setting) to toggle keyboard backlight on/off in Niri.

## Step 1: Identify the Key Event

The Fn key is a hardware modifier, so Fn+F4 likely sends a specific XF86 key code. We need to identify which one.

### Option A: Use `wev` (Wayland Event Viewer)

```bash
# Install wev if not already installed
nix-shell -p wev

# Run wev to capture key events
wev
```

Then press **Fn+F4** and look for the key name in the output. It will likely show something like:
- `XF86KbdBrightnessToggle`
- `XF86KbdBrightnessUp`
- `XF86KbdBrightnessDown`
- Or another XF86 key name

### Option B: Check if it's already recognized

Since you already have `XF86KbdBrightnessUp` and `XF86KbdBrightnessDown` configured, Fn+F4 might be one of these. Test by:
1. Pressing Fn+F4
2. Checking if the backlight changes (increases or decreases)

If it increases, it's `XF86KbdBrightnessUp`
If it decreases, it's `XF86KbdBrightnessDown`

### Option C: Check with `evtest` (if available)

```bash
# Find keyboard device
ls /dev/input/by-id/*kbd*

# Run evtest on keyboard device
sudo evtest /dev/input/eventX  # Replace X with your keyboard device number
```

Press Fn+F4 and look for the key code.

## Step 2: Add Toggle Keybind

Once you identify the key name, add it to your Niri config. Here are the most likely scenarios:

### Scenario 1: If Fn+F4 sends `XF86KbdBrightnessToggle`

Add this to your `binds` section in `~/.config/niri/config.kdl`:

```kdl
XF86KbdBrightnessToggle allow-when-locked=true { 
    spawn-sh "brightnessctl --class=leds --device=asus::kbd_backlight set $(brightnessctl --class=leds --device=asus::kbd_backlight get | awk '{print ($1 == 0) ? 3 : 0}')"; 
}
```

### Scenario 2: If Fn+F4 sends `XF86KbdBrightnessUp` (most common)

You have two options:

**Option A**: Replace the existing `XF86KbdBrightnessUp` with a toggle:

```kdl
// Replace the existing XF86KbdBrightnessUp line (line 406) with:
XF86KbdBrightnessUp allow-when-locked=true { 
    spawn-sh "brightnessctl --class=leds --device=asus::kbd_backlight set $(brightnessctl --class=leds --device=asus::kbd_backlight get | awk '{print ($1 == 0) ? 3 : 0}')"; 
}
```

**Option B**: Keep both behaviors - add a separate toggle keybind and keep the increment:

```kdl
// Keep existing XF86KbdBrightnessUp for increment
XF86KbdBrightnessUp allow-when-locked=true { spawn "brightnessctl" "--class=leds" "--device=asus::kbd_backlight" "set" "+1"; }

// Add toggle for Fn+F4 (if it sends the same key, this will override)
// Or use a different key name if Fn+F4 sends something else
```

### Scenario 3: If Fn+F4 sends a different key name

If `wev` shows a different key name (e.g., `XF86KbdBrightnessCycle` or something custom), use that name:

```kdl
<KEY_NAME> allow-when-locked=true { 
    spawn-sh "brightnessctl --class=leds --device=asus::kbd_backlight set $(brightnessctl --class=leds --device=asus::kbd_backlight get | awk '{print ($1 == 0) ? 3 : 0}')"; 
}
```

## Step 3: Test the Configuration

1. Save the config file
2. Reload Niri config: `niri msg action reload-config` (or restart Niri)
3. Press Fn+F4
4. Verify the keyboard backlight toggles between off (0) and max (3)

## Current Toggle Logic

The toggle command cycles between:
- **0** (off) → **3** (max brightness)
- **3** (max) → **0** (off)
- Any other value → **0** (off)

If you want different behavior (e.g., cycle through 0→1→2→3→0), we can modify the awk command.

## Alternative: Cycle Through Levels

If you prefer Fn+F4 to cycle through all brightness levels (0→1→2→3→0), use this instead:

```kdl
XF86KbdBrightnessUp allow-when-locked=true { 
    spawn-sh "brightnessctl --class=leds --device=asus::kbd_backlight set $(brightnessctl --class=leds --device=asus::kbd_backlight get | awk '{print ($1 >= 3) ? 0 : $1 + 1}')"; 
}
```

This will:
- 0 → 1
- 1 → 2
- 2 → 3
- 3 → 0

## Troubleshooting

### If Fn+F4 doesn't work:

1. **Check if the key is recognized**: Use `wev` to verify the key event is being sent
2. **Check key name**: Make sure you're using the exact key name from `wev`
3. **Check permissions**: Ensure `brightnessctl` can access the LED device
4. **Test manually**: Run the brightnessctl command manually to verify it works:
   ```bash
   brightnessctl --class=leds --device=asus::kbd_backlight set 3
   brightnessctl --class=leds --device=asus::kbd_backlight set 0
   ```

### If you want to keep increment/decrement AND add toggle:

You can bind Fn+F4 to a different key combination or use a different XF86 key if your keyboard supports it. For example, if Fn+F3 is brightness up and Fn+F4 is brightness down, you might need to check what Fn+F4 actually sends.

## Next Steps

1. Run `wev` to identify the exact key name for Fn+F4
2. Add the appropriate keybind to your config
3. Test and adjust as needed


