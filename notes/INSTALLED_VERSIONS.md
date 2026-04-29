# Installed Package Versions
## Current System State

This document tracks the versions of key packages installed on your system.

---

## **Niri Wayland Compositor**

### Version Information
- **Installed Version**: **25.08**
- **Source**: `pkgs.niri` from nixpkgs channel
- **Location in config**: `niri.nix` line 281, 372, 399
- **Verification**: 
  ```bash
  niri --version
  # Output: niri 25.08 (Nixpkgs)
  ```

### Configuration Details
- Uses `pkgs.niri` directly from nixpkgs
- Wrapped in custom `niri-amd-session` package for AMD GPU optimization
- Custom wrapper script: `niri-amd-wrapper` (forces AMD iGPU usage)

### Upgrade Notes
- Will automatically update when nixpkgs channel is updated
- Currently same version (25.08) in both `nixos-25.05` and `nixpkgs-unstable` channels
- No manual version pinning required

---

## **Noctalia Shell**

### Version Information
- **Installed Version**: **4.7.1**
- **Source**: Custom derivation fetching from GitHub, pinned to specific rev
- **Location in config**: `niri.nix`

### Configuration Details
```nix
noctalia-shell = pkgs.stdenvNoCC.mkDerivation rec {
  pname = "noctalia-shell";
  version = "0.1.0";
  
  src = pkgs.fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "noctalia-shell";
    rev = "main";
    sha256 = "sha256-pWz6IWgG614EoVxPY6tlEsurZMznBvbyliI3go1BAuY=";
  };
  ...
}
```

### Upgrade Notes
- ⚠️ Pinned to specific rev with SHA256 — won't auto-update
- To upgrade: update `rev` and SHA256 in `niri.nix` to the desired release tag

### Dependencies
- **Quickshell**: 0.2.1 (from unstable channel)
- **Qt6**: Uses `qt6.qtbase` and `qt6.wrapQtAppsHook`
- **Runtime deps**: brightnessctl, cava, cliphist, ddcutil, matugen, wlsunset, wl-clipboard, gpu-screen-recorder (x86_64 only)

---

## **Quickshell** (Noctalia Shell dependency)

### Version Information
- **Installed Version**: **0.2.1**
- **Source**: `unstable.quickshell` from nixpkgs-unstable channel
- **Location in config**: `niri.nix` lines 144, 145, 146, 401
- **Verification**:
  ```bash
  noctalia-shell --version
  # Output: quickshell 0.2.1, revision tag-v0.2.1, distributed by: Nixpkgs
  ```

### Configuration Details
- Required by Noctalia Shell for IPC communication
- Used for screen locking via IPC: `qs -p ${noctalia-shell}/share/noctalia-shell ipc call lockScreen lock`

---

## **Summary Table**

| Package | Version | Source | Auto-Update | Notes |
|---------|---------|--------|-------------|-------|
| **Linux Kernel** | 7.0 | `pkgs.linuxKernel.packages.linux_7_0` | ❌ No | Pinned. Migrated from 6.19 (EOL at 6.19.14) on 2026-04-22 |
| **Niri** | 25.08 | `pkgs.niri` | ✅ Yes | Updates with nixpkgs channel |
| **Noctalia Shell** | **4.7.1** | GitHub rev pinned | ❌ No | Pinned to specific rev with SHA256 |
| **Quickshell** | 0.2.1 | `unstable.quickshell` | ✅ Yes | Updates with unstable channel |
| **ASUS DialPad Driver** | 2.2.0 | GitHub `fetchFromGitHub` | ❌ No | Patched via postPatch for two 2.2.0 bugs — see ASUS_DIALPAD_FIX.md |

---

## **Version Check Commands**

```bash
# Check Niri version
niri --version

# Check Noctalia Shell / Quickshell version
noctalia-shell --version

# Check what nixpkgs has for niri
nix-env -qaP niri

# Check if Noctalia SHA256 needs updating
nix-prefetch-github noctalia-dev noctalia-shell --rev main

# Check current system packages
nix-store -q --references $(which niri) | head -10
```

---

## **Upgrade Considerations**

### For NixOS 25.11 Upgrade:

1. **Niri**: 
   - ✅ Should upgrade automatically with nixpkgs
   - ✅ No action needed

2. **Noctalia Shell**:
   - ⚠️ Check if SHA256 needs updating before upgrade
   - ⚠️ If `main` branch has moved, update SHA256 in `niri.nix` line 307
   - ⚠️ Consider pinning to a release tag for stability

3. **Quickshell**:
   - ✅ Will update with unstable channel
   - ⚠️ Ensure compatibility with Noctalia Shell version

---

**Last Updated**: 2026-04-22
**Next Review**: Before next NixOS upgrade

