# Niri: Switched to Unstable Channel

**Date:** 2026-05-12

## Change

Switched `niri` from `pkgs.niri` (stable nixpkgs) to `unstable.niri` in `niri.nix`.

## Why

The stable nixpkgs channel lags behind niri's upstream releases. Using `unstable.niri` ensures future SpectreOS builds and ISOs include newer niri versions automatically on each channel update.

The `<unstable>` channel and `let unstable = import <unstable> ...` binding were already present in `niri.nix` (used by noctalia-shell and noctalia-qs), so the change was minimal.

## Files Changed

- `niri.nix` — 5 references updated: lines in the AMD wrapper script, `niri-amd-session` derivation, and `environment.systemPackages`

## Notes

- Both `nixos` and `unstable` channels update together with `nix-channel --update`
- Watch niri's changelog for KDL config breaking changes after updates — these would be immediately visible at login
