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
