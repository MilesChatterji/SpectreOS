# SpectreOS Host Config — Agent Notes

This repo contains the live PX13 host configuration. Changes here go to `/etc/nixos/` via `sudo nixos-rebuild switch`. See `SpectreOS26.05/` for the broader project.

## Hardware: ASUS ProArt PX13 (HN7306WU)
- CPU: AMD Ryzen AI 9 HX 370 (Strix Halo)
- GPU: AMD Radeon 890M (iGPU) + NVIDIA RTX 4050 Max-Q (dGPU, PRIME offload)
- WiFi: MediaTek mt7925e (PCI 0000:c3:00.0)

## Reference snapshots (copied 2026-05-28)

`configuration-spectreos-base.nix` and `niri-spectreos-base.nix` are point-in-time copies of the portable project base from `SpectreOS26.05/`. Use them to diff against `configuration.nix` and `niri.nix` when merging upstream changes.

### Key intentional differences — do NOT blindly overwrite

| Area | Host (configuration.nix) | Base (configuration-spectreos-base.nix) |
|------|--------------------------|------------------------------------------|
| Display manager | GDM + GNOME (kept as hardware reference) | greetd + tuigreet |
| Updater callPackage | Absolute path to SpectreOS26.05/apps/ | Relative ./apps/ (no apps/ dir here) |
| niri.nix | Full PX13 config — AMD GPU wrapper, MST, brightness, dialpad, color profile, idle | Hardware-agnostic base with PX13 blocks commented out |
| Kernel params | `iommu=pt acpi_osi=Linux` (IOMMU regression workaround) | None — base doesn't assume ASUS/AMD/NVIDIA |
| Imports | asus-dialpad.nix, gpu-offload.nix | Neither — PX13-only |
| Firewall ports | 17500 TCP/UDP (Dropbox) | Closed |

### What the base has that the host is missing (candidates to merge)

- `hardware.graphics.enable = true` — base has this; host relies on gpu-offload.nix enabling it
- `programs.dconf.enable = true` — base has this; host may not (check before adding)
- `xdg.portal` block — base configures xdg-desktop-portal-gtk; host doesn't
- `systemd.services.greetd.environment.TERM = "xterm-256color"` — N/A on host (uses GDM, not greetd)

## Upcoming work — NVIDIA + newer kernel compatibility

Next session focus: get NVIDIA RTX 4050 Max-Q working reliably with kernel 7.x.

**Context:** Kernel 7.0.9 had an AMD IOMMU regression (`__rlookup_amd_iommu` bounds check) that broke NVIDIA MSI IRQ setup regardless of IOMMU config. Workaround was to stay on 7.0.5. Fixed in 7.0.10 per kernel changelog — but Miles has not yet tested 7.0.10+ on this hardware. Once a new stable kernel lands on the host's channel, upgrade and validate:
1. NVIDIA probe succeeds (`nvidia-smi` works, no "Can't find an IRQ" in dmesg)
2. PRIME offload functions (`niri-session-amd` wrapper still routes iGPU correctly)
3. `iommu=pt` kernel param can stay (correct for AMD IOMMU passthrough when GPU works)

**gpu-offload.nix** contains the PRIME/offload config and NVIDIA driver pin. Changes to make NVIDIA work on a newer kernel likely land there, not in configuration.nix.

**niri.nix** has the AMD GPU wrapper (`niri-session-amd`) — re-enable the commented-out PX13 blocks once GPU situation is stable.

**This may require local-only changes** that should NOT be upstreamed to SpectreOS26.05. Anything in gpu-offload.nix or the NVIDIA driver pin is PX13-specific and stays here.

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
