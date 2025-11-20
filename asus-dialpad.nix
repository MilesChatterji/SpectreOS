# ASUS DialPad Driver configuration for PX13
# This file contains all ASUS DialPad related configuration

{ config, pkgs, ... }:

let
  # Python environment with all dependencies
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    numpy
    libevdev
    xlib
    pyinotify
    smbus2
    pyasyncore
    pywayland
    xkbcommon
    systemd
  ]);

  # ASUS DialPad Driver package
  asus-dialpad-driver = pkgs.stdenv.mkDerivation rec {
    pname = "asus-dialpad-driver";
    version = "1.1.0";
    
    src = pkgs.fetchFromGitHub {
      owner = "asus-linux-drivers";
      repo = "asus-dialpad-driver";
      rev = "v${version}";
      sha256 = "sha256-odaAYB9e/R5UXDzh0XvDrOcO0vq97gNmUIirOWX8RP0=";
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
  users.groups = {
    uinput = { };
    input = { };
    i2c = { };
  };

  # Add user to DialPad groups (merged with existing groups from configuration.nix)
  users.users.miles = {
    extraGroups = [ "uinput" "input" "i2c" ];
  };

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
      ExecStart = "${asus-dialpad-driver}/bin/asus-dialpad-driver proartp16";
      WorkingDirectory = "${asus-dialpad-driver}/share/asus-dialpad-driver";
      Restart = "on-failure";
      RestartSec = 5;
      StandardOutput = "journal";
      StandardError = "journal";
      Environment = [
        "XDG_SESSION_TYPE=wayland"
        "WAYLAND_DISPLAY=wayland-0"
        "LOG=WARNING"
        "HOME=%h"
      ];
    };
  };
}

