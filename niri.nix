# Niri Wayland Compositor configuration with Noctalia Shell
# Based on official noctalia-shell package.nix approach
# https://github.com/noctalia-dev/noctalia-shell/tree/main/nix

{ config, pkgs, ... }:

let
  unstable = import <unstable> { config.allowUnfree = true; };
  
  # Helper script for brightness save/restore during idle dimming
  # Saves current brightness to a temp file before dimming
  # Restores brightness on resume (when user provides input)
  brightness-save-restore = pkgs.writeScriptBin "brightness-save-restore" ''
    #!${pkgs.bash}/bin/bash
    # Save or restore display brightness for idle dimming
    # Usage: brightness-save-restore save|restore
    BRIGHTNESS_FILE="$HOME/.cache/niri-brightness-backup"
    
    case "$1" in
      save)
        # Save current brightness level
        CURRENT=$(brightnessctl --class=backlight get 2>/dev/null || echo "50")
        echo "$CURRENT" > "$BRIGHTNESS_FILE"
        ;;
      restore)
        # Restore saved brightness level
        if [ -f "$BRIGHTNESS_FILE" ]; then
          SAVED=$(cat "$BRIGHTNESS_FILE")
          brightnessctl --class=backlight set "$SAVED" 2>/dev/null || true
          rm -f "$BRIGHTNESS_FILE"
        fi
        ;;
      *)
        echo "Usage: brightness-save-restore save|restore" >&2
        exit 1
        ;;
    esac
  '';
  
  # Auto brightness script based on ambient light sensor
  # Reads sensor from /sys/devices/.../iio:device*/in_illuminance_raw (dynamically discovered)
  # Maps lux values to brightness percentages with hysteresis to prevent flickering
  # Includes automatic manual override detection (30-second cooldown after manual changes)
  # Automatically detects manual brightness changes from keyboard shortcuts, Noctalia widget, or direct brightnessctl commands
  # Pauses when power saving dims the screen
  auto-brightness-sensor = pkgs.writeScriptBin "auto-brightness-sensor" ''
    #!${pkgs.bash}/bin/bash
    # Auto brightness based on ambient light sensor
    
    # Dynamically discover sensor path (device number may change after kernel/system upgrades)
    # Look for the HID-SENSOR-200041 ambient light sensor
    RAW_FILE=""
    SCALE_FILE=""
    
    # Find the sensor by searching for in_illuminance_raw files under HID-SENSOR-200041
    for raw_path in $(find /sys/devices -path "*HID-SENSOR-200041*" -name "in_illuminance_raw" 2>/dev/null); do
      if [ -r "''$raw_path" ]; then
        RAW_FILE="''$raw_path"
        # Find corresponding scale file in the same directory
        SENSOR_DIR=$(dirname "''$raw_path")
        if [ -r "''$SENSOR_DIR/in_illuminance_scale" ]; then
          SCALE_FILE="''$SENSOR_DIR/in_illuminance_scale"
          break
        fi
      fi
    done
    
    # Fallback: if not found, try finding any illuminance sensor
    if [ -z "''$RAW_FILE" ]; then
      RAW_FILE=$(find /sys/devices -name "in_illuminance_raw" 2>/dev/null | head -1)
      if [ -n "''$RAW_FILE" ]; then
        SENSOR_DIR=$(dirname "''$RAW_FILE")
        SCALE_FILE="''$SENSOR_DIR/in_illuminance_scale"
      fi
    fi
    
    # Exit if sensor not found
    if [ -z "''$RAW_FILE" ] || [ ! -r "''$RAW_FILE" ]; then
      exit 0  # Silently exit if sensor not available
    fi
    
    # Manual override protection
    MANUAL_BRIGHTNESS_FILE="''$HOME/.cache/manual-brightness-time"
    LAST_AUTO_BRIGHTNESS_FILE="''$HOME/.cache/last-auto-brightness"
    COOLDOWN=30  # seconds
    
    # Power saving integration - pause if screen is dimmed
    AUTO_BRIGHTNESS_DISABLED_FILE="/tmp/auto-brightness-disabled"
    if [ -f "''$AUTO_BRIGHTNESS_DISABLED_FILE" ]; then
      exit 0  # Skip adjustment when power saving has dimmed screen
    fi
    
    # Get current brightness
    CURRENT_RAW=$(${pkgs.brightnessctl}/bin/brightnessctl --class=backlight get 2>/dev/null || echo "0")
    CURRENT_MAX=$(${pkgs.brightnessctl}/bin/brightnessctl --class=backlight max 2>/dev/null || echo "100")
    CURRENT_PERCENT=$((CURRENT_RAW * 100 / CURRENT_MAX))
    
    # Check if user manually changed brightness recently (check cooldown FIRST)
    # Manual overrides are only set by brightnessctl-manual script, not auto-detected
    if [ -f "''$MANUAL_BRIGHTNESS_FILE" ]; then
      MANUAL_TIME=$(stat -c %Y "''$MANUAL_BRIGHTNESS_FILE" 2>/dev/null || echo "0")
      NOW=$(date +%s)
      if [ $((NOW - MANUAL_TIME)) -lt ''$COOLDOWN ]; then
        exit 0  # Skip auto adjustment during cooldown
      fi
      # Cooldown expired, remove the manual override file
      rm -f "''$MANUAL_BRIGHTNESS_FILE" 2>/dev/null || true
    fi
    
    # Read sensor values
    RAW=$(cat "''$RAW_FILE" 2>/dev/null || echo "0")
    SCALE=$(cat "''$SCALE_FILE" 2>/dev/null || echo "0.1")
    
    # Calculate lux
    LUX=$(echo "''$RAW * ''$SCALE" | ${pkgs.bc}/bin/bc -l)
    
    # Map lux to brightness (adjust these thresholds based on testing)
    # Using hysteresis to prevent flickering (only adjust if change is significant)
    if (( $(echo "''$LUX < 1" | ${pkgs.bc}/bin/bc -l) )); then
      TARGET_BRIGHTNESS=20   # Very dark (0-1 lux)
      TARGET_KBD_BRIGHTNESS=1  # Keyboard bright (level 1) in dark conditions
    elif (( $(echo "''$LUX < 10" | ${pkgs.bc}/bin/bc -l) )); then
      TARGET_BRIGHTNESS=35   # Dark (1-10 lux)
      TARGET_KBD_BRIGHTNESS=1  # Keyboard bright (level 1) in dark conditions
    elif (( $(echo "''$LUX < 50" | ${pkgs.bc}/bin/bc -l) )); then
      TARGET_BRIGHTNESS=50   # Dim (10-50 lux)
      TARGET_KBD_BRIGHTNESS=1  # Keyboard bright (level 1) in dim conditions
    elif (( $(echo "''$LUX < 200" | ${pkgs.bc}/bin/bc -l) )); then
      TARGET_BRIGHTNESS=70   # Normal (50-200 lux)
      TARGET_KBD_BRIGHTNESS=0  # Keyboard off in normal/bright conditions
    elif (( $(echo "''$LUX < 500" | ${pkgs.bc}/bin/bc -l) )); then
      TARGET_BRIGHTNESS=85   # Bright (200-500 lux)
      TARGET_KBD_BRIGHTNESS=0  # Keyboard off in bright conditions
    else
      TARGET_BRIGHTNESS=100  # Very bright (500+ lux)
      TARGET_KBD_BRIGHTNESS=0  # Keyboard off in very bright conditions
    fi
    
    # Only adjust if change is significant (hysteresis: 5% threshold)
    DIFF=$((TARGET_BRIGHTNESS - CURRENT_PERCENT))
    if [ ''${DIFF#-} -lt 5 ]; then
      exit 0  # Change too small, skip adjustment
    fi
    
    # Set screen brightness
    ${pkgs.brightnessctl}/bin/brightnessctl --class=backlight set "''$TARGET_BRIGHTNESS%"
    
    # Save the brightness we just set so we can detect manual changes later
    echo "''$TARGET_BRIGHTNESS" > "''$LAST_AUTO_BRIGHTNESS_FILE" 2>/dev/null || true
    
    # Set keyboard backlight (inverted: bright screen = dim keyboard, dim screen = bright keyboard)
    # User preference: Level 1 (first level) for dark conditions, never use brightest settings
    ${pkgs.brightnessctl}/bin/brightnessctl --class=leds --device=asus::kbd_backlight set "''$TARGET_KBD_BRIGHTNESS" 2>/dev/null || true
  '';
  
  # Helper script to manually set brightness and disable auto-brightness temporarily
  # Usage: brightnessctl-manual set 50% (or any brightnessctl command)
  # This marks the change as manual, preventing auto-brightness from overriding for 30 seconds
  # Also saves the brightness value so the auto-detection system knows what was set
  brightnessctl-manual = pkgs.writeScriptBin "brightnessctl-manual" ''
    #!${pkgs.bash}/bin/bash
    # Helper to set brightness manually and disable auto-brightness temporarily
    
    # Call brightnessctl with all arguments
    ${pkgs.brightnessctl}/bin/brightnessctl "$@"
    
    # Mark as manual change (touches timestamp file)
    touch "$HOME/.cache/manual-brightness-time" 2>/dev/null || true
    
    # Save the brightness value we just set (for screen brightness only)
    # This helps the auto-detection system track manual changes
    if echo "$*" | grep -q "backlight"; then
      CURRENT_RAW=$(${pkgs.brightnessctl}/bin/brightnessctl --class=backlight get 2>/dev/null || echo "0")
      CURRENT_MAX=$(${pkgs.brightnessctl}/bin/brightnessctl --class=backlight max 2>/dev/null || echo "100")
      CURRENT_PERCENT=$((CURRENT_RAW * 100 / CURRENT_MAX))
      echo "$CURRENT_PERCENT" > "$HOME/.cache/last-auto-brightness" 2>/dev/null || true
    fi
  '';
  
  # Script to apply ASUS DCI P3 ICC color profile to display
  # This ensures accurate color representation for DaVinci Resolve editing
  # Works by importing the profile and applying it to the display via colord
  # Note: Display must be registered with colord (usually done by GNOME)
  apply-color-profile = pkgs.writeScriptBin "apply-color-profile" ''
    #!${pkgs.bash}/bin/bash
    # Apply ASUS DCI P3 ICC color profile to display for accurate color in DaVinci Resolve
    
    PROFILE_PATH="/var/lib/colord/icc/ASUS_Display_DCIP3.icm"
    MAX_RETRIES=5
    RETRY_DELAY=3
    
    # Check if profile file exists
    if [ ! -f "$PROFILE_PATH" ]; then
      echo "Profile file not found: $PROFILE_PATH" >&2
      echo "This is not critical - profile may already be applied via GNOME" >&2
      exit 0  # Exit gracefully - don't fail the service
    fi
    
    # Wait for colord to be ready
    COLORD_READY=0
    for i in $(seq 1 $MAX_RETRIES); do
      if dbus-send --system --print-reply --dest=org.freedesktop.ColorManager /org/freedesktop/ColorManager org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
        COLORD_READY=1
        break
      fi
      sleep $RETRY_DELAY
    done
    
    if [ $COLORD_READY -eq 0 ]; then
      echo "colord service not responding - profile may already be applied" >&2
      exit 0  # Exit gracefully
    fi
    
    # Try to find the profile in colord database (may already be imported from GNOME)
    PROFILE_ID=""
    # First, try to find existing profile
    PROFILE_ID=$(colormgr get-profiles 2>/dev/null | grep -i "ASUS.*DCI.*P3\|ASUS_Display_DCIP3" | head -1 | awk '{print $1}' || echo "")
    
    # If not found, try to import it (with timeout handling)
    if [ -z "$PROFILE_ID" ]; then
      # Use timeout to prevent hanging (timeout is in coreutils, should be in PATH)
      IMPORT_OUTPUT=$(${pkgs.coreutils}/bin/timeout 10 colormgr import-profile "$PROFILE_PATH" 2>&1 || echo "timeout")
      if [ "$IMPORT_OUTPUT" != "timeout" ] && [ -n "$IMPORT_OUTPUT" ]; then
        # Try to extract profile ID from output
        PROFILE_ID=$(echo "$IMPORT_OUTPUT" | grep -i "profile.*id\|^[a-f0-9-]\{36\}" | head -1 | awk '{print $NF}' || echo "")
        # If still no ID, try parsing the object path
        if [ -z "$PROFILE_ID" ]; then
          PROFILE_ID=$(echo "$IMPORT_OUTPUT" | grep -oE "/[a-f0-9-]+" | head -1 | tr -d '/' || echo "")
        fi
      fi
    fi
    
    # Detect display - try to get registered displays from colord
    DISPLAY_NAME=""
    DISPLAY_ID=""
    
    # First, try to get any registered display device
    DISPLAY_ID=$(colormgr get-devices-by-kind display 2>/dev/null | head -1 | awk '{print $1}' || echo "")
    if [ -n "$DISPLAY_ID" ]; then
      # Extract display name from device ID or use the ID itself
      DISPLAY_NAME=$(colormgr get-devices 2>/dev/null | grep "$DISPLAY_ID" | awk '{print $2}' || echo "$DISPLAY_ID")
    fi
    
    # If no registered display, try to detect via Wayland
    if [ -z "$DISPLAY_NAME" ]; then
      for name in "eDP-1" "eDP" "DP-1" "HDMI-1"; do
        if command -v wlr-randr >/dev/null 2>&1; then
          if wlr-randr 2>/dev/null | grep -q "^$name"; then
            DISPLAY_NAME="$name"
            break
          fi
        fi
      done
    fi
    
    # Apply the profile if we have both profile ID and display
    if [ -n "$PROFILE_ID" ] && [ -n "$DISPLAY_ID" ]; then
      # Add profile to device
      colormgr device-add-profile "$DISPLAY_ID" "$PROFILE_ID" 2>/dev/null || true
      
      # Set as default profile
      colormgr device-make-profile-default "$DISPLAY_ID" "$PROFILE_ID" 2>/dev/null || true
      
      echo "Applied ASUS DCI P3 profile to display: $DISPLAY_NAME ($DISPLAY_ID)"
      exit 0
    elif [ -n "$PROFILE_ID" ] && [ -n "$DISPLAY_NAME" ]; then
      # Try using display name directly (may work if device exists but not registered)
      colormgr device-add-profile "$DISPLAY_NAME" "$PROFILE_ID" 2>/dev/null || true
      colormgr device-make-profile-default "$DISPLAY_NAME" "$PROFILE_ID" 2>/dev/null || true
      echo "Applied ASUS DCI P3 profile to display: $DISPLAY_NAME"
      exit 0
    else
      # Profile file exists and is valid, but display isn't registered yet
      # This is OK - the profile will be applied when display is registered (e.g., via GNOME)
      echo "Profile file exists, but display not registered with colord yet" >&2
      echo "This is normal for Niri - profile will be available when display is registered" >&2
      echo "If you set the profile in GNOME, it should persist and work in applications" >&2
      exit 0  # Exit gracefully - don't fail the service
    fi
  '';
  
  # swayidle startup script with configured timeouts
  # Handles auto-dim, screen lock, and suspend on idle
  # Uses Noctalia Shell's built-in lock screen via IPC instead of swaylock
  # Note: Noctalia Shell uses -p flag to point to its installation directory, not -c for config name
  # Integrates with auto-brightness by disabling it during dimming
  swayidle-start = pkgs.writeShellScript "swayidle-start" ''
    ${pkgs.swayidle}/bin/swayidle -w \
      timeout 180 '${brightness-save-restore}/bin/brightness-save-restore save && touch /tmp/auto-brightness-disabled && ${pkgs.brightnessctl}/bin/brightnessctl --class=backlight set 10% && KBD_BRIGHTNESS=$(${pkgs.brightnessctl}/bin/brightnessctl --class=leds --device=asus::kbd_backlight get 2>/dev/null || echo "0") && echo "$KBD_BRIGHTNESS" > "$HOME/.cache/niri-kbd-brightness-backup" && ${pkgs.brightnessctl}/bin/brightnessctl --class=leds --device=asus::kbd_backlight set 0' \
        resume '${brightness-save-restore}/bin/brightness-save-restore restore && rm -f /tmp/auto-brightness-disabled && if [ -f "$HOME/.cache/niri-kbd-brightness-backup" ]; then KBD_BRIGHTNESS=$(cat "$HOME/.cache/niri-kbd-brightness-backup"); ${pkgs.brightnessctl}/bin/brightnessctl --class=leds --device=asus::kbd_backlight set "$KBD_BRIGHTNESS" 2>/dev/null || true; rm -f "$HOME/.cache/niri-kbd-brightness-backup"; fi' \
      timeout 300 '${unstable.noctalia-qs}/bin/qs -p ${noctalia-shell}/share/noctalia-shell ipc call lockScreen lock' \
      timeout 900 '${brightness-save-restore}/bin/brightness-save-restore save && ${pkgs.systemd}/bin/systemctl suspend' \
        before-sleep '${unstable.noctalia-qs}/bin/qs -p ${noctalia-shell}/share/noctalia-shell ipc call lockScreen lock'
  '';
  
  # Wrapper script for Niri that forces AMD iGPU usage
  # This prevents NVIDIA GPU access by default to reduce power consumption
  # Applications can still use NVIDIA via nvidia-offload wrapper when needed
  # Dynamically detects AMD card and render node to handle device number swaps
  niri-amd-wrapper = pkgs.writeScriptBin "niri-session-amd" ''
    #!${pkgs.bash}/bin/bash
    # Force AMD 890M iGPU for Niri Wayland compositor and all applications
    # Dynamically detects AMD card and render node to handle device number swaps
    
    # Detect AMD card by finding the backlight device (AMD GPUs have amdgpu_bl*)
    AMD_CARD=""
    for backlight in /sys/class/backlight/amdgpu_bl*; do
      if [ -e "$backlight" ]; then
        # Extract card number from symlink path
        AMD_CARD=$(readlink -f "$backlight" | grep -o "card[0-9]" | head -1)
        if [ -n "$AMD_CARD" ]; then
          break
        fi
      fi
    done
    
    # Fallback: detect AMD card by vendor ID (0x1002 = AMD)
    if [ -z "$AMD_CARD" ]; then
      for card in /dev/dri/card*; do
        if [ -e "$card" ]; then
          vendor=$(cat /sys/class/drm/$(basename "$card")/device/vendor 2>/dev/null)
          if [ "$vendor" = "0x1002" ] || [ "$vendor" = "4098" ]; then
            AMD_CARD=$(basename "$card")
            break
          fi
        fi
      done
    fi
    
    # Detect AMD render node by vendor ID (0x1002 = AMD)
    AMD_RENDER=""
    for render in /dev/dri/renderD*; do
      if [ -e "$render" ]; then
        vendor=$(cat /sys/class/drm/$(basename "$render")/device/vendor 2>/dev/null)
        if [ "$vendor" = "0x1002" ] || [ "$vendor" = "4098" ]; then
          AMD_RENDER=$(basename "$render")
          break
        fi
      fi
    done
    
    # Validate detection
    if [ -z "$AMD_CARD" ] || [ ! -e "/dev/dri/$AMD_CARD" ]; then
      echo "ERROR: Could not detect AMD GPU card device" >&2
      exit 1
    fi
    
    if [ -z "$AMD_RENDER" ] || [ ! -e "/dev/dri/$AMD_RENDER" ]; then
      echo "ERROR: Could not detect AMD GPU render node" >&2
      exit 1
    fi
    
    echo "Detected AMD card: /dev/dri/$AMD_CARD"
    echo "Detected AMD render node: /dev/dri/$AMD_RENDER"
    
    # Update Niri config file to use the detected AMD render node
    # The config file override takes precedence over environment variables
    NIRI_CONFIG="$HOME/.config/niri/config.kdl"
    if [ -f "$NIRI_CONFIG" ]; then
      # Update render-drm-device in config file if it exists
      if grep -q "render-drm-device" "$NIRI_CONFIG"; then
        # Use sed to update the render device path
        sed -i "s|render-drm-device \"/dev/dri/renderD[0-9]*\"|render-drm-device \"/dev/dri/$AMD_RENDER\"|g" "$NIRI_CONFIG"
        echo "Updated Niri config: render-drm-device = /dev/dri/$AMD_RENDER"
      fi
      
      # Note: MST outputs that fail via IPC should be added to config.kdl manually
      # Example: output "DP-11" { mode "3840x2160@60.000" }
    fi
    
    # CRITICAL: Set environment variables BEFORE any GPU access
    # WLR_DRM_DEVICES forces the compositor (Niri) to use AMD iGPU only
    # This must be set before Niri starts to prevent NVIDIA detection
    # Note: MST (Multi-Stream Transport) should work with this setting as long as
    # the USB-C/DP port is connected to the AMD card. If MST still doesn't work,
    # try removing this line temporarily to allow MST probing of all cards.
    export WLR_DRM_DEVICES=/dev/dri/$AMD_CARD
    # Prevent Niri from using NVIDIA-specific DRM modifiers
    export WLR_DRM_NO_MODIFIERS=1
    # Allow software rendering fallback if needed
    export WLR_RENDERER_ALLOW_SOFTWARE=1
    
    # Force all applications to use AMD iGPU by default
    # These can be overridden by nvidia-offload wrapper for specific apps
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export DRI_PRIME=0
    export __NV_PRIME_RENDER_OFFLOAD=0
    export __VK_LAYER_NV_optimus=
    # Restrict Vulkan to AMD ICD only - prevents NVIDIA Vulkan ICD from initializing,
    # which would otherwise hold a graphics context open and block NVIDIA runtime suspend
    export VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json
    # Restrict EGL to Mesa only - prevents NVIDIA EGL (libnvidia-eglcore) from loading,
    # which libglvnd would otherwise initialize via 10_nvidia.json when niri sets up its
    # GBM/EGL context, holding /dev/nvidia0 open and blocking NVIDIA runtime suspend
    export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
    
    # Force Xwayland to use AMD iGPU
    # Xwayland is launched by Niri and should inherit WLR_DRM_DEVICES
    # But we'll be explicit to ensure it uses AMD
    # Setting GBM_BACKEND to AMD's render node device path forces Xwayland to use AMD
    export GBM_BACKEND=/dev/dri/$AMD_RENDER
    # Ensure Xwayland uses hardware acceleration on AMD (not software rendering)
    export LIBGL_ALWAYS_SOFTWARE=0
    # Force Mesa to use AMD driver (radeonsi is the modern AMD driver)
    export MESA_LOADER_DRIVER_OVERRIDE=radeonsi
    
    # Additional NVIDIA prevention - prevent NVIDIA libraries from being loaded
    # This helps prevent accidental NVIDIA usage even if detected
    export __GL_SYNC_TO_VBLANK=1
    # Prevent NVIDIA from being selected as default
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    
    # Note: Electron apps like Cursor may still use NVIDIA when they need extra performance
    # This is acceptable - they're being selective about GPU usage
    
    # Set environment for systemd user session (inherited by niri.service and all children)
    # This ensures the environment persists through systemd service startup
    # CRITICAL: Do this BEFORE launching niri-session so child processes inherit it
    systemctl --user set-environment WLR_DRM_DEVICES=/dev/dri/$AMD_CARD
    systemctl --user set-environment WLR_DRM_NO_MODIFIERS=1
    systemctl --user set-environment __GLX_VENDOR_LIBRARY_NAME=mesa
    systemctl --user set-environment DRI_PRIME=0
    systemctl --user set-environment __NV_PRIME_RENDER_OFFLOAD=0
    # Force Xwayland to use AMD iGPU
    systemctl --user set-environment GBM_BACKEND=/dev/dri/$AMD_RENDER
    systemctl --user set-environment MESA_LOADER_DRIVER_OVERRIDE=radeonsi
    systemctl --user set-environment VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json
    systemctl --user set-environment __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json

    # Launch niri-session with AMD iGPU
    # The environment variables should force Niri and Xwayland to use AMD only
    # NVIDIA GPU should power down automatically when not in use
    exec env WLR_DRM_DEVICES=/dev/dri/$AMD_CARD \
            WLR_DRM_NO_MODIFIERS=1 \
            __GLX_VENDOR_LIBRARY_NAME=mesa \
            DRI_PRIME=0 \
            __NV_PRIME_RENDER_OFFLOAD=0 \
            GBM_BACKEND=/dev/dri/$AMD_RENDER \
            MESA_LOADER_DRIVER_OVERRIDE=radeonsi \
            VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json \
            __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json \
            ${pkgs.niri}/bin/niri-session "$@"
  '';
  
  # Custom desktop entry for Niri with AMD iGPU
  # This replaces the default Niri entry to force AMD iGPU usage
  # Note: The wrapper script dynamically detects AMD card/render node, so these env vars
  # are just defaults - the wrapper will override them with correct values
  niri-amd-desktop = pkgs.writeText "niri-amd.desktop" ''
    [Desktop Entry]
    Name=Niri
    Comment=A scrollable-tiling Wayland compositor
    Exec=${niri-amd-wrapper}/bin/niri-session-amd
    Type=Application
    DesktopNames=niri
    X-KDE-Wayland-Environment=WLR_DRM_NO_MODIFIERS=1;__GLX_VENDOR_LIBRARY_NAME=mesa;DRI_PRIME=0;__NV_PRIME_RENDER_OFFLOAD=0;__VK_LAYER_NV_optimus=;MESA_LOADER_DRIVER_OVERRIDE=radeonsi;VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json;__EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
  '';
  
  # Noctalia Shell - using official package.nix approach
  noctalia-shell = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "noctalia-shell";
    version = "4.7.5";

    src = pkgs.fetchFromGitHub {
      owner = "noctalia-dev";
      repo = "noctalia-shell";
      rev = "v4.7.5";
      sha256 = "sha256-0xoCuJSRSWcn4mCX382lCxqLbnuOrrqS4dOcdpoUmZg=";  # v4.7.5 release
    };
    
    nativeBuildInputs = with pkgs; [
      qt6.wrapQtAppsHook
    ];
    
    buildInputs = with pkgs; [
      qt6.qtbase
      qt6.qtmultimedia  # Required for SoundService.qml (QtMultimedia module)
    ];
    
    # Runtime dependencies (from official package.nix)
    runtimeDeps = with pkgs; [
      unstable.noctalia-qs  # The qs binary
      brightnessctl
      cava
      cliphist
      ddcutil
      matugen
      wlsunset
      wl-clipboard
    ] ++ pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
      gpu-screen-recorder
    ];
    
    fontsConf = pkgs.makeFontsConf {
      fontDirectories = [
        pkgs.roboto
        pkgs.inter-nerdfont
      ];
    };
    
    installPhase = ''
      mkdir -p $out/share/noctalia-shell $out/bin
      cp -r . $out/share/noctalia-shell
      ln -s ${unstable.noctalia-qs}/bin/qs $out/bin/noctalia-shell
    '';
    
    preFixup = ''
      qtWrapperArgs+=(
        --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
        --set FONTCONFIG_FILE ${fontsConf}
        --add-flags "-p $out/share/noctalia-shell"
      )
    '';
    
    meta = {
      description = "A sleek and minimal desktop shell for Wayland, built with Quickshell";
      homepage = "https://github.com/noctalia-dev/noctalia-shell";
      license = pkgs.lib.licenses.mit;
      mainProgram = "noctalia-shell";
    };
  };
  
         # Create AMD-optimized Niri session package
         # This forces Niri to use AMD iGPU (card1) instead of NVIDIA (card0)
  # With proprietary NVIDIA drivers, the GPU will automatically power down when not in use
  # This significantly reduces power consumption and fan noise
  niri-amd-session = pkgs.runCommand "niri-amd-session" {
    passthru.providedSessions = [ "niri" ];
    preferLocalBuild = true;
    allowSubstitutes = false;
  } ''
    # Symlink everything from niri package except the desktop entry we'll replace
    mkdir -p $out
    for item in ${pkgs.niri}/*; do
      name=$(basename "$item")
      if [ "$name" != "share" ]; then
        ln -s "$item" "$out/$name"
      fi
    done
    
    # Handle share directory specially - symlink subdirectories but replace wayland-sessions
    if [ -d ${pkgs.niri}/share ]; then
      mkdir -p $out/share
      for item in ${pkgs.niri}/share/*; do
        name=$(basename "$item")
        if [ "$name" != "wayland-sessions" ]; then
          ln -s "$item" "$out/share/$name"
        fi
      done
    fi
    
    # Create wayland-sessions directory and add our custom desktop entry
    mkdir -p $out/share/wayland-sessions
    install -m 644 ${niri-amd-desktop} $out/share/wayland-sessions/niri.desktop
  '';
  
  # Script to auto-enable MST (DisplayPort Multi-Stream Transport) outputs
  # Detects connected but disabled DP outputs and enables them automatically
  # This is needed because MST outputs are detected but not enabled by default
  # 
  # IMPORTANT: This script dynamically detects displays - it does NOT hardcode display names.
  # Display names (DP-9, DP-10, DP-13, etc.) can change after disconnect/reconnect due to MST topology.
  # The script scans all outputs and enables any that are disabled, regardless of their names.
  enable-mst-outputs = pkgs.writeScriptBin "enable-mst-outputs" ''
    #!${pkgs.bash}/bin/bash
    # Auto-enable MST (DisplayPort Multi-Stream Transport) outputs
    # Waits for Niri to start, then enables any connected but disabled DP outputs
    # 
    # This script dynamically detects displays - display names (DP-9, DP-10, etc.) can change
    # after disconnect/reconnect, so we scan all outputs rather than hardcoding names.
    
    # Wait for Niri to be ready (check if WAYLAND_DISPLAY is set or niri process exists)
    MAX_WAIT=30
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
      if [ -n "$WAYLAND_DISPLAY" ] || pgrep -x niri >/dev/null 2>&1; then
        break
      fi
      sleep 1
      WAITED=$((WAITED + 1))
    done
    
    # Additional wait for outputs to be detected (MST topology can take time)
    sleep 3
    
    # Use niri msg output to enable connected but disabled outputs
    # Niri has its own IPC command for output management - wlr-randr doesn't work with Niri
    # NOTE: Some MST outputs may fail to enable via IPC due to DRM errors.
    # In that case, they need to be added to ~/.config/niri/config.kdl manually.
    if command -v niri >/dev/null 2>&1; then
      # Parse niri msg outputs to find disabled outputs
      # Extract output names from parentheses using grep and awk
      niri msg outputs 2>/dev/null | grep -E "\(DP-[0-9]+\)|\(HDMI-[0-9]+\)|\(eDP-[0-9]+\)" | while read -r line; do
        # Extract output name from parentheses using awk (more reliable than sed in Nix strings)
        OUTPUT_NAME=$(echo "$line" | awk -F'[()]' '{for(i=2;i<=NF;i+=2) if($i ~ /^(DP|HDMI|eDP)-[0-9]+$/) print $i}')
        if [ -n "$OUTPUT_NAME" ]; then
          # Check if this output is disabled - use grep to check for "Disabled" in the output block
          # Get the full output block and check if it contains "Disabled" on its own line
          if niri msg outputs 2>/dev/null | grep -A 5 "$OUTPUT_NAME" | grep -q "^[[:space:]]*Disabled$"; then
            echo "Enabling disabled output: $OUTPUT_NAME"
            # Try to enable the output - may need mode set first for MST
            # Set preferred mode first, then enable
            PREFERRED_MODE=$(niri msg outputs 2>/dev/null | grep -A 20 "$OUTPUT_NAME" | grep -oE "[0-9]+x[0-9]+@[0-9.]+" | head -1)
            if [ -n "$PREFERRED_MODE" ]; then
              niri msg output "$OUTPUT_NAME" mode "$PREFERRED_MODE" 2>/dev/null || true
              sleep 0.5
            fi
            # Try to enable - if this fails due to DRM error, the output needs to be in config.kdl
            if ! niri msg output "$OUTPUT_NAME" on 2>/dev/null; then
              echo "WARNING: Failed to enable $OUTPUT_NAME via IPC (DRM error)."
              echo "  Add this to ~/.config/niri/config.kdl:"
              echo "  output \"$OUTPUT_NAME\" {"
              echo "    mode \"$PREFERRED_MODE\""
              echo "  }"
            fi
          fi
        fi
      done
    fi
  '';
in
{
  environment.systemPackages = with pkgs; [
    # niri binaries are needed, but the desktop entry comes from niri-amd-session
    # The session package should take precedence for the desktop entry
    niri
    xwayland-satellite
    unstable.noctalia-qs
    noctalia-shell
    niri-amd-wrapper
    brightness-save-restore
    auto-brightness-sensor  # Auto brightness based on ambient light sensor
    brightnessctl-manual  # Helper to set brightness manually (disables auto-brightness temporarily)
    apply-color-profile  # Apply ASUS DCI P3 ICC color profile for accurate color in DaVinci Resolve
    # Hardware control utilities
    brightnessctl  # For display brightness and keyboard backlight control
    bc  # For floating point calculations in auto-brightness script
    wlsunset  # For nightlight (blue light filter) functionality
    wlr-randr  # Display configuration tool for Wayland (needed for MST output management)
    enable-mst-outputs  # Script to auto-enable MST outputs on Niri startup
    # Power management
    swayidle  # Wayland idle management daemon for auto-dim, lock, and suspend
    # Note: Using Noctalia Shell's built-in lock screen via IPC instead of swaylock
  ] ++ pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
    # gpu-screen-recorder is only available on x86_64-linux
    # It's also included in noctalia-shell runtimeDeps, but adding it here
    # makes it available system-wide for direct use
    gpu-screen-recorder
  ];

  # Replace default Niri session with AMD-optimized version
  # With proprietary NVIDIA drivers, nouveau is automatically blacklisted
  # and the NVIDIA GPU will power down when not in use
  services.displayManager.sessionPackages = [
    niri-amd-session
  ];
  
  # Note: The desktop entry should be provided by niri-amd-session
  # If it's still not working, we may need to check session package priority
  
  # Optional: Use their official NixOS module approach for systemd service
  # This would autostart noctalia-shell with the graphical session
  # Note: Noctalia doesn't need WLR_DRM_DEVICES since it's not a compositor
  # The wrapper script handles GPU selection for Niri (the compositor)
  systemd.user.services.noctalia-shell = {
    description = "Noctalia Shell - Wayland desktop shell";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${noctalia-shell}/bin/noctalia-shell";
      Restart = "on-failure";
      # Include system PATH so Noctalia can find sh, bash, brightnessctl, nmcli, etc.
      # This is critical for brightness detection scripts and other hardware services
      # We need to explicitly include system binaries in PATH since PassEnvironment may not
      # include them if the service starts before the user session is fully initialized
      Environment = [
        "NOCTALIA_SETTINGS_FALLBACK=%h/.config/noctalia/gui-settings.json"
        # Force Mesa/AMD for rendering (not critical for Noctalia, but helps with consistency)
        "__GLX_VENDOR_LIBRARY_NAME=mesa"
        "DRI_PRIME=0"
        "__NV_PRIME_RENDER_OFFLOAD=0"
        "__VK_LAYER_NV_optimus="
        # Explicitly add system PATH to ensure sh, brightnessctl, nmcli, gpu-screen-recorder, etc. are found
        # This ensures critical system binaries are available even if user session PATH isn't set yet
        # /run/current-system/sw/bin includes all system packages (brightnessctl, nmcli, sh, gpu-screen-recorder, etc.)
        # Also include the noctalia-shell wrapper's PATH which includes runtimeDeps (gpu-screen-recorder is in runtimeDeps)
        # Note: PassEnvironment will append user session PATH, but system PATH takes precedence
        "PATH=/run/wrappers/bin:${pkgs.lib.makeBinPath (with pkgs; [
          unstable.noctalia-qs
          brightnessctl
          cava
          cliphist
          ddcutil
          matugen
          wlsunset
          wl-clipboard
        ] ++ pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
          gpu-screen-recorder
        ])}:/run/current-system/sw/bin:/run/current-system/sw/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
      ];
      # Pass PATH from the user session so Noctalia can find system binaries
      # This is required for brightness detection scripts and other hardware services
      # The system PATH above ensures critical binaries are always available
      PassEnvironment = [ "PATH" ];
    };
  };
  
  # Auto-enable MST outputs service
  # Runs after Niri starts to enable any connected but disabled MST outputs
  # This fixes the issue where MST daisy-chained monitors are detected but not enabled
  # IMPORTANT: Script dynamically detects displays - names (DP-9, DP-10, etc.) can change
  # after disconnect/reconnect, so it scans all outputs rather than hardcoding names.
  systemd.user.services.enable-mst-outputs = {
    description = "Enable MST (DisplayPort Multi-Stream Transport) outputs";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    # Wait a bit longer to ensure Niri is fully initialized
    serviceConfig = {
      ExecStart = "${enable-mst-outputs}/bin/enable-mst-outputs";
      Type = "oneshot";
      RemainAfterExit = false;
    };
  };
  
  # Path unit to re-run MST enable script when displays are hotplugged
  # This handles disconnect/reconnect scenarios where display names may change
  # Monitors /sys/class/drm for display connection changes
  # Note: Display names (DP-9, DP-10, DP-13, etc.) can change after reconnect due to MST topology
  systemd.user.paths.enable-mst-outputs-on-hotplug = {
    description = "Monitor for display hotplug events";
    wantedBy = [ "graphical-session.target" ];
    pathConfig = {
      # Monitor for changes in DRM connector status files
      # This triggers when displays are connected/disconnected
      # Note: Wildcards in paths require MakeDirectory=yes or systemd may not detect changes
      PathChanged = "/sys/class/drm";
    };
  };
  
  # Service triggered by the path unit above
  # Re-runs the MST enable script when displays are connected/disconnected
  # The script dynamically detects all outputs, so it works even if names changed
  systemd.user.services.enable-mst-outputs-on-hotplug = {
    description = "Enable MST outputs after display hotplug";
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c 'sleep 2 && ${enable-mst-outputs}/bin/enable-mst-outputs'";
      Type = "oneshot";
    };
  };

  # Nightlight service using wlsunset
  # Automatically adjusts screen color temperature based on time of day
  # Uses location-based sunrise/sunset times or manual schedule
  systemd.user.services.wlsunset = {
    description = "wlsunset - Nightlight (blue light filter) for Wayland";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      # wlsunset will automatically detect sunrise/sunset times based on location
      # Default: 6500K (day) to 4000K (night), transitions over 1 hour
      # You can customize these values or add location with -l LAT,LON
      ExecStart = "${pkgs.wlsunset}/bin/wlsunset";
      Restart = "on-failure";
      RestartSec = 5;
      # Pass Wayland environment variables
      PassEnvironment = [ "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" "XDG_SESSION_TYPE" ];
    };
  };

  # Auto brightness service based on ambient light sensor
  # Polls sensor every 3 seconds and adjusts screen/keyboard brightness
  # Includes automatic manual override detection (30-second cooldown)
  # Automatically detects manual brightness changes from any source (keyboard, widget, CLI)
  # Pauses when power saving dims the screen
  systemd.user.timers.auto-brightness-sensor = {
    description = "Auto brightness sensor timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnActiveSec = "3s";      # Run immediately
      OnUnitActiveSec = "3s";  # Then every 3 seconds
      AccuracySec = "1s";
    };
  };

  systemd.user.services.auto-brightness-sensor = {
    description = "Auto brightness based on ambient light sensor";
    serviceConfig = {
      ExecStart = "${auto-brightness-sensor}/bin/auto-brightness-sensor";
      Type = "oneshot";
      # Pass Wayland environment variables (not critical for sensor reads, but good practice)
      PassEnvironment = [ "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" "XDG_SESSION_TYPE" ];
      # Include system PATH for brightnessctl
      Environment = [
        "PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
      ];
    };
  };

  # Power management service using swayidle
  # Handles auto-dim, screen lock, and suspend on idle
  # Timers:
  #   - 3 minutes: Dim screen to 10% (saves current brightness first)
  #   - 5 minutes: Lock screen with swaylock
  #   - 15 minutes: Suspend system
  # Integrates with auto-brightness by disabling it during dimming
  systemd.user.services.swayidle = {
    description = "swayidle - Wayland idle management daemon";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      # swayidle configuration:
      # -w: Wait for idle events (required for Wayland)
      # timeout 180: After 3 minutes of inactivity, dim screen to 10%
      #   - Save current brightness before dimming
      #   - Dim to 10% brightness
      #   - On resume (user input), restore saved brightness
      # timeout 300: After 5 minutes of inactivity, lock screen
      #   - Lock screen using Noctalia Shell's built-in lock screen (via IPC)
      # timeout 900: After 15 minutes of inactivity, suspend system
      #   - Before suspend, save brightness (in case dimmed)
      #   - Lock screen before suspend (using Noctalia Shell's lock screen)
      #   - Suspend using systemctl suspend (system-level suspend command, requires polkit permissions)
      ExecStart = "${swayidle-start}";
      Restart = "on-failure";
      RestartSec = 5;
      # Pass Wayland environment variables required for swayidle and Noctalia IPC
      PassEnvironment = [ "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" "XDG_SESSION_TYPE" ];
      # Include system PATH for brightnessctl and systemctl
      Environment = [
        "PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
      ];
    };
  };
  
  # Color profile application service
  # Applies ASUS DCI P3 ICC profile to display for accurate color in DaVinci Resolve
  # Ensures proper color representation for sRGB, Rec709, and 10-bit P3 color spaces
  # Note: This service exits gracefully if display isn't registered yet (common in Niri)
  # The profile will be applied when the display is registered (e.g., via GNOME)
  systemd.user.services.apply-color-profile = {
    description = "Apply ASUS DCI P3 ICC color profile to display";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    # Don't require colord - it may not be ready or display may not be registered
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${apply-color-profile}/bin/apply-color-profile";
      # Don't restart on failure - script exits gracefully if display isn't registered
      Restart = "no";
      # Pass Wayland environment variables
      PassEnvironment = [ "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" "XDG_SESSION_TYPE" ];
      # Include system PATH for colormgr and dbus-send
      Environment = [
        "PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
      ];
    };
  };
}

