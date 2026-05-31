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

## Active kernel regressions — running 7.0.5 (bootloader selection)

Two confirmed regressions in kernel 7.0.10 on this hardware. Both filed at bugs.kernel.org.
Stay on 7.0.5 generation until upstream fixes land. Periodically rebuild the 26.05 generation
and test — when both regressions are resolved, switch back.

### 1. NVIDIA MSI IRQ regression (7.0.9+)
`NVRM: Can't find an IRQ for your NVIDIA card!` — nvidia probe fails regardless of IOMMU config.
Fixed in 26.05's build of 7.0.10 (nvidia-smi confirmed working). **Resolved.**
See `nvidia-msi-regression-bug-report.md`.

### 2. Platform power management regression (7.0.10)
Idle battery draw ~3x higher on 7.0.10 vs 7.0.5 on AMD Ryzen AI 9 HX 370 (Strix Halo).
- 7.0.5: ~8h battery, normal idle
- 7.0.10: ~2.5h battery, ~17W idle with nothing running
- Workarounds tried: `amd_pstate=passive`, `amdgpu.ppfeaturemask=0xffff7fff` — slight improvement only
- Root cause: unknown delta between 7.0.5 and 7.0.10; platform C-states unaffected, GPU not the cause
- ACPI GPP4 errors at boot: present on both kernels, not the cause
- See `kernel-power-regression-bug-report.md`

### When testing a new kernel build
1. Boot 26.05 generation from bootloader
2. Check `nvidia-smi` — should work (MSI regression resolved in 26.05)
3. Check idle battery draw — should be ~5-6W with nothing running
4. If both pass, switch back to 26.05 as default generation

### Config notes for 7.0.5 generation
`configuration.nix` kernelParams: `iommu=pt acpi_osi=Linux amd_pstate=passive`
`gpu-offload.nix` extraModprobeConfig: includes `amdgpu ppfeaturemask=0xffff7fff`
These are safe on 7.0.5 and may improve power on future kernels when the regression is fixed.

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
