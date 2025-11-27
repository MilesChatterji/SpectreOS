# Niri Wayland Compositor configuration with Noctalia Shell
# Based on official noctalia-shell package.nix approach
# https://github.com/noctalia-dev/noctalia-shell/tree/main/nix

{ config, pkgs, ... }:

let
  unstable = import <unstable> { config.allowUnfree = true; };
  
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
    # Hardware control utilities
    brightnessctl  # For display brightness and keyboard backlight control
    wlsunset  # For nightlight (blue light filter) functionality
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
}

