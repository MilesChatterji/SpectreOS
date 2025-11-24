# Niri Wayland Compositor configuration
# Simple setup to add Niri as a session option in GDM

{ config, pkgs, ... }:

{
  # Add Niri to system packages
  environment.systemPackages = with pkgs; [
    niri
    xwayland-satellite  # Recommended for X11 app support
  ];

  # Create a desktop entry for Niri so it appears in GDM
  # This allows you to select Niri as a session when logging in
  services.xserver.displayManager.sessionPackages = [ pkgs.niri ];
}

