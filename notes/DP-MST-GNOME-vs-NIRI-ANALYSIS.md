# DP-MST: GNOME vs Niri Comparison Analysis

## Summary
GNOME successfully enables all 3 displays (including daisy-chained DP-11), but Niri cannot enable DP-11 due to a DRM atomic state error.

## Key Finding: "Error testing state" in Niri

**Niri Error (from logs):**
```
Error testing state on device `/dev/dri/card2` (Invalid argument (os error 22))
```

This error occurs when Niri tries to connect DP-11. The error happens during DRM compositor creation, specifically when testing the atomic state of the connector.

## GNOME Success Pattern

**GNOME Logs (19:35:43 - 19:36:18):**
- Successfully added device `/dev/dri/card2` using atomic mode setting
- Created GBM renderer for card2
- DP-11 was successfully configured and enabled
- Multiple atomic commits succeeded

**Key GNOME Messages:**
```
Added device '/dev/dri/card2' (amdgpu) using atomic mode setting.
Created gbm renderer for '/dev/dri/card2'
GPU /dev/dri/card2 selected primary from builtin panel presence
```

## Niri Failure Pattern

**Niri Logs (19:40:11 - 19:40:12):**
- Detects DP-11 connector correctly
- Attempts to connect DP-11
- **Fails** with "Error testing state" when creating DRM compositor
- Falls back to "invalid modifier" mode
- DP-11 remains disabled

**Key Niri Messages:**
```
DEBUG: connecting connector: DP-11
WARN: error creating DRM compositor, will try with invalid modifier: 
  DrmError(Access(AccessError { errmsg: "Error testing state", 
  dev: Some("/dev/dri/card2"), 
  source: Os { code: 22, kind: InvalidInput, message: "Invalid argument" } }))
```

## CRTC Allocation

Both compositors attempt to use the same CRTCs:
- **DP-9 (working)**: Uses `CRTC:90:crtc-1`
- **DP-11 (failing)**: Attempts to use `CRTC:94:crtc-2`

Both are on the same AMD card (card2), so CRTC allocation is not the issue.

## Atomic State Analysis

**From kernel logs:**
- DP-11 atomic states are being created and linked to CRTC-2
- The kernel accepts the atomic state configuration
- However, when Niri tries to **test** the state (before committing), it fails with "Invalid argument"

**Timeline:**
1. **19:35:43**: GNOME successfully configures DP-11
2. **19:40:11**: GNOME session ends
3. **19:40:11**: Niri starts and detects DP-11
4. **19:40:12**: Niri fails to test DP-11 state (Invalid argument)

## Possible Root Causes

### 1. **MST Topology State Inconsistency**
After GNOME releases the MST connector, the topology state might be left in an inconsistent state that Niri cannot query. The "Error testing state" suggests Niri is trying to validate the atomic state before committing, but the state is invalid.

### 2. **Timing/Race Condition**
Niri might be trying to test the state before the MST topology is fully ready after GNOME released it. There might be a brief window where the state is transitioning.

### 3. **Atomic State Validation Differences**
GNOME (Mutter) and Niri (wlroots) might handle atomic state validation differently:
- **GNOME/Mutter**: May be more tolerant of certain state configurations
- **Niri/wlroots**: May perform stricter validation that fails on MST connectors

### 4. **MST Port State**
The MST port (00000000a2de7c45) might be in a state that Niri's state testing cannot handle. The kernel logs show the port is configured, but Niri's validation fails.

## What GNOME Does Differently

1. **State Testing**: GNOME might not perform the same "test state" operation that Niri does, or it handles errors differently
2. **MST Initialization**: GNOME might wait longer or handle MST topology initialization differently
3. **Error Recovery**: GNOME might have better error recovery for MST state issues
4. **Atomic Commit Flags**: GNOME might use different atomic commit flags that are more compatible with MST

## Current System State

- **DP-9**: Connected and enabled (working)
- **DP-11**: Connected but disabled (failing)
- **eDP-1**: Connected and enabled (internal display)
- **DRM Debug**: `0x1e` (comprehensive debugging enabled)

## Recommendations (No Changes Yet)

Since you want to keep the system stable and think about this first:

1. **Document the Issue**: This analysis captures the problem
2. **Monitor for Updates**: Watch for Niri/wlroots updates that might fix MST state testing
3. **Workaround Options** (for future consideration):
   - Use GNOME for multi-monitor MST setups
   - Wait for Niri/wlroots MST improvements
   - Investigate if there's a Niri configuration option to skip state testing
   - Check if there's a way to reset MST topology state before Niri starts

## Technical Details

**Error Code**: `EINVAL (22)` - Invalid argument
**Operation**: `drmModeAtomicTest()` or similar state testing function
**Device**: `/dev/dri/card2` (AMD iGPU)
**Connector**: DP-11 (MST daisy-chained monitor)

The error occurs in Niri's DRM backend when it tries to validate an atomic state before committing it. This is a safety check to ensure the state is valid, but it's failing for DP-11's MST state.

