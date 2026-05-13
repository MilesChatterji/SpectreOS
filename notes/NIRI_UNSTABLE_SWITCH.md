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

---

## Noctalia Shell Simplification (2026-05-12)

Removed the custom `stdenvNoCC` derivation that was manually tracking noctalia-shell releases via `fetchFromGitHub`. Switched to `unstable.noctalia-shell` from nixpkgs unstable, same as noctalia-qs.

### What changed

- Deleted ~70 lines of custom derivation code (pname, version, src, buildInputs, runtimeDeps, wrappers, etc.)
- `noctalia-shell` references in `niri.nix` now point to `unstable.noctalia-shell`
- Simplified `noctalia.service` PATH and environment — the upstream nixpkgs package bakes in runtime deps (brightnessctl, cliphist, etc.) so manual PATH wrangling is no longer needed
- Updated swayidle lock screen calls to use `unstable.noctalia-shell` path instead of the old custom derivation

### Why

The upstream nixpkgs unstable package now handles everything the custom derivation was doing. Maintaining a custom derivation meant manually bumping versions and hashes — unnecessary now that it's in nixpkgs.

### Notes

- Future SpectreOS builds should use `unstable.noctalia-shell` — no custom derivation needed
- If noctalia-shell ever needs to track a version ahead of nixpkgs unstable, the old derivation pattern can be restored from git history (`f89d6b9`)

---

## Blur Configuration (2026-05-13)

Added blur support to `~/.config/niri/config.kdl` (not tracked in this repo — user config).

### Changes made

1. **Global blur parameters** added after the animations comment block:
```kdl
blur {
    passes 3
    offset 3
    noise 0.02
    saturation 1.5
}
```

2. **Ghostty window rule** added to force blur (Ghostty's `background-blur` is macOS-native; on Wayland niri must apply it directly):
```kdl
window-rule {
    match app-id=r#"^com\.mitchellh\.ghostty$"#
    background-effect {
        blur true
    }
}
```

### Notes

- Ghostty config has `background-opacity = 0.65` and `background-blur = true` — the opacity is what makes blur visible
- Noctalia Shell panel surfaces request blur themselves via `ext-background-effect` protocol — no layer-rule needed
- Noctalia settings panel does not yet support blur — leave it for upstream to implement
- Future SpectreOS default configs should include these blur rules
