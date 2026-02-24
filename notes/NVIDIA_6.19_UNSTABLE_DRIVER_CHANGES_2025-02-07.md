# NVIDIA 6.19 / Unstable Driver Changes (2025-02-07)

**Purpose:** Document all edits made from ~1pm 2025-02-07 to try kernel 6.19 with NVIDIA 580.126.18 from nixos-unstable. Use this note to **revert to baseline** (kernel 6.18 + stable-channel driver) if this work becomes too involved or waiting for stable makes more sense.

**Baseline state:** System was stable on kernel 6.18.13 with NVIDIA production driver from the stable channel (580.119.02). No unstable fetch; kernel was pinned to `linuxPackages_6_18`.

---

## 1. `configuration.nix` — kernel pin

### Baseline (revert to this)

```nix
  # Pin to kernel 6.18 until nixpkgs has NVIDIA 580.126.18 (6.19-compatible)
  boot.kernelPackages = pkgs.linuxPackages_6_18;

  # Kernel parameters for DisplayPort Multi-Stream Transport (DP-MST) support
```

### Current (as of 2025-02-07)

- **Explicit 6.19 pin** (25.11 default is 6.12, so we must set this to get 6.19):

```nix
  # Pin to kernel 6.19; default on 25.11 is 6.12. NVIDIA 580.126.18 from unstable in gpu-offload.nix.
  boot.kernelPackages = pkgs.linuxPackages_6_19;

  # Kernel parameters for DisplayPort Multi-Stream Transport (DP-MST) support
```

**Revert:** Restore `boot.kernelPackages = pkgs.linuxPackages_6_18;` and the original “Pin to kernel 6.18 until…” comment; remove the 6.19 pin and its comment.

---

## 2. `gpu-offload.nix` — NVIDIA driver from unstable

### Baseline (revert to this)

- **No** unstable fetch or import.
- **No** `ourKernel`, `nvidiaX11Path`, `unstableWithOurKernel`, or `unstableNvidiaPackages` in the `let` block.
- **hardware.nvidia.package** set to channel driver:

```nix
# At top of file: no NOTE/TODO block about 2025-02-07.

let
  # NVIDIA offload wrapper script
  # (no unstableSrc, unstable, ourKernel, nvidiaX11Path, unstableWithOurKernel, unstableNvidiaPackages)

  # In hardware.nvidia:
    # Use production driver (580.126.18) for kernel 6.19 compatibility
    # stable (580.119.02) does not build on 6.19; production has the 6.19 fixes
    package = config.boot.kernelPackages.nvidiaPackages.production;
```

### Current (as of 2025-02-07)

- **Top of file:** NOTE (2025-02-07) and TODO about reverting when stable has 580.126.18+.
- **let block** (after the opening `let`):
  - `unstableSrc = builtins.fetchTarball { url = "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz"; };`
  - `unstable = import unstableSrc { config.allowUnfree = true; inherit (config.nixpkgs) system; };`
  - `ourKernel = config.boot.kernelPackages.kernel;`
  - `nvidiaX11Path = unstableSrc + "/pkgs/os-specific/linux/nvidia-x11";`
  - `unstableWithOurKernel = unstable // { kernel = ourKernel; callPackage = fn: args: ... };` (full custom callPackage logic).
  - `unstableNvidiaPackages = unstableWithOurKernel.callPackage (unstableSrc + "/pkgs/os-specific/linux/nvidia-x11") { };`
- **hardware.nvidia.package:** `package = unstableNvidiaPackages.production;` with comment pointing at top-of-file NOTE.

**Revert:**
1. Remove the entire NOTE/TODO block at the top (lines about 2025-02-07 and revert instructions).
2. Remove from the `let` block: `unstableSrc`, `unstable`, `ourKernel`, `nvidiaX11Path`, `unstableWithOurKernel`, `unstableNvidiaPackages` (and all their comments).
3. Set `package = config.boot.kernelPackages.nvidiaPackages.production;` and restore the previous comment (production driver for 6.19 compatibility / stable doesn’t build on 6.19).

---

## Quick revert checklist

- [ ] **configuration.nix:** Restore `boot.kernelPackages = pkgs.linuxPackages_6_18;` and original “Pin to kernel 6.18…” comment; remove the 6.19 pin.
- [ ] **gpu-offload.nix:** Remove NOTE/TODO at top; remove unstable fetch/import and all related let bindings; set `package = config.boot.kernelPackages.nvidiaPackages.production;` with old comment.
- [ ] Run `sudo nixos-rebuild dry-run` (then `switch` when satisfied).

---

## Maintenance

- **When stable channel has 580.126.18+:** Revert **gpu-offload.nix only** as above (remove unstable fetch and use `config.boot.kernelPackages.nvidiaPackages.production`). **Do not keep using unstable for NVIDIA** after that—unstable will move on to newer/experimental drivers; you want the driver from your production channel only. Keep the 6.19 kernel pin in configuration.nix unless you decide to change kernel. Optionally add a “Completed: reverted to stable driver on YYYY-MM-DD” line at the top of this note.
- **If you add more edits** for the same 6.19/unstable-driver work, append a “Further changes (date)” section below with file, baseline vs current, and revert steps.
