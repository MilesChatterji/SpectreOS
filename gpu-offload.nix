# GPU Offloading Configuration with Proprietary NVIDIA Drivers
# Use AMD 890M iGPU by default, NVIDIA only when explicitly requested via nvidia-offload
# This reduces power consumption significantly
# System: AMD Ryzen AI 9 HX 370 with Radeon 890M (card1/amdgpu) + NVIDIA discrete (card0/nvidia)
#
# NOTE: NVIDIA driver from NixOS 26.05 stable channel — nvidiaPackages.stable resolves to
# 595.x in 26.05. Previously pulled from nixos-unstable for 595.x power management; no
# longer needed since stable caught up. The .mod split from the unstable era is gone.
#
# ASUS PX13 HARDWARE NOTE — OS-BUILDER: This file is specific to the ASUS ProArt PX13
# (AMD Ryzen AI 9 HX 370 + NVIDIA dGPU). Do NOT include supergfxd or this GPU offload
# configuration in the SpectreOS base image or VM images. It should be an optional
# hardware profile applied only on supported ASUS hybrid-GPU laptops.

{ config, pkgs, ... }:

let
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
    # Expose NVIDIA userspace libs (libnvidia-ml, libcuda, libEGL_nvidia, etc.)
    # to processes inside the FHS container. The FHS rootfs has no NVIDIA libs bundled,
    # and /run/opengl-driver/lib is not in its ld.so.conf, so GPUDetect cannot load
    # libnvidia-ml.so on Wayland (no X11 logs fallback) without this path.
    # Safe to prepend: /run/opengl-driver/lib has only NVIDIA-specific libs, not the
    # generic libGL.so.1/libEGL.so.1 dispatch stubs that the FHS provides via glvnd.
    if [ -z "$LD_LIBRARY_PATH" ]; then
      export LD_LIBRARY_PATH="/run/opengl-driver/lib:${pkgs.alsa-plugins}/lib"
    else
      export LD_LIBRARY_PATH="/run/opengl-driver/lib:${pkgs.alsa-plugins}/lib:$LD_LIBRARY_PATH"
    fi
    
    # NVIDIA PRIME render offload (for modern applications)
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only

    # Legacy DRI_PRIME for older applications
    export DRI_PRIME=1

    # Force NVIDIA for Xwayland applications
    export GBM_BACKEND=nvidia-drm

    # Re-enable NVIDIA EGL and Vulkan ICDs.
    # niri.nix pins these to AMD-only so the NVIDIA GPU can RTD3 power-down when idle.
    # Unsetting is not enough: GLVND falls back to XDG_DATA_DIRS scanning, and
    # /run/opengl-driver/share is not in XDG_DATA_DIRS, so the NVIDIA ICD is never found.
    # Must explicitly point to the NVIDIA ICD paths inside /run/opengl-driver.
    export __EGL_VENDOR_LIBRARY_FILENAMES="/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json"
    export VK_ICD_FILENAMES="/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json"
    
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
    
    # 595.x from NixOS 26.05 stable. nvidiaPackages.stable tracks the NVIDIA stable branch.
    package = pkgs.linuxKernel.packages.linux_7_0.nvidiaPackages.stable;
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

  # NVreg_DynamicPowerManagement=0x02 requests fine-grained power management from the
  # nvidia driver. RTD3 (D3cold) is not supported on PX13 firmware (no _PR3 ACPI method),
  # so the driver will not actually enter D3cold — this is a no-op but harmless to keep.
  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x02
    # Disable PP_GFXOFF to work around an amdgpu idle power regression introduced in
    # kernel 6.18 where PP_GFXOFF misbehaves and doubles GPU idle draw on some platforms.
    options amdgpu ppfeaturemask=0xffff7fff
  '';

  services.udev.extraRules = ''
    # Allow NVIDIA GPU (VGA/3D controller/Audio/USB) to runtime suspend when idle
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", TEST=="power/control", ATTR{power/control}="auto"
    # Keep the PCIe root port for the NVIDIA GPU (0000:00:03.1, bus c4) from runtime-suspending.
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:03.1", ATTR{power/control}="on"
  '';

  # ASUS GPU switching daemon.
  # This platform's firmware does not support NVIDIA RTD3 (D3cold), so the GPU
  # sits at ~6W in P8 idle when NVIDIA modules are loaded regardless of driver config.
  # supergfxd in Integrated mode unloads the driver, dropping to ~0W draw.
  #
  # Default mode: Integrated (0W GPU draw — switch to Hybrid when NVIDIA needed).
  # hotplug_type = "None": PX13 exposes neither dgpu_disable WMI (Asus type) nor a
  # working PCIe hotplug slot power path (Std type). None skips power cycling entirely
  # and lets supergfxd manage only module load/unload. The GPU stays physically powered
  # on from firmware; the udev rules above keep it from entering D3cold prematurely.
  # Use nvidia-offload <app> to run applications on the NVIDIA GPU.
  # For battery travel: supergfxctl -m Integrated → logout/login before unplugging.
  # This config resets to Hybrid on nixos-rebuild; change mode here to persist Integrated.
  #
  # OS-BUILDER: supergfxd is ASUS-specific. Exclude from base and VM images.
  boot.kernelModules = [ "asus_nb_wmi" ];
  services.supergfxd = {
    enable = true;
    settings = {
      mode = "Integrated";
      vfio_enable = false;
      vfio_save = false;
      compute_save = false;
      always_reboot = false;
      no_logind = false;
      logout_timeout_s = 180;
      hotplug_type = "None";
    };
  };
}

