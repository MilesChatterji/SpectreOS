# GPU Offloading Configuration with Proprietary NVIDIA Drivers
# Use AMD 890M iGPU by default, NVIDIA only when explicitly requested via nvidia-offload
# This reduces power consumption significantly
# System: AMD Ryzen AI 9 HX 370 with Radeon 890M (card1/amdgpu) + NVIDIA discrete (card0/nvidia)
#
# NOTE (2025-02-07): NVIDIA driver is pulled from nixos-unstable (580.126.18+) so it builds
# on kernel 6.19.x. Stable channel (e.g. 25.11) still had 580.119.02 which does not build on 6.19.
# Only this package comes from unstable; rest of system stays on your channel.
# TODO: When your NixOS channel has nvidia 580.126.18+ in stable, revert to:
#   package = config.boot.kernelPackages.nvidiaPackages.production;
# and remove the unstable fetch/import and unstableNvidiaPackages in the let block below.

{ config, pkgs, ... }:

let
  # Import nixpkgs-unstable only for the NVIDIA driver (580.126.18+).
  # The driver is built against your current kernel (config.boot.kernelPackages)
  # so the rest of the system stays on your channel (e.g. 25.11).
  unstableSrc = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
    # Omit sha256 to track latest unstable; add sha256 to pin to a specific tarball.
  };
  unstable = import unstableSrc {
    config.allowUnfree = true;
    inherit (config.nixpkgs) system;
  };
  # nvidia-x11 gets kernel from the package set via internal callPackage. The top-level
  # unstable set has no "kernel"; we override callPackage so every call injects our kernel.
  ourKernel = config.boot.kernelPackages.kernel;
  # Inject kernel when the called function has a 'kernel' argument.
  # Only pass our callPackage when calling the top-level nvidia-x11 default.nix, so inner
  # callPackage (e.g. settings.nix) are not given unexpected 'callPackage'.
  nvidiaX11Path = unstableSrc + "/pkgs/os-specific/linux/nvidia-x11";
  unstableWithOurKernel = unstable // {
    kernel = ourKernel;
    callPackage = fn: args:
      let
        inject = if builtins.isFunction fn && builtins.functionArgs fn ? kernel then { kernel = ourKernel; } else { };
        passOurCallPackage = if fn == nvidiaX11Path then { callPackage = unstableWithOurKernel.callPackage; } else { };
        args' = args // inject // passOurCallPackage;
      in
      unstable.callPackage fn args';
  };
  unstableNvidiaPackages = unstableWithOurKernel.callPackage (unstableSrc + "/pkgs/os-specific/linux/nvidia-x11") { };

  # NVIDIA offload wrapper script
  # Use this to run applications on the NVIDIA GPU instead of AMD iGPU
  # Example: nvidia-offload davinci-resolve
  nvidia-offload = pkgs.writeScriptBin "nvidia-offload" ''
    #!${pkgs.bash}/bin/bash
    # NVIDIA PRIME offload wrapper
    # Forces applications to use NVIDIA GPU instead of AMD iGPU
    
    # Preserve audio environment variables (for PipeWire/PulseAudio)
    # These are needed for applications that use audio (DaVinci Resolve, etc.)
    if [ -n "$XDG_RUNTIME_DIR" ]; then
      export XDG_RUNTIME_DIR
      export PIPEWIRE_RUNTIME_DIR="$XDG_RUNTIME_DIR"
      export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"
      # Set PULSE_SERVER for PulseAudio compatibility (PipeWire emulates PulseAudio)
      export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
    fi
    # ALSA configuration - route through PulseAudio/PipeWire
    # DaVinci Resolve uses ALSA directly, so we need to ensure it routes through PipeWire
    # Force PulseAudio as the default PCM device
    export ALSA_PCM_NAME=pulse
    # Set ALSA plugin directory so ALSA can find the PulseAudio plugin
    # This is needed for FHS environments (like DaVinci Resolve) that may not have
    # the plugin in their default library search path
    export ALSA_PLUGIN_DIR="${pkgs.alsa-plugins}/lib/alsa-lib"
    # Ensure ALSA library can find the PulseAudio plugin
    # Add alsa-plugins to library path so the plugin is accessible from FHS environment
    # Prepend to preserve any existing library paths (important for FHS environments)
    if [ -z "$LD_LIBRARY_PATH" ]; then
      export LD_LIBRARY_PATH="${pkgs.alsa-plugins}/lib"
    else
      export LD_LIBRARY_PATH="${pkgs.alsa-plugins}/lib:$LD_LIBRARY_PATH"
    fi
    # Note: The FHS environment should have its own library paths set up
    # We're only adding the alsa-plugins path, not replacing the entire LD_LIBRARY_PATH
    
    # NVIDIA PRIME render offload (for modern applications)
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only

    # Legacy DRI_PRIME for older applications
    export DRI_PRIME=1

    # Force NVIDIA for Xwayland applications
    export GBM_BACKEND=nvidia-drm

    # Re-enable NVIDIA EGL and Vulkan ICDs (session defaults restrict these to AMD-only)
    unset __EGL_VENDOR_LIBRARY_FILENAMES
    unset VK_ICD_FILENAMES
    
    # Execute the command with NVIDIA GPU
    exec "$@"
  '';
  
  # AMD-only wrapper script
  # Use this to force applications to use AMD iGPU only
  # Useful for Electron apps (Cursor, etc.) that might auto-detect NVIDIA
  amd-only = pkgs.writeScriptBin "amd-only" ''
    #!${pkgs.bash}/bin/bash
    # Force AMD iGPU only - prevents applications from using NVIDIA
    
    # Force AMD for all rendering
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export DRI_PRIME=0
    export __NV_PRIME_RENDER_OFFLOAD=0
    export __VK_LAYER_NV_optimus=
    
    # Force Mesa to use AMD driver (radeonsi is the modern AMD driver)
    export MESA_LOADER_DRIVER_OVERRIDE=radeonsi
    # Ensure hardware acceleration on AMD (not software rendering)
    export LIBGL_ALWAYS_SOFTWARE=0
    
    # Note: GBM_BACKEND should NOT be set to a device path for Electron apps
    # MESA interprets it incorrectly and tries to construct invalid library paths
    # Instead, rely on DRI_PRIME=0 and MESA_LOADER_DRIVER_OVERRIDE to force AMD
    
    # For Electron/Chromium apps, disable NVIDIA GPU detection
    # These flags force Electron to use the integrated GPU (AMD)
    export ELECTRON_DISABLE_SANDBOX=1
    # Disable NVIDIA-specific optimizations
    export ELECTRON_USE_ANGLE=0
    
    # For Chromium-based apps, force EGL rendering on AMD
    # Use --use-gl=egl to force EGL (works better with Wayland)
    export CHROMIUM_FLAGS="--use-gl=egl --disable-gpu-sandbox"
    
    # If crashes persist, try disabling GPU acceleration entirely:
    # export ELECTRON_DISABLE_GPU=1
    # export CHROMIUM_FLAGS="--disable-gpu"
    
    # Execute the command with AMD iGPU only
    exec "$@"
  '';
in
{
  # Enable AMD graphics (iGPU) - this should be primary
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  
  # Configure proprietary NVIDIA drivers
  # This automatically blacklists nouveau and provides better power management
  # Note: hardware.nvidia.enabled is read-only and set automatically when videoDrivers includes "nvidia"
  
  # Enable NVIDIA as a video driver (required even for Wayland/Xwayland)
  services.xserver.videoDrivers = [ "nvidia" ];
  
  hardware.nvidia = {
    # Use proprietary drivers, not open-source nouveau
    open = false;
    
    # Disable modesetting to prevent NVIDIA from being initialized for display
    # This forces Wayland compositors (Niri) to use AMD iGPU for the internal display
    # NVIDIA can still be used for compute/rendering via nvidia-offload (PRIME offload)
    # Testing: GNOME may still work, but if it breaks, rollback with: nixos-rebuild switch --rollback
    # This should reduce power consumption in Niri and fix brightness controls
    # 
    # NOTE: If DP-MST (daisy-chained monitors) doesn't work and your USB-C port
    # is connected to NVIDIA, you may need to temporarily enable modesetting:
    # modesetting.enable = true;
    # This will allow NVIDIA to handle display output, which may be needed for MST.
    modesetting.enable = false;
    
    # Enable power management (allows GPU to power down when not in use)
    powerManagement.enable = true;
    # Note: powerManagement.finegrained requires hardware.nvidia.prime.offload.enable,
    # which needs explicit PCI bus IDs. RTD3 is instead enabled manually below via
    # boot.extraModprobeConfig and services.udev.extraRules.
    
    # Enable support for 32-bit applications (needed for some games/apps)
    nvidiaSettings = true;
    
    # Use production driver from nixpkgs-unstable (580.126.18+) built for current kernel.
    # See NOTE at top of file (2025-02-07): revert to .nvidiaPackages.production when stable has it.
    package = unstableNvidiaPackages.production;
  };
  
  # Set environment variables for PRIME offloading
  # Use AMD 890M iGPU by default, NVIDIA via nvidia-offload wrapper
  # These variables prevent applications from using NVIDIA by default
  environment.sessionVariables = {
    # Use AMD 890M iGPU by default (Mesa drivers)
    __GLX_VENDOR_LIBRARY_NAME = "mesa";
    # Force AMD for DRI-based applications (0 = AMD, 1 = NVIDIA)
    DRI_PRIME = "0";
    # Disable NVIDIA PRIME render offload by default
    # Applications can override this via nvidia-offload wrapper
    __NV_PRIME_RENDER_OFFLOAD = "0";
    # Disable NVIDIA Vulkan layer by default
    __VK_LAYER_NV_optimus = "";
  };
  
  # For Wayland compositors (Niri), set environment to prefer AMD iGPU
  # The compositor will use the AMD iGPU by default
  # Apps can request NVIDIA via: nvidia-offload app-name
  
  # Add GPU offload wrappers to system packages
  environment.systemPackages = [ nvidia-offload amd-only ];
  
  # Usage:
  # - Use 'nvidia-offload app-name' to run an app on NVIDIA GPU (for performance)
  # - Use 'amd-only app-name' to force an app to use AMD iGPU only (for power saving)
  # Note: Cursor and other Electron apps can use NVIDIA when they need extra performance
  # Xwayland is configured to use AMD iGPU by default (see niri.nix)
  
  # Note: nouveau is automatically blacklisted when proprietary drivers are enabled
  # The NVIDIA GPU will power down when not in use, saving significant power

  # Enable NVIDIA RTD3 (runtime D3) power management manually.
  # This is what hardware.nvidia.powerManagement.finegrained does internally,
  # but that option requires hardware.nvidia.prime.offload.enable (and bus IDs).
  # Since we use environment-variable-based offload instead of NixOS's PRIME module,
  # we replicate the effect directly here.
  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x02
  '';

  services.udev.extraRules = ''
    # Allow NVIDIA GPU (VGA/3D controller/Audio/USB) to runtime suspend when idle
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", TEST=="power/control", ATTR{power/control}="auto"
  '';
}

