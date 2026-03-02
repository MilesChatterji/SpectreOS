# Noctalia Shell 4.6.0 Migration Note

**Date:** 2025-02-07 (approx.)  
**Current state:** Reverted to **noctalia-shell 4.5.0** in `niri.nix` so the shell works with the existing **quickshell** setup.

---

## Why 4.6.0 didn’t load

- **4.6.0 requires `noctalia-qs`** (Noctalia’s fork of Quickshell), not upstream **quickshell**. Our config uses `unstable.quickshell` everywhere. The shell “will not work with a plain quickshell binary” and can break.
- **Systemd is no longer supported** by upstream for starting Noctalia; they recommend launching from the compositor (e.g. `exec noctalia-shell` in Niri config).

---

## What was reverted

- In **niri.nix**: noctalia-shell derivation set back to **v4.5.0** (rev and sha256 for v4.5.0). No other files were changed.

---

## To migrate to 4.6.0 later

1. **Add a noctalia-qs package**  
   Build from [noctalia-dev/noctalia-qs](https://github.com/noctalia-dev/noctalia-qs) (repo has a `default.nix`; may need nix-gitignore and other deps). Prefetch with e.g.  
   `nix-prefetch-github noctalia-dev noctalia-qs --rev v0.0.2`  
   (v0.0.2 sha256: `sha256-rEuOibqZMx7+NvV2OVIdQQCDV9HT2lMsb9vHbA+d5FU=`).

2. **Use noctalia-qs instead of quickshell for Noctalia**  
   In **niri.nix**:
   - In the noctalia-shell derivation: `runtimeDeps`, installPhase symlink (`ln -s` to noctalia-qs’s `qs`), and wrapper args.
   - Swayidle lock/suspend commands (lines ~291–293): use noctalia-qs’s `qs` instead of `unstable.quickshell`.
   - Systemd user service `noctalia-shell`: ensure `PATH` and any direct `qs` usage point at noctalia-qs.
   - `environment.systemPackages`: include noctalia-qs (or rely on noctalia-shell’s wrapper).

3. **Optionally move startup off systemd**  
   Since 4.6.0 drops systemd support, consider starting Noctalia from Niri’s config (e.g. `exec noctalia-shell` in Niri startup) and disabling or removing the systemd user service.

4. **Bump noctalia-shell to 4.6.0**  
   Update rev/sha256 in the derivation to v4.6.0 (e.g.  
   `nix-prefetch-github noctalia-dev noctalia-shell --rev v4.6.0`).

---

## References

- [Noctalia Shell v4.6.0 release notes](https://github.com/noctalia-dev/noctalia-shell/releases/tag/v4.6.0) — “Migrate to noctalia-qs”, “Systemd startup no longer supported”.
- [noctalia-qs repo](https://github.com/noctalia-dev/noctalia-qs) — contains `default.nix`, `overlay.nix`, `flake.nix`.
- [Noctalia NixOS docs](https://docs.noctalia.dev/getting-started/nixos/) — flake-based install with `noctalia-qs` input.
