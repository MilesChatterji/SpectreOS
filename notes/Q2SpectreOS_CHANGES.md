# Q2 SpectreOS Changes & Future Projects

**Date:** 2026-03-23
**Context:** Post-rebuild review session. System running well on Noctalia 4.6.7, kernel 6.19.9.

---

## Three Planned Config Simplifications

These are not urgent — intention is to let the system run reliably for a while first, then apply as a cleanup pass. All three reduce custom plumbing in favour of official nixpkgs.

### 1. NVIDIA Driver — revert to stable channel

**Current state:** `gpu-offload.nix` pulls NVIDIA 580.126.18 from nixos-unstable via a custom `fetchTarball` + kernel injection workaround. This was put in place 2025-02-07 when stable (580.119.02) didn't build on kernel 6.19.

**Change:** Remove the entire unstable fetch and let block from `gpu-offload.nix`. Revert `hardware.nvidia.package` to `config.boot.kernelPackages.nvidiaPackages.production`.

**Why it's likely safe now:** The workaround is 13+ months old. NixOS 25.11 stable has almost certainly moved well past 580.126.18. Verify current stable driver version before switching.

**Reference:** Full revert steps documented in `notes/NVIDIA_6.19_UNSTABLE_DRIVER_CHANGES_2025-02-07.md`.

---

### 2. Kernel Pin — relax from explicit 6.19

**Current state:** `configuration.nix` has `boot.kernelPackages = pkgs.linuxPackages_6_19;`. NixOS 25.11 default is 6.12 (LTS). The 6.19 pin was needed for NVIDIA driver compatibility.

**Options when ready:**
- Remove pin entirely → drops back to NixOS 25.11 default (6.12 LTS). Most stable, least maintenance.
- Keep `linuxPackages_6_19` → stays on latest 6.19.x patch, as now.
- Switch to `linuxPackages_latest` → tracks whatever nixpkgs has, similar behaviour to now but not tied to a specific series.

**Note:** This decision is independent of the NVIDIA driver change. Revert driver first, confirm stability, then consider relaxing the kernel pin.

---

### 3. Noctalia Shell — replace custom derivation with nixpkgs package

**Current state:** `niri.nix` contains a ~60-line custom `stdenvNoCC.mkDerivation` that fetches Noctalia from GitHub with a pinned SHA256, manually specifies build inputs, runtime deps, install phase, and Qt wrapper config. Requires manual SHA update each release (e.g. just updated to 4.6.7).

**Change:** Replace the entire derivation with `unstable.noctalia`. Replace `unstable.noctalia-qs` references with `unstable.noctalia-qs` (already in unstable, no change there) or eventually `pkgs.noctalia-qs` if it lands in stable.

**What simplifies:**
- 60-line derivation block removed from `niri.nix`
- No more manual SHA256 management
- Noctalia IPC call in `swayidle-start` simplifies (official package bakes in `-p` path via Qt wrapper, no need to call `qs` directly with explicit data path)
- PATH construction in `noctalia-shell` systemd service simplifies

**What stays in `niri.nix`:** Everything Niri/hardware-specific — AMD GPU wrapper, brightness scripts, MST display handling, swayidle service, all systemd session services.

**What could move to `configuration.nix`:** Package declarations (`unstable.noctalia`, `unstable.noctalia-qs`) in `environment.systemPackages`.

**Verify before switching:** Confirm official package binary name and data path structure match what swayidle IPC call expects.

---

## Future Projects (in rough priority order)

### 1. Noctalia Fork
Contribute or fork Noctalia to include changes already made in SpectreOS:
- Brightnessctl integration (ambient light sensor auto-brightness, manual override cooldown)
- Power saver options (idle dim, configurable thresholds)
- Goal: upstream these as proper Noctalia features rather than maintaining them as custom scripts outside the shell

### 2. Visual NixOS Updater
A GUI tool for updating:
- Home Manager packages/config
- System-level NixOS packages/config
- Targeted at making NixOS maintenance accessible without dropping to terminal for every rebuild
- Will need to handle both `nixos-rebuild` and `home-manager switch` flows

### 3. Custom NixOS Installer
An installer that produces a system configured as SpectreOS is today. Key considerations:
- Hardware detection methods (GPU, display, sensors) with variables/profiles
- Modular config — hardware-specific vs user preference vs baseline
- Probably builds on the simplifications above (less custom plumbing = easier to template)
- Long-term: could serve as a general NixOS opinionated install tool

---

## Current System State (as of this session)

| Item | State |
|------|-------|
| NixOS channel | 25.11 |
| Kernel | 6.19.9 (pinned to `linuxPackages_6_19`) |
| NVIDIA driver | 580.126.18+ from nixos-unstable |
| Noctalia Shell | 4.6.7 (custom SHA derivation in `niri.nix`) |
| Noctalia-QS | From `unstable.noctalia-qs` |
| Niri | 25.08 from nixpkgs |
