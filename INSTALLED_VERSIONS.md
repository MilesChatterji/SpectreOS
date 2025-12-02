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
- **Actual Installed Version**: **3.3.0** (as reported by Noctalia Shell)
- **Latest Available Version**: **3.5.0** (released 2025-12-01)
- **Declared Version in Nix**: **0.1.0** (arbitrary metadata, not related to actual version)
- **Source**: Custom derivation fetching from GitHub
- **Git Branch**: `main` (pinned)
- **SHA256**: `sha256-pWz6IWgG614EoVxPY6tlEsurZMznBvbyliI3go1BAuY=`
- **Location in config**: `niri.nix` lines 299-358

### Version Correlation
- The **"0.1.0"** in `niri.nix` is just Nix derivation metadata and has no relation to the actual Noctalia Shell version
- The **actual version (3.3.0)** is determined by the commit on the `main` branch that the SHA256 corresponds to
- Noctalia Shell uses semantic versioning: **3.3.0 → 3.4.0 → 3.5.0**
- Your SHA256 likely corresponds to the v3.3.0 release commit

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

### Current GitHub State
- **Latest release**: **v3.5.0** (published 2025-12-01)
- **Your installed version**: **v3.3.0** (published 2025-11-23)
- **Latest main branch commit**: `ba09514138f964bc680f95ec7c80263442f56b2d`
- **Latest commit date**: 2025-12-01T21:12:49Z
- **Note**: The SHA256 in your config corresponds to a commit from around v3.3.0 timeframe

### Upgrade Notes
- ⚠️ **Pinned to `main` branch** - won't auto-update
- ⚠️ **SHA256 pinning** - if `main` branch moves, SHA256 will break and need updating
- ⚠️ **Version Mismatch**: You're running **3.3.0** but **3.5.0** is available
- **To check if update needed**:
  ```bash
  nix-prefetch-github noctalia-dev noctalia-shell --rev main
  # Or pin to specific release:
  nix-prefetch-github noctalia-dev noctalia-shell --rev v3.5.0
  ```
- **To update to v3.5.0**: 
  1. Update `rev` in `niri.nix` line 306 to `"v3.5.0"` (or keep `"main"` for latest)
  2. Update SHA256 in `niri.nix` line 307 with new hash from `nix-prefetch-github`
- **Recommendation**: Consider pinning to a specific release tag (e.g., `v3.5.0`) instead of `main` for stability and predictable versions

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
| **Niri** | 25.08 | `pkgs.niri` | ✅ Yes | Updates with nixpkgs channel |
| **Noctalia Shell** | **3.3.0** (actual) / 0.1.0 (Nix metadata) | GitHub `main` branch | ❌ No | Pinned to `main` with SHA256. **3.5.0 available** |
| **Quickshell** | 0.2.1 | `unstable.quickshell` | ✅ Yes | Updates with unstable channel |

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

**Last Updated**: $(date +%Y-%m-%d)
**Next Review**: Before NixOS 25.11 upgrade

