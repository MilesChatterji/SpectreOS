# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:
let 
   unstable = import <unstable> { config.allowUnfree = true; };
   
   # Custom SpectreOS Plymouth theme - Step 2: Logo + Progress Bars
   spectreos-plymouth-theme = pkgs.runCommand "spectreos-plymouth-theme" {
     splashImage = builtins.path {
       path = /etc/nixos/assets/logo.png;
       name = "spectreos-logo.png";
     };
     progressBox = builtins.path {
       path = /etc/nixos/assets/progress_box.png;
       name = "progress_box.png";
     };
     progressBar = builtins.path {
       path = /etc/nixos/assets/progress_bar.png;
       name = "progress_bar.png";
     };
   } ''
     mkdir -p $out/share/plymouth/themes/spectreos
     
     # Copy all images
     cp $splashImage $out/share/plymouth/themes/spectreos/logo.png
     cp $progressBox $out/share/plymouth/themes/spectreos/progress_box.png
     cp $progressBar $out/share/plymouth/themes/spectreos/progress_bar.png
     
     # Create theme configuration file
     cat > $out/share/plymouth/themes/spectreos/spectreos.plymouth <<EOF
     [Plymouth Theme]
     Name=SpectreOS
     Description=SpectreOS Boot Splash
     ModuleName=script
     
     [script]
     ImageDir=$out/share/plymouth/themes/spectreos
     ScriptFile=$out/share/plymouth/themes/spectreos/spectreos.script
     EOF
     
     # Create script to display logo and progress bars
     cat > $out/share/plymouth/themes/spectreos/spectreos.script <<'SCRIPT'
     # SpectreOS Plymouth Theme Script
     
     # Set background to black
     Window.SetBackgroundTopColor(0.00, 0.00, 0.00);
     Window.SetBackgroundBottomColor(0.00, 0.00, 0.00);
     
     # Load images and create sprites immediately (at script load time)
     logo.image = Image("logo.png");
     logo.sprite = Sprite(logo.image);
     
     progress_box.image = Image("progress_box.png");
     progress_box.sprite = Sprite(progress_box.image);
     
     progress_bar.original_image = Image("progress_bar.png");
     progress_bar.image = progress_bar.original_image;
     progress_bar.sprite = Sprite(progress_bar.image);
     
     # Immediately set opacity to ensure sprites are visible
     logo.sprite.SetOpacity(1);
     progress_box.sprite.SetOpacity(1);
     progress_bar.sprite.SetOpacity(1);
     
     # Function to position all elements
     fun refresh_callback() {
       screen_width = Window.GetWidth();
       screen_height = Window.GetHeight();
       
       # Only position if we have valid dimensions
       if (screen_width > 0 && screen_height > 0) {
         # Center the logo vertically and horizontally
         logo_width = logo.image.GetWidth();
         logo_height = logo.image.GetHeight();
         logo_x = Window.GetX() + (screen_width - logo_width) / 2;
         logo_y = Window.GetY() + (screen_height - logo_height) / 2 - 100; # Slightly above center
         logo.sprite.SetPosition(logo_x, logo_y, 1000);
         logo.sprite.SetOpacity(1);
         
         # Position progress box: centered horizontally, near bottom of screen for visibility
         progress_box_width = progress_box.image.GetWidth();
         progress_box_height = progress_box.image.GetHeight();
         progress_box_x = Window.GetX() + (screen_width - progress_box_width) / 2;
         # Place at bottom of screen with some padding
         progress_box_y = Window.GetY() + screen_height - progress_box_height - 100;
         
         # Store box position for progress bar positioning
         progress_box.x = progress_box_x;
         progress_box.y = progress_box_y;
         
         progress_box.sprite.SetPosition(progress_box_x, progress_box_y, 2000);
         progress_box.sprite.SetOpacity(1);
         
         # Position progress bar: centered inside the box
         # Use current scaled width (or original if not scaled yet)
         current_bar_width = progress_bar.image.GetWidth();
         current_bar_height = progress_bar.image.GetHeight();
         box_padding_x = (progress_box_width - current_bar_width) / 2;
         box_padding_y = (progress_box_height - current_bar_height) / 2;
         progress_bar_x = progress_box_x + box_padding_x;
         progress_bar_y = progress_box_y + box_padding_y;
         progress_bar.sprite.SetPosition(progress_bar_x, progress_bar_y, 3000);
         progress_bar.sprite.SetOpacity(1);
       } else {
         # If dimensions not available, use fixed positions for testing
         logo.sprite.SetPosition(100, 100, 1000);
         logo.sprite.SetOpacity(1);
         progress_box.sprite.SetPosition(100, 600, 2000);
         progress_box.sprite.SetOpacity(1);
         progress_bar.sprite.SetPosition(100, 650, 3000);
         progress_bar.sprite.SetOpacity(1);
       }
     }
     
     # Set refresh function to keep everything positioned
     Plymouth.SetRefreshFunction(refresh_callback);
     
     # Try to position elements immediately (may not work if display not ready)
     # This ensures sprites are at least created and visible
     refresh_callback();
     
     # Initialize display when ready - position elements when display is available
     fun OnDisplayInit() {
       refresh_callback();
     }
     
     # Function to handle boot progress updates
     fun OnBootProgress(duration, progress) {
       # Calculate new width based on progress (0.0 to 1.0)
       new_width = Math.Int(progress_bar.original_image.GetWidth() * progress);
       
       # Ensure minimum width for visibility
       if (new_width < 1) {
         new_width = 1;
       }
       
       # Scale the progress bar image horizontally
       progress_bar.image = progress_bar.original_image.Scale(new_width, progress_bar.original_image.GetHeight());
       progress_bar.sprite.SetImage(progress_bar.image);
       
       # Recalculate position to keep it centered in the box
       screen_width = Window.GetWidth();
       screen_height = Window.GetHeight();
       if (screen_width > 0 && screen_height > 0) {
         # Get current box position (stored in refresh_callback)
         progress_box_width = progress_box.image.GetWidth();
         progress_box_height = progress_box.image.GetHeight();
         progress_box_x = Window.GetX() + (screen_width - progress_box_width) / 2;
         progress_box_y = Window.GetY() + screen_height - progress_box_height - 100;
         
         # Center the scaled progress bar inside the box
         current_bar_width = progress_bar.image.GetWidth();
         current_bar_height = progress_bar.image.GetHeight();
         box_padding_x = (progress_box_width - current_bar_width) / 2;
         box_padding_y = (progress_box_height - current_bar_height) / 2;
         progress_bar_x = progress_box_x + box_padding_x;
         progress_bar_y = progress_box_y + box_padding_y;
         progress_bar.sprite.SetPosition(progress_bar_x, progress_bar_y, 3000);
       }
     }
     
     # Register boot progress callback
     Plymouth.SetBootProgressFunction(OnBootProgress);
     
     # Function called when Plymouth quits
     fun OnQuit() {
       logo.sprite.SetOpacity(0);
       progress_box.sprite.SetOpacity(0);
       progress_bar.sprite.SetOpacity(0);
     }
     SCRIPT
   '';
in

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # ASUS specific hardware configuration
      ./asus-dialpad.nix
      #import Niri WM
      ./niri.nix
      # GPU offloading configuration
      ./gpu-offload.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  # Use "auto" to let systemd-boot pick a suitable console mode
  boot.loader.systemd-boot.consoleMode = "auto";
  boot.loader.efi.canTouchEfiVariables = true;

  # Plymouth boot splash screen
  # Step 1: Custom theme with logo only (progress bars will be added next)
  boot.plymouth = {
    enable = true;
    theme = "spectreos";
    themePackages = [ spectreos-plymouth-theme ];
  };

  # Kernel 7; default on 25.11 is 6.12. NVIDIA 580.126.18 from unstable in gpu-offload.nix.
  boot.kernelPackages = pkgs.linuxKernel.packages.linux_7_0;

  # Kernel parameters for DisplayPort Multi-Stream Transport (DP-MST) support
  # Note: MST debugging removed - was causing excessive logging and performance issues
  # MST is enabled by default in the kernel
  # To re-enable MST debugging in the future (if needed), add: "drm.debug=0x04" (MST only, less verbose)
  # boot.kernelParams = [
  #   "drm.debug=0x04"  # MST debug only (much less verbose than 0x1e)
  # ];
  
  #Asus specific firmware controllers
  services.fwupd.enable = true;
  hardware.enableAllFirmware = true;
  
  # Power management - works with both GNOME and Niri
  # This is what GNOME's power save mode uses, so they work together
  services.power-profiles-daemon.enable = true;
  
  # Configure logind for better power management
  # NixOS 25.11: All logind options moved to settings.Login
  services.logind = {
    settings = {
      Login = {
        HandlePowerKey = "suspend";
        HandleSuspendKey = "suspend";
        HandleHibernateKey = "hibernate";
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "ignore";
      };
    };
  };

  #enable flatpak for 3rd party software containers
  services.flatpak.enable = true;

  # Virtualisation (KVM/QEMU)
  virtualisation.libvirtd = {
    enable = true;
    qemu.package = pkgs.qemu_kvm;
  };

  networking.hostName = "PX13"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  # NixOS 25.11: Options moved out of services.xserver
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Color management service (colord)
  # Manages ICC color profiles for displays and printers
  # Profiles set in GNOME will persist and work across all sessions (including Niri)
  services.colord.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.miles = {
    isNormalUser = true;
    description = "Miles Chatterji";
    # All groups: networkmanager (networking), wheel (sudo), video/render (GPU access), 
    # uinput/input/i2c (ASUS DialPad hardware access)
    extraGroups = [ "networkmanager" "wheel" "video" "render" "uinput" "input" "i2c" "libvirtd" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Use ZSH
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable experimental Nix features
  # nix-command: Enables the new nix command (nix search, nix shell, etc.)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Added 2026-05-08 for SpectreOS Updater compatibility.
  # home-manager does NOT set its own NIX_PATH entry — it relies on <home-manager/...>
  # being resolvable at evaluation time. Without this, 'home-manager switch' fails after
  # a nixos-rebuild because the channel path is no longer guaranteed to exist.
  # Pointing at pkgs.home-manager.src keeps the pinned version in lock-step with the binary.
  nix.nixPath = [
    "home-manager=${pkgs.home-manager.src}"
    "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    "nixos-config=/etc/nixos/configuration.nix"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  # Most user packages have been migrated to Home Manager
  # Keep these at system level for TTY/recovery access and multi-user availability
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.

  # SpectreOS Updater — GTK4/Rust GUI for package management and system updates.
  # Added 2026-05-08. Source lives in SpectreOS26.05 (the portable project base);
  # absolute path is intentional — the host config has no apps/ subdirectory.
  # package.nix uses ./ relative to itself, so the absolute callPackage path is safe.
  (pkgs.callPackage /home/miles/Documents/SpectreOS26.05/apps/spectreos-updater/package.nix {})

  neovim  # Keep for TTY/recovery editing
  git     # Keep for version control in TTY/recovery
  wget    # Keep for downloads in TTY/recovery
  fwupd   # System firmware updates
  busybox # System utilities
  lshw    # Hardware info (system-level)
  colord  # Color management daemon (for ICC profile management)
  nvtopPackages.full

  # Added 2026-05-08 — required by the SpectreOS Updater's System tab.
  # home-manager is invoked as 'bash -l -c home-manager switch' by the updater;
  # it must be on PATH at the system level so it's available before a user session starts.
  home-manager
  ];

  # Autostart systemd systemctl configs for apps that should open with other apps. 

  # Autostart proton-bridge and make it availalbe to all email clients upon opening them.

  # Dropbox service has been migrated to Home Manager
  # See ~/.config/home-manager/home.nix for systemd.user.services.dropbox

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Security wrapper for gsr-kms-server to grant sys_admin capability
  # gpu-screen-recorder requires gsr-kms-server to have sys_admin capability
  # to access DRM/KMS devices without root privileges
  # This wrapper will be created at /run/wrappers/bin/gsr-kms-server
  security.wrappers.gsr-kms-server = {
    source = "${pkgs.gpu-screen-recorder}/bin/gsr-kms-server";
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+ep";
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # Dropbox ports below.
  networking.firewall = {
    allowedTCPPorts = [ 17500 ];
    allowedUDPPorts = [ 17500 ];
  };
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  # SpectreOS identity — overrides NixOS defaults in /etc/os-release and /etc/lsb-release.
  # ID_LIKE=nixos preserves NixOS tooling compatibility. lib.mkForce is required because
  # NixOS sets these files with high priority.
  environment.etc."spectreos/upgrade-helper.sh" = {
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      VERSION="''${1:?Usage: upgrade-helper.sh <version>}"
      export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
      nix-channel --add "https://nixos.org/channels/nixos-$VERSION" nixos
      nix-channel --add "https://github.com/nix-community/home-manager/archive/release-$VERSION.tar.gz" home-manager
      nix-channel --update
      nixos-rebuild switch --upgrade
    '';
    mode = "0755";
  };

  environment.etc."spectreos/rebuild-helper.sh" = {
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
      nixos-rebuild switch
    '';
    mode = "0755";
  };

  environment.etc."spectreos/rollback-helper.sh" = {
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      GENERATION="''${1:?Usage: rollback-helper.sh <generation>}"
      export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
      nix-env --switch-generation "$GENERATION" --profile /nix/var/nix/profiles/system
      /nix/var/nix/profiles/system/bin/switch-to-configuration switch
    '';
    mode = "0755";
  };

  # Allow wheel-group users to run the SpectreOS helper scripts without a password prompt.
  security.sudo.extraConfig = ''
    %wheel ALL=(root) NOPASSWD: /etc/spectreos/upgrade-helper.sh *
    %wheel ALL=(root) NOPASSWD: /etc/spectreos/rebuild-helper.sh
    %wheel ALL=(root) NOPASSWD: /etc/spectreos/rollback-helper.sh *
  '';

  environment.etc."os-release".text = lib.mkForce ''
    NAME="SpectreOS"
    PRETTY_NAME="SpectreOS 0.1 (Beta)"
    ID=spectreos
    ID_LIKE=nixos
    VERSION="0.1"
    VERSION_ID="0.1"
    VERSION_CODENAME=beta
    LOGO="nix-snowflake"
    ANSI_COLOR="0;38;2;126;186;228"
  '';

  environment.etc."lsb-release".text = lib.mkForce ''
    DISTRIB_ID=SpectreOS
    DISTRIB_RELEASE=0.1
    DISTRIB_CODENAME=beta
    DISTRIB_DESCRIPTION="SpectreOS 0.1 (Beta)"
    LSB_VERSION=0.1
  '';

  system.stateVersion = "25.11"; # Did you read the comment?

}
