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

## Kernel regressions — now running 26.05 + 7.0.11 (gen 209)

Both confirmed regressions resolved. System now on 26.05 + 7.0.11 as daily driver.

### 1. NVIDIA MSI IRQ regression (7.0.9+) — RESOLVED
`NVRM: Can't find an IRQ for your NVIDIA card!` — nvidia probe fails regardless of IOMMU config.
Fixed in 26.05's build of 7.0.10 (nvidia-smi confirmed working).
See `nvidia-msi-regression-bug-report.md`.

### 2. Platform power management regression — RESOLVED (2026-06-09)
Root cause was **diagnostic config residue**, not a kernel regression:
- `ppfeaturemask=0xffff7fff` disables PP_GFXOFF, keeping the GFX IP powered → elevated idle + S0i3 blocked
- Root port 0000:00:03.1 forced `power/control=on` → prevents PCIe suspend and dGPU D3cold
- `amd_pmf` blacklisted unnecessarily — gen 198 (good) runs with it loaded
- `amd_pstate=passive`, `pci=noaer`, `amd_pmc disable_workarounds` — all diagnostic, all present on bad gens

Every test since gen 198 carried this residue. Gen 198 never had any of it.
**Fix:** Remove all diagnostic items. Clean config on 7.0.11 = 5-6W idle, ~8h battery, S0i3 working.

No diagnostic changes remain in configs. See `kernel-power-regression-bug-report.md` for full history.

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
