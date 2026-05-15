# SpectreOS Host Config — Agent Notes

This repo contains the live PX13 host configuration. Changes here go to `/etc/nixos/` via `sudo nixos-rebuild switch`. See `SpectreOS26.05/` for the broader project.

## Hardware: ASUS ProArt PX13 (HN7306WU)
- CPU: AMD Ryzen AI 9 HX 370 (Strix Halo)
- GPU: AMD Radeon 890M (iGPU) + NVIDIA RTX 4050 Max-Q (dGPU, PRIME offload)
- WiFi: MediaTek mt7925e (PCI 0000:c3:00.0)

## Known changes and why

### WiFi runtime power management (2026-05-14)
Added a udev rule to enable runtime PM on the mt7925e wifi card:
```nix
services.udev.extraRules = ''
  ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x14c3", ATTR{device}=="0x7925", ATTR{power/control}="auto"
'';
```
**Why:** Powertop flagged the card as staying fully powered at all times with no runtime PM, causing it to run hot on weak signals. This targets only the mt7925e by vendor/device ID.
**Risk:** Low. If the card becomes unstable (some mt7925e units are sensitive to aggressive PM), remove these lines and rebuild. Many PX13 users replace this card — it is a known weak point.
