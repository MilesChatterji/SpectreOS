# Noctalia Shell Version Clarification

## Version Confusion Explained

You're seeing a version mismatch between what's in `niri.nix` and what Noctalia Shell reports:

### The Two Version Numbers

1. **`version = "0.1.0"` in `niri.nix`** (line 301)
   - This is **arbitrary Nix derivation metadata**
   - It has **NO relation** to the actual Noctalia Shell version
   - It's just a placeholder value for the Nix package system
   - You could set it to "1.0.0" or "banana" and it wouldn't affect the actual Noctalia version

2. **Actual Noctalia Shell Version: 3.3.0**
   - This is the **real version** that Noctalia Shell reports
   - Determined by the actual code/commit from GitHub
   - Noctalia Shell uses semantic versioning: 3.3.0, 3.4.0, 3.5.0, etc.

### How It Works

Your `niri.nix` configuration:
```nix
noctalia-shell = pkgs.stdenvNoCC.mkDerivation rec {
  pname = "noctalia-shell";
  version = "0.1.0";  // ← This is just Nix metadata, ignored by Noctalia
  
  src = pkgs.fetchFromGitHub {
    owner = "noctalia-dev";
    repo = "noctalia-shell";
    rev = "main";  // ← This determines what code you get
    sha256 = "sha256-pWz6IWgG614EoVxPY6tlEsurZMznBvbyliI3go1BAuY=";  // ← This pins the commit
  };
  ...
}
```

The actual version (3.3.0) comes from:
- The commit on the `main` branch that your SHA256 corresponds to
- That commit happens to be from around the v3.3.0 release timeframe

### Current Status

- **Installed**: v3.3.0 (released 2025-11-23)
- **Available**: v3.5.0 (released 2025-12-01)
- **Difference**: 2 minor versions behind (3.3.0 → 3.4.0 → 3.5.0)

### Why You're Seeing the Update Prompt

Noctalia Shell checks for updates and found:
- You're running: **3.3.0**
- Latest available: **3.5.0**
- It's prompting you to update

### To Update (When Ready)

If you want to update to v3.5.0, you have two options:

#### Option 1: Pin to Specific Release (Recommended)
```nix
src = pkgs.fetchFromGitHub {
  owner = "noctalia-dev";
  repo = "noctalia-shell";
  rev = "v3.5.0";  // ← Pin to specific release
  sha256 = "sha256-XXXXX";  // ← Get new hash with: nix-prefetch-github noctalia-dev noctalia-shell --rev v3.5.0
};
```

#### Option 2: Stay on Latest Main
```nix
src = pkgs.fetchFromGitHub {
  owner = "noctalia-dev";
  repo = "noctalia-shell";
  rev = "main";  // ← Stay on latest main
  sha256 = "sha256-XXXXX";  // ← Get new hash with: nix-prefetch-github noctalia-dev noctalia-shell --rev main
};
```

### Summary

- **"0.1.0"** = Nix metadata (meaningless)
- **"3.3.0"** = Actual Noctalia Shell version (what matters)
- **"3.5.0"** = Latest available version
- The prompt is correct - you are 2 versions behind

---

**Last Updated**: $(date +%Y-%m-%d)

