# Kernel Bug Report: Platform Power Management Regression on AMD Ryzen AI 9 HX 370 (Strix Halo)

## Bugzilla Fields

- **Product:** Power Management
- **Component:** ACPI
- **Version:** 7.0.10–7.0.11
- **Severity:** regression

---

## Hardware

| Field | Value |
|---|---|
| Machine | ASUS ProArt PX13 (HN7306WU) |
| CPU | AMD Ryzen AI 9 HX 370 (Strix Halo / Zen 5) |
| iGPU | AMD Radeon 890M |
| dGPU | NVIDIA RTX 4050 Max-Q (disabled — supergfxd Integrated mode) |
| OS | NixOS 26.05 |
| amd-pstate driver | amd-pstate (passive mode, forced via kernel param) |

---

## Summary

Idle platform power draw is approximately 3x higher on kernel 7.0.10/7.0.11 compared to 7.0.5
on AMD Ryzen AI 9 HX 370 (Strix Halo). Battery life regresses from ~8 hours to ~2.5 hours
with identical workload (two terminals + Wayland compositor, no GPU load).

A secondary regression is also present: S0i3 (deepest suspend state) is not entered during
s2idle suspend, causing significant battery drain and elevated temperatures during sleep.

---

## Kernel Versions

| Version | Battery draw at idle | Estimated battery life | S0i3 suspend |
|---|---|---|---|
| 7.0.5 | ~5-6W | ~8 hours | Working |
| 7.0.10 | ~17W | ~2.5 hours | Failing |
| 7.0.11 | ~19-20W | ~2 hours | Failing |

---

## System State During Measurement

- NVIDIA dGPU: unloaded (supergfxd Integrated mode, `lsmod | grep nvidia` returns empty)
- AMD Radeon 890M (iGPU): ~5W measured via hwmon
- AMD NPU (amdxdna): runtime suspended
- CPU: 24 cores (Zen 5), all with EPP=power, reaching C3 idle state
- Workload: 2 terminal sessions + Niri Wayland compositor only
- power-profiles-daemon: power-saver profile active (ACPI platform_profile = quiet)
- amd_pstate: passive mode

---

## Suspend Regression

On 7.0.10 and 7.0.11, the AMD Platform Management Controller fails to reach S0i3:

```
amd_pmc AMDI000A:00: Last suspend didn't reach deepest state
```

This results in ~7% battery drain over a 20-minute suspend and temperatures rising from
~30°C to ~50°C on resume. The system is effectively not entering proper sleep.

---

## Investigation Results (2026-06-04)

**linux-firmware not the cause:** NixOS 25.11 nixpkgs (commit 8fd9daa3db09) also contains
linux-firmware-20260410 — the exact same version present in the regressed 26.05 system.
Generation 198 (7.0.5, good power) used this firmware. Pinning 26.05 to 25.11 firmware
made no difference. The AMD SMU firmware hypothesis is ruled out.

**amd_pmf not the cause:** `amd_pmf` (AMD Platform Management Framework) was blacklisted.
Note: at boot it logged `"No Smart PC policy present"`, meaning the AI power management was
not active. Blacklisting it produced no improvement in idle power.

**amd_pmc workarounds not the cause:** Setting `amd_pmc.disable_workarounds=1` produced no
improvement. S0i3 still not reached (not retested after this change, but idle power unchanged).

**amdxdna not the cause:** Blacklisting the NPU driver produced no change.

**GPU not the cause:** Forcing `power_dpm_force_performance_level=low` on the iGPU
increased power draw rather than reducing it, confirming the GPU is already near minimum
clocks. amdgpu measured at ~5W via hwmon.

**CPU C-states not the cause:** CPU reaches C3 on all cores. C-state availability
(POLL/C1/C2/C3) is identical between 7.0.5 and 7.0.10.

**ACPI GPP4 errors not the cause:** Present on both 7.0.5 and 7.0.10, not correlated.

**Partial mitigations (slight improvement only):**
- `amd_pstate=passive` kernel parameter
- `amdgpu.ppfeaturemask=0xffff7fff` (disables PP_GFXOFF)

---

## Suspected Cause

The regression is kernel-source-based, between 7.0.5 and 7.0.10. All package-level changes
tested (linux-firmware, amd_pmf, amd_pmc workarounds) have been ruled out through direct
comparison with a known-good generation using identical packages.

The symptoms — elevated idle power and S0i3 failure — both point to the platform not
correctly entering deep idle states at the hardware level. Likely culprits in the 7.0.5→7.0.10
kernel delta:

1. **amd_pmc driver changes** affecting how S0i3 entry is coordinated on Strix Halo.
   The `disable_workarounds` parameter had no effect, suggesting the issue is in the
   base driver logic rather than the platform-specific workaround paths.

2. **amdgpu FCLK/UCLK management**: On Strix Halo, GPU and CPU share LPDDR5X memory
   over a unified fabric. A change in how amdgpu manages fabric/memory clocks at idle
   could keep the entire SoC at elevated power even with the GPU otherwise idle.

Bisecting between 7.0.5 and 7.0.10 would identify the responsible commit. The ASUS
ProArt PX13 (HN7306WU) with Strix Halo is a reproducible test platform.

---

## Additional Context

A related PCIe MSI allocation regression (NVIDIA RTX 4050 Max-Q IRQ failure) was also
present in the 7.0.9/7.0.10 range and resolved in the NixOS 26.05 build of 7.0.10,
suggesting this kernel range has had multiple Strix Halo regressions.

ACPI SSDT tables present at boot: CPMPMF (AMD CPM Platform Management Framework power
limit tables) and OEMPMF (ASUS OEM PMF customization). These are read by amd_pmf but
are not the cause of the regression.
