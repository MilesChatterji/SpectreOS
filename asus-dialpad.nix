# ASUS DialPad Driver configuration for PX13
# This file contains all ASUS DialPad related configuration

{ config, pkgs, ... }:

let
  # Python environment with all dependencies
  # NixOS 25.11: systemd package renamed to systemd-python
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    numpy
    libevdev
    xlib
    pyinotify
    python-periphery
    pyasyncore
    pywayland
    xcffib
    xkbcommon
    systemd-python  # Renamed from systemd in NixOS 25.11
  ]);

  # ASUS DialPad Driver package
  asus-dialpad-driver = pkgs.stdenv.mkDerivation rec {
    pname = "asus-dialpad-driver";
    version = "2.2.0";

    src = pkgs.fetchFromGitHub {
      owner = "asus-linux-drivers";
      repo = "asus-dialpad-driver";
      rev = "v${version}";
      sha256 = "sha256-AEeC3VRxz70Acj+pQ04NGPTNI7kDCaocrQf6qLqWfF8=";
    };
    
    nativeBuildInputs = [
      pythonEnv
      pkgs.ibus
      pkgs.libevdev
      pkgs.curl
      pkgs.xorg.xinput
      pkgs.i2c-tools
      pkgs.libxml2
      pkgs.libxkbcommon
    ];
    
    # Fix 2.2.0 bugs:
    # 1. coactivator_keys initializes to None instead of [], causing TypeError
    #    when Wayland keymap event fires before config loads.
    # 2. send_key_event checks uinput_device which is never assigned — should
    #    be udev (the actual libevdev UInput device created in initialize_virtual_device).
    postPatch = ''
      substituteInPlace dialpad.py \
        --replace-fail "coactivator_keys = None" "coactivator_keys = []"
      sed -i 's/\buinput_device\b/udev/g' dialpad.py
    '';

    buildPhase = ''
      echo "Skipping build phase"
    '';
    
    installPhase = ''
      mkdir -p $out/share/asus-dialpad-driver
      install -Dm755 dialpad.py $out/share/asus-dialpad-driver/dialpad.py
      if [ -d layouts ]; then
        cp -r layouts $out/share/asus-dialpad-driver/
        find $out/share/asus-dialpad-driver/layouts -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
      fi
      
      # Create a wrapper script that uses the Python environment
      mkdir -p $out/bin
      cat > $out/bin/asus-dialpad-driver <<EOF
      #!${pkgs.bash}/bin/bash
      exec ${pythonEnv}/bin/python3 $out/share/asus-dialpad-driver/dialpad.py "\$@"
      EOF
      chmod +x $out/bin/asus-dialpad-driver
    '';
    
    preFixup = ''
      sed -i 's/\r$//' $out/share/asus-dialpad-driver/dialpad.py
    '';
  };
in
{
  # Kernel modules for ASUS DialPad
  boot.kernelModules = [ "uinput" "i2c-dev" ];
  
  # Enable i2c hardware support for DialPad
  hardware.i2c.enable = true;
  
  # Udev rules for ASUS DialPad (i2c and uinput access)
  services.udev.extraRules = ''
    # Set uinput device permissions
    KERNEL=="uinput", GROUP="uinput", MODE="0660"
    # Set i2c-dev permissions
    SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"
  '';

  # Groups for ASUS DialPad
  # Note: GIDs are set to standard system group IDs to ensure udev recognizes them
  # input group already has GID 174 (system range) in NixOS defaults, so we keep it
  # i2c and uinput need system GIDs (61 and 98) to be recognized by udev
  users.groups = {
    uinput = { gid = 98; };
    # input group uses default GID 174 (already a system group)
    i2c = { gid = 61; };
  };

  # Note: User groups (uinput, input, i2c) are now defined in configuration.nix
  # to avoid conflicts. The groups are merged there with other user groups.

  # Add ASUS DialPad Driver to system packages
  environment.systemPackages = [ asus-dialpad-driver ];

  # ASUS DialPad Driver service
  # PX13 uses nested layout (proartp16) - adjust if needed
  # The config file will be created in ~/.config/asus-dialpad-driver/ on first run
  systemd.user.services.asus-dialpad-driver = {
    description = "ASUS DialPad Driver";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      # Wait for Wayland display to be available before starting
      # This script checks for WAYLAND_DISPLAY in the session environment and verifies the socket exists
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'while [ -z \"$WAYLAND_DISPLAY\" ] || [ ! -S \"$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY\" ]; do sleep 0.5; done; echo \"Wayland display ready: $WAYLAND_DISPLAY\"'";
      ExecStart = "${asus-dialpad-driver}/bin/asus-dialpad-driver proartp16";
      WorkingDirectory = "%h/.config/asus-dialpad-driver";
      ConfigurationDirectory = "asus-dialpad-driver";
      Restart = "on-failure";
      RestartSec = 5;
      StandardOutput = "journal";
      StandardError = "journal";
      # Don't hardcode WAYLAND_DISPLAY - let it inherit from the session environment
      # The actual display name (wayland-0, wayland-1, etc.) varies by session
      Environment = [
        "XDG_SESSION_TYPE=wayland"
        "LOG=WARNING"
        "HOME=%h"
      ];
      # Pass through environment from the session (including WAYLAND_DISPLAY)
      PassEnvironment = [ "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" "XDG_SESSION_TYPE" ];
    };
  };
}

