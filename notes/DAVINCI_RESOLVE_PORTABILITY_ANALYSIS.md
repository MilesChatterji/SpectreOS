# DaVinci Resolve Fixes - Portability Analysis

**Date**: December 21, 2025  
**Purpose**: Analysis of DaVinci Resolve fixes for generic NixOS distribution

---

## Summary

### ✅ **Portable (Safe for All Systems)**
- Audio fixes (`.asoundrc`, `alsa-plugins`, audio environment variables)
- These work on any system with PipeWire

### ⚠️ **Needs Conditional Logic (GPU-Specific)**
- Desktop file using `nvidia-offload` wrapper
- `gpu-offload.nix` import (only if NVIDIA GPU detected)
- NVIDIA-specific environment variables

---

## Detailed Analysis

### 1. Audio Fixes (✅ Fully Portable)

#### `.asoundrc` Configuration
```nix
".asoundrc" = {
  text = ''
    pcm.!default {
      type pulse
    }
    ctl.!default {
      type pulse
    }
  '';
};
```

**Portability**: ✅ **100% Portable**
- Works on any system with PipeWire
- No GPU dependencies
- No hardware-specific assumptions
- Safe to include in all installations

#### `alsa-plugins` Package
```nix
home.packages = with pkgs; [
  alsa-plugins
];
```

**Portability**: ✅ **100% Portable**
- Generic ALSA plugin package
- Works on any Linux system
- No GPU dependencies

#### Audio Environment Variables in `nvidia-offload` Wrapper
```bash
export XDG_RUNTIME_DIR
export PIPEWIRE_RUNTIME_DIR="$XDG_RUNTIME_DIR"
export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"
export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
export ALSA_PCM_NAME=pulse
```

**Portability**: ✅ **Portable (but wrapper name is misleading)**
- These variables are generic PipeWire/PulseAudio variables
- Work on any system with PipeWire
- **Issue**: Wrapper is named `nvidia-offload` but contains generic audio fixes
- **Recommendation**: Extract audio fixes to a separate wrapper or apply them directly

---

### 2. GPU Fixes (⚠️ Needs Conditional Logic)

#### Desktop File with `nvidia-offload` Wrapper
```nix
".local/share/applications/davinci-resolve-studio.desktop" = {
  text = ''
    Exec=/run/current-system/sw/bin/nvidia-offload davinci-resolve-studio
  '';
};
```

**Portability**: ⚠️ **Needs Conditional Logic**

**Current Behavior**:
- Always uses `nvidia-offload` wrapper
- On systems without NVIDIA: Wrapper still exists but sets NVIDIA variables unnecessarily
- On systems with only NVIDIA: Works but wrapper is redundant
- On systems with only AMD/Intel: Works but wrapper is unnecessary

**Recommended Approach**:
```nix
# Detect if NVIDIA GPU is present
hasNvidia = config.hardware.nvidia.enable or false;

# Conditional desktop file
".local/share/applications/davinci-resolve-studio.desktop" = {
  text = ''
    Exec=${if hasNvidia 
      then "/run/current-system/sw/bin/nvidia-offload davinci-resolve-studio"
      else "davinci-resolve-studio"
    }
  '';
};
```

**Alternative**: Create a generic `davinci-resolve-audio` wrapper that:
- Always sets audio environment variables
- Only sets NVIDIA variables if NVIDIA is detected at runtime

---

#### `gpu-offload.nix` Import
```nix
# In configuration.nix or similar
imports = [
  ./gpu-offload.nix  # Only if NVIDIA GPU detected
];
```

**Portability**: ⚠️ **Needs Conditional Logic**

**Current Behavior**:
- `gpu-offload.nix` always enables NVIDIA drivers: `services.xserver.videoDrivers = [ "nvidia" ];`
- This will **FAIL** on systems without NVIDIA GPU
- System won't boot or will have graphics issues

**Recommended Approach**:
```nix
# Detect NVIDIA GPU presence
# Option 1: Check hardware-configuration.nix or lspci output
# Option 2: Make gpu-offload.nix conditional internally

# In gpu-offload.nix, make NVIDIA config conditional:
hardware.nvidia = lib.mkIf (config.hardware.nvidia.enable or false) {
  # ... NVIDIA config
};

# Or detect at install time and conditionally import:
imports = lib.optionals (hasNvidiaGpu) [
  ./gpu-offload.nix
];
```

---

#### `nvidia-offload` Wrapper Script
```bash
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export DRI_PRIME=1
export GBM_BACKEND=nvidia-drm
```

**Portability**: ⚠️ **Mostly Harmless but Unnecessary**

**Behavior on Non-NVIDIA Systems**:
- ✅ Won't break anything (variables are just ignored)
- ⚠️ Unnecessary overhead
- ⚠️ Misleading name suggests NVIDIA is required

**Behavior on Single GPU Systems**:
- ✅ Works fine (just uses the single GPU)
- ⚠️ Unnecessary wrapper

**Recommendation**: 
- Keep wrapper but make it detect NVIDIA at runtime
- Or create separate wrappers: `davinci-resolve-audio` (generic) + `nvidia-offload` (NVIDIA-specific)

---

## Recommended Implementation Strategy

### Option 1: Runtime Detection (Most Flexible)

Create a generic `davinci-resolve-launcher` wrapper:

```nix
davinci-resolve-launcher = pkgs.writeScriptBin "davinci-resolve-launcher" ''
  #!${pkgs.bash}/bin/bash
  
  # Always set audio environment variables (portable)
  if [ -n "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR
    export PIPEWIRE_RUNTIME_DIR="$XDG_RUNTIME_DIR"
    export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"
    export PULSE_SERVER="unix:$XDG_RUNTIME_DIR/pulse/native"
  fi
  export ALSA_PCM_NAME=pulse
  
  # Detect NVIDIA GPU at runtime
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    # NVIDIA GPU detected - use NVIDIA offload
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    export DRI_PRIME=1
    export GBM_BACKEND=nvidia-drm
  fi
  
  exec davinci-resolve-studio "$@"
'';
```

**Desktop file**:
```nix
Exec=/run/current-system/sw/bin/davinci-resolve-launcher
```

**Portability**: ✅ **100% Portable**
- Works on any system
- Automatically detects NVIDIA if present
- Falls back gracefully to single GPU or iGPU

---

### Option 2: Install-Time Detection (More Explicit)

Detect GPU during installation and conditionally configure:

```nix
# In install script or hardware detection
hasNvidia = checkNvidiaGpu();  # From lspci or /sys/class/drm

# In home.nix
".local/share/applications/davinci-resolve-studio.desktop" = {
  text = ''
    Exec=${if hasNvidia 
      then "/run/current-system/sw/bin/nvidia-offload davinci-resolve-studio"
      else "davinci-resolve-studio"
    }
  '';
};
```

**Portability**: ✅ **Portable with conditional logic**
- Requires GPU detection in install script
- More explicit about GPU usage
- Can be documented in hardware-configuration.nix

---

### Option 3: Separate Audio Wrapper (Cleanest Separation)

Create two wrappers:

1. **`davinci-resolve-audio`** (always applied):
   - Sets audio environment variables
   - Generic, works everywhere

2. **`nvidia-offload`** (only if NVIDIA):
   - Sets NVIDIA GPU variables
   - Wrapped by audio wrapper if NVIDIA detected

**Desktop file**:
```nix
Exec=${if hasNvidia
  then "/run/current-system/sw/bin/davinci-resolve-audio /run/current-system/sw/bin/nvidia-offload davinci-resolve-studio"
  else "/run/current-system/sw/bin/davinci-resolve-audio davinci-resolve-studio"
}
```

**Portability**: ✅ **Portable with clear separation**
- Audio fixes are always applied
- GPU fixes are conditional
- Clear separation of concerns

---

## Fallback Behavior Analysis

### Single GPU Systems (AMD or Intel only)

**Current Implementation**:
- ✅ Audio fixes work
- ⚠️ Desktop file uses `nvidia-offload` (unnecessary but harmless)
- ⚠️ NVIDIA variables are set (ignored, no harm)

**With Recommended Fixes**:
- ✅ Audio fixes work
- ✅ Desktop file uses appropriate launcher
- ✅ No unnecessary NVIDIA variables

### Single GPU Systems (NVIDIA only)

**Current Implementation**:
- ✅ Audio fixes work
- ✅ NVIDIA variables work
- ⚠️ Wrapper is technically unnecessary (but harmless)

**With Recommended Fixes**:
- ✅ Audio fixes work
- ✅ NVIDIA variables work
- ✅ Cleaner implementation

### Dual GPU Systems (AMD + NVIDIA)

**Current Implementation**:
- ✅ Audio fixes work
- ✅ NVIDIA variables work
- ✅ Forces NVIDIA usage (as intended)

**With Recommended Fixes**:
- ✅ Audio fixes work
- ✅ NVIDIA variables work
- ✅ Same behavior, cleaner code

---

## Implementation Checklist for Generic Distribution

### ✅ Always Include (Portable)
- [x] `.asoundrc` configuration
- [x] `alsa-plugins` package
- [x] Audio environment variables (extracted from `nvidia-offload`)

### ⚠️ Conditionally Include (GPU-Specific)
- [ ] `gpu-offload.nix` import (only if NVIDIA detected)
- [ ] Desktop file `nvidia-offload` usage (only if NVIDIA detected)
- [ ] NVIDIA driver configuration (only if NVIDIA detected)

### 🔧 Detection Methods

**Option A: Hardware Detection Script**
```bash
# During installation
if lspci | grep -qi nvidia; then
  HAS_NVIDIA=true
else
  HAS_NVIDIA=false
fi
```

**Option B: Check hardware-configuration.nix**
```nix
# Parse hardware-configuration.nix for GPU info
# Or check /sys/class/drm for NVIDIA devices
```

**Option C: Runtime Detection**
```bash
# In wrapper script
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  # NVIDIA present
fi
```

---

## Recommended Approach for Your Distribution

### 1. **Extract Audio Fixes to Generic Wrapper**
   - Create `davinci-resolve-audio` wrapper with only audio environment variables
   - Always apply this wrapper (100% portable)

### 2. **Make GPU Configuration Conditional**
   - Only import `gpu-offload.nix` if NVIDIA GPU detected
   - Detect during installation or at runtime

### 3. **Update Desktop File Logic**
   ```nix
   Exec=${if config.hardware.nvidia.enable or false
     then "/run/current-system/sw/bin/davinci-resolve-audio /run/current-system/sw/bin/nvidia-offload davinci-resolve-studio"
     else "/run/current-system/sw/bin/davinci-resolve-audio davinci-resolve-studio"
   }
   ```

### 4. **Document in hardware-configuration.nix**
   - Add comment about GPU detection
   - Note if NVIDIA is present or not

---

## Testing Checklist

For each hardware configuration:
- [ ] Single GPU (AMD only)
- [ ] Single GPU (Intel only)
- [ ] Single GPU (NVIDIA only)
- [ ] Dual GPU (AMD + NVIDIA)
- [ ] Dual GPU (Intel + NVIDIA)

Verify:
- [ ] DaVinci Resolve launches
- [ ] Audio works
- [ ] Video playback works
- [ ] Correct GPU is used (if applicable)

---

## Summary

**Portable Components** (safe for all systems):
- ✅ Audio configuration (`.asoundrc`)
- ✅ Audio packages (`alsa-plugins`)
- ✅ Audio environment variables

**Needs Conditional Logic**:
- ⚠️ GPU wrapper usage in desktop file
- ⚠️ `gpu-offload.nix` import
- ⚠️ NVIDIA driver configuration

**Recommended Solution**:
- Extract audio fixes to generic wrapper
- Use runtime or install-time GPU detection
- Conditionally apply GPU-specific fixes
- Document GPU detection in hardware-configuration.nix

