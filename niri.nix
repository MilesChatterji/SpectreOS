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
  # Reads sensor from /sys/devices/.../iio:device2/in_illuminance_raw
  # Maps lux values to brightness percentages with hysteresis to prevent flickering
  # Includes manual override protection (30-second cooldown after manual changes)
  # Pauses when power saving dims the screen
  auto-brightness-sensor = pkgs.writeScriptBin "auto-brightness-sensor" ''
    #!${pkgs.bash}/bin/bash
    # Auto brightness based on ambient light sensor
    
    # Sensor path (HID-SENSOR-200041.6.auto/iio:device2)
    SENSOR_BASE="/sys/devices/0020:1022:0001.0009/HID-SENSOR-200041.6.auto/iio:device2"
    RAW_FILE="''$SENSOR_BASE/in_illuminance_raw"
    SCALE_FILE="''$SENSOR_BASE/in_illuminance_scale"
    
    # Manual override protection
    MANUAL_BRIGHTNESS_FILE="''$HOME/.cache/manual-brightness-time"
    COOLDOWN=30  # seconds
    
    # Power saving integration - pause if screen is dimmed
    AUTO_BRIGHTNESS_DISABLED_FILE="/tmp/auto-brightness-disabled"
    if [ -f "''$AUTO_BRIGHTNESS_DISABLED_FILE" ]; then
      exit 0  # Skip adjustment when power saving has dimmed screen
    fi
    
    # Check if user manually changed brightness recently
    if [ -f "''$MANUAL_BRIGHTNESS_FILE" ]; then
      MANUAL_TIME=$(stat -c %Y "''$MANUAL_BRIGHTNESS_FILE" 2>/dev/null || echo "0")
      NOW=$(date +%s)
      if [ $((NOW - MANUAL_TIME)) -lt ''$COOLDOWN ]; then
        exit 0  # Skip auto adjustment during cooldown
      fi
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
    
    # Get current brightness to implement hysteresis (only adjust if change > 5%)
    CURRENT_RAW=$(${pkgs.brightnessctl}/bin/brightnessctl --class=backlight get 2>/dev/null || echo "0")
    CURRENT_MAX=$(${pkgs.brightnessctl}/bin/brightnessctl --class=backlight max 2>/dev/null || echo "100")
    CURRENT_PERCENT=$((CURRENT_RAW * 100 / CURRENT_MAX))
    
    # Only adjust if change is significant (hysteresis: 5% threshold)
    DIFF=$((TARGET_BRIGHTNESS - CURRENT_PERCENT))
    if [ ''${DIFF#-} -lt 5 ]; then
      exit 0  # Change too small, skip adjustment
    fi
    
    # Set screen brightness
    ${pkgs.brightnessctl}/bin/brightnessctl --class=backlight set "''$TARGET_BRIGHTNESS%"
    
    # Set keyboard backlight (inverted: bright screen = dim keyboard, dim screen = bright keyboard)
    # User preference: Level 1 (first level) for dark conditions, never use brightest settings
    ${pkgs.brightnessctl}/bin/brightnessctl --class=leds --device=asus::kbd_backlight set "''$TARGET_KBD_BRIGHTNESS" 2>/dev/null || true
  '';
  
  # Helper script to manually set brightness and disable auto-brightness temporarily
  # Usage: brightnessctl-manual set 50% (or any brightnessctl command)
  # This marks the change as manual, preventing auto-brightness from overriding for 30 seconds
  brightnessctl-manual = pkgs.writeScriptBin "brightnessctl-manual" ''
    #!${pkgs.bash}/bin/bash
    # Helper to set brightness manually and disable auto-brightness temporarily
    
    # Call brightnessctl with all arguments
    ${pkgs.brightnessctl}/bin/brightnessctl "$@"
    
    # Mark as manual change (touches timestamp file)
    touch "$HOME/.cache/manual-brightness-time" 2>/dev/null || true
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
      timeout 300 '${unstable.quickshell}/bin/qs -p ${noctalia-shell}/share/noctalia-shell ipc call lockScreen lock' \
      timeout 900 '${brightness-save-restore}/bin/brightness-save-restore save && ${pkgs.systemd}/bin/systemctl --user suspend' \
        before-sleep '${unstable.quickshell}/bin/qs -p ${noctalia-shell}/share/noctalia-shell ipc call lockScreen lock'
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
    fi
    
    # CRITICAL: Set environment variables BEFORE any GPU access
    # WLR_DRM_DEVICES forces the compositor (Niri) to use AMD iGPU only
    # This must be set before Niri starts to prevent NVIDIA detection
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
    # Don't restrict VK_ICD_FILENAMES - let Vulkan auto-detect drivers
    # The other environment variables (DRI_PRIME, __GLX_VENDOR_LIBRARY_NAME) will guide GPU selection
    # This allows applications to find the right drivers while preferring AMD
    
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
    X-KDE-Wayland-Environment=WLR_DRM_NO_MODIFIERS=1;__GLX_VENDOR_LIBRARY_NAME=mesa;DRI_PRIME=0;__NV_PRIME_RENDER_OFFLOAD=0;__VK_LAYER_NV_optimus=;MESA_LOADER_DRIVER_OVERRIDE=radeonsi
  '';
  
  # Noctalia Shell - using official package.nix approach
  noctalia-shell = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "noctalia-shell";
    version = "0.1.0";
    
    src = pkgs.fetchFromGitHub {
      owner = "noctalia-dev";
      repo = "noctalia-shell";
      rev = "main";
      sha256 = "sha256-pWz6IWgG614EoVxPY6tlEsurZMznBvbyliI3go1BAuY=";
    };
    
    nativeBuildInputs = with pkgs; [
      qt6.wrapQtAppsHook
    ];
    
    buildInputs = with pkgs; [
      qt6.qtbase
    ];
    
    # Runtime dependencies (from official package.nix)
    runtimeDeps = with pkgs; [
      unstable.quickshell  # The qs binary
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
      ln -s ${unstable.quickshell}/bin/qs $out/bin/noctalia-shell
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
in
{
  environment.systemPackages = with pkgs; [
    # niri binaries are needed, but the desktop entry comes from niri-amd-session
    # The session package should take precedence for the desktop entry
    niri
    xwayland-satellite
    unstable.quickshell
    noctalia-shell
    niri-amd-wrapper
    brightness-save-restore
    auto-brightness-sensor  # Auto brightness based on ambient light sensor
    brightnessctl-manual  # Helper to set brightness manually (disables auto-brightness temporarily)
    # Hardware control utilities
    brightnessctl  # For display brightness and keyboard backlight control
    bc  # For floating point calculations in auto-brightness script
    wlsunset  # For nightlight (blue light filter) functionality
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
        # Explicitly add system PATH to ensure sh, brightnessctl, nmcli, etc. are found
        # This ensures critical system binaries are available even if user session PATH isn't set yet
        # /run/current-system/sw/bin includes all system packages (brightnessctl, nmcli, sh, etc.)
        # Note: PassEnvironment will append user session PATH, but system PATH takes precedence
        "PATH=/run/current-system/sw/bin:/run/current-system/sw/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
      ];
      # Pass PATH from the user session so Noctalia can find system binaries
      # This is required for brightness detection scripts and other hardware services
      # The system PATH above ensures critical binaries are always available
      PassEnvironment = [ "PATH" ];
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
  # Includes manual override protection (30-second cooldown)
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
      #   - Suspend using systemctl
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
}

