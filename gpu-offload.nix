# GPU Offloading Configuration with Proprietary NVIDIA Drivers
# Use AMD 890M iGPU by default, NVIDIA only when explicitly requested via nvidia-offload
# This reduces power consumption significantly
# System: AMD Ryzen AI 9 HX 370 with Radeon 890M (card1/amdgpu) + NVIDIA discrete (card0/nvidia)

{ config, pkgs, ... }:

let
  # NVIDIA offload wrapper script
  # Use this to run applications on the NVIDIA GPU instead of AMD iGPU
  # Example: nvidia-offload davinci-resolve
  nvidia-offload = pkgs.writeScriptBin "nvidia-offload" ''
    #!${pkgs.bash}/bin/bash
    # NVIDIA PRIME offload wrapper
    # Forces applications to use NVIDIA GPU instead of AMD iGPU
    
    # NVIDIA PRIME render offload (for modern applications)
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    
    # Legacy DRI_PRIME for older applications
    export DRI_PRIME=1
    
    # Force NVIDIA for Xwayland applications
    export GBM_BACKEND=nvidia-drm
    
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
    modesetting.enable = false;
    
    # Enable power management (allows GPU to power down when not in use)
    powerManagement.enable = true;
    
    # Enable support for 32-bit applications (needed for some games/apps)
    nvidiaSettings = true;
    
    # Package set - use the latest stable drivers
    package = config.boot.kernelPackages.nvidiaPackages.stable;
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
}

