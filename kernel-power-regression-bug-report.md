# Kernel Bug Report: Platform Power Management Regression on AMD Ryzen AI 9 HX 370 (Strix Halo)

## Bugzilla Fields

- **Product:** Power Management
- **Component:** ACPI
- **Version:** 7.0.10
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
| amd-pstate driver | amd-pstate-epp (active mode) |

---

## Summary

Idle platform power draw is approximately 3x higher on kernel 7.0.10 compared to 7.0.5
on AMD Ryzen AI 9 HX 370 (Strix Halo). Battery life regresses from ~8 hours to ~2.5 hours
with identical workload (two terminals + Wayland compositor, no GPU load).

---

## Kernel Versions

| Version | Battery draw at idle | Estimated battery life |
|---|---|---|
| 7.0.5 | ~5-6W | ~8 hours |
| 7.0.10 | ~17W | ~2.5 hours |

Tested on NixOS 26.05 with same configuration, same hardware, same BIOS. Only the kernel
version differs.

---

## System State During Measurement

- NVIDIA dGPU: unloaded (supergfxd Integrated mode, `lsmod | grep nvidia` returns empty)
- AMD Radeon 890M (iGPU): 3W measured via hwmon, shader clock 638 MHz
- AMD NPU (amdxdna): runtime suspended
- CPU: 24 cores (Zen 5), all with EPP=power, reaching C3 idle state
- Workload: 2 terminal sessions + Niri Wayland compositor only
- power-profiles-daemon: power-saver profile active (ACPI platform_profile = quiet)

---

## Investigation Results

**GPU not the cause:** Forcing `power_dpm_force_performance_level=low` on the iGPU
increased power draw rather than reducing it, confirming the GPU is already near minimum
clocks. amdgpu measured at 3W via hwmon in both states.

**CPU C-states not the cause:** CPU reaches C3 on all cores. C3 residency is high (nearly
full uptime). C-state availability (POLL/C1/C2/C3) is identical between 7.0.5 and 7.0.10.

**ACPI GPP4 errors not the cause:** Boot log shows ACPI duplicate object errors for
`\_SB.PCI0.GPP4._S0W/_PR0/_PR3` (PCIe root port for SD card reader, 0000:00:02.2).
These errors are present on **both** 7.0.5 and 7.0.10 and do not correlate with the
power regression.

**NPU driver not the cause:** `amdxdna` module loaded but device shows
`runtime_status=suspended` with sustained suspended time. Power unchanged when tested
without it.

**Partial mitigations (slight improvement only):**
- `amd_pstate=passive` kernel parameter
- `amdgpu.ppfeaturemask=0xffff7fff` (disables PP_GFXOFF)

Neither resolved the regression. Root cause remains in the 7.0.5→7.0.10 kernel delta.

---

## Suspected Cause

An unknown regression between 7.0.5 and 7.0.10 affecting platform power management on
AMD Strix Halo. The elevated draw appears to come from the CPU/SoC fabric rather than
any individual peripheral. Likely candidates:

1. A change in amd-pstate, amdgpu DPM, or AMD platform driver affecting how the Strix
   Halo SoC fabric (FCLK/UCLK/memory subsystem) manages idle power states.
2. A change in how the AMD SMU (System Management Unit) is initialised or communicated
   with, causing the platform to remain in a higher power state.

Bisecting between 7.0.5 and 7.0.10 would identify the responsible commit. The ASUS
ProArt PX13 (HN7306WU) with Strix Halo is a reproducible test platform.

---

## Additional Context

A related PCIe MSI allocation regression (NVIDIA RTX 4050 Max-Q IRQ failure) was also
present in the 7.0.9/7.0.10 range and resolved in the NixOS 26.05 build of 7.0.10,
suggesting this kernel range has had multiple Strix Halo regressions.
