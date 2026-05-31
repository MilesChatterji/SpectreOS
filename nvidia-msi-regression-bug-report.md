# Kernel Bug Report: PCIe MSI Allocation Failure for NVIDIA RTX 4050 Max-Q on Strix Halo

## Bugzilla Fields

- **Product:** Drivers
- **Component:** PCI
- **Version:** 7.0.10
- **Severity:** regression

---

## Hardware

| Field | Value |
|---|---|
| Machine | ASUS ProArt PX13 (HN7306WU) |
| CPU | AMD Ryzen AI 9 HX 370 (Strix Halo / Zen 5) |
| iGPU | AMD Radeon 890M |
| dGPU | NVIDIA RTX 4050 Max-Q (AD107, PCI 0000:c4:00.0, device 10DE:28A1) |
| NVIDIA audio | AD107 HD Audio (PCI 0000:c4:00.1, device 10DE:22BE) |
| PCIe root port | 0000:00:03.1 |
| IOMMU group | Both c4:00.0 and c4:00.1 in group 19 |
| OS | NixOS 25.11 |
| NVIDIA driver | 595.71.05 |

---

## Summary

The NVIDIA RTX 4050 Max-Q (Ada Lovelace) fails to initialize on kernel 7.0.9 and
7.0.10. The driver reports `NVRM: Can't find an IRQ for your NVIDIA card!` and probe
fails with error -1. The same hardware and driver worked correctly on kernel 7.0.3
and 7.0.5.

Ada Lovelace GPUs require MSI for GSP firmware — there is no INTx fallback. When
MSI allocation fails the driver cannot load.

---

## Kernel Versions

| Version | Result |
|---|---|
| 7.0.3 | **Working** — nvidia-smi succeeds, PRIME offload functional |
| 7.0.5 | **Working** |
| 7.0.9 | **Broken** — NVRM: Can't find an IRQ |
| 7.0.10 | **Broken** — same error |

---

## dmesg (kernel 7.0.10, clean boot, no userspace GPU management daemon)

```
[    0.264622] pci 0000:c4:00.0: [10de:28a1] type 00 class 0x030000 PCIe Legacy Endpoint
[    0.264703] pci 0000:c4:00.0: PME# supported from D0 D3hot
[    0.265041] pci 0000:c4:00.1: [10de:22be] type 00 class 0x040300 PCIe Endpoint
[    0.313956] pci 0000:c4:00.1: extending delay after power-on from D3hot to 20 msec
[    0.313979] pci 0000:c4:00.1: D0 power state depends on 0000:c4:00.0
[    0.315169] pci 0000:c4:00.0: Adding to iommu group 19
[    0.315176] pci 0000:c4:00.1: Adding to iommu group 19
[    2.691871] snd_hda_intel 0000:c4:00.1: enabling device (0000 -> 0002)
[    2.692230] snd_hda_intel 0000:c4:00.1: Disabling MSI
[    4.352526] nvidia 0000:c4:00.0: enabling device (0000 -> 0003)
[    4.352587] NVRM: Can't find an IRQ for your NVIDIA card!
[    4.352588] NVRM: Please check your BIOS settings.
[    4.352588] NVRM: [Plug & Play OS] should be set to NO
[    4.352588] NVRM: [Assign IRQ to VGA] should be set to YES
[    4.352610] nvidia 0000:c4:00.0: probe with driver nvidia failed with error -1
[    4.352628] NVRM: The NVIDIA probe routine failed for 1 device(s).
[    4.352628] NVRM: None of the NVIDIA devices were initialized.
```

The driver retries 3 times at ~1 second intervals, then once more at ~122 seconds.
All attempts fail identically.

After probe failure the GPU disappears from the PCIe bus (no longer visible in
`lspci`). Writing `on` to `power/control` does not restore it. The device must be
power cycled via reboot.

**Note:** `snd_hda_intel` on c4:00.1 disables MSI and falls back to INTx
successfully. MSI is failing specifically at the nvidia driver's MSI allocation
step, not at a global bus level.

---

## Additional Regression: PCIe Hotplug Slot Power Write

On kernel 7.0.5, writing to `/sys/bus/pci/slots/0-2/power` (the PCIe hotplug slot
for the downstream bus containing the GPU) succeeds and allows the GPU to be power
cycled. On 7.0.9 and 7.0.10 this write fails:

```
Write /sys/bus/pci/slots/0-2/power: No such device (os error 19)
```

On 7.0.3 and 7.0.5, the GPU was power cycled through this mechanism before the
nvidia driver probed. This power cycle may have been a necessary precondition for
MSI allocation to succeed. The simultaneous regression of this write suggests a
related root cause.

---

## Kernel Parameters Tested — All Fail Identically

| Parameter | Result |
|---|---|
| `iommu=pt` | Fails |
| *(no iommu param — full IOMMU mode)* | Fails |
| `amd_iommu=off` | Fails (tested on 7.0.9) |
| `intremap=off` | Fails (tested on 7.0.10) |

The failure is identical regardless of whether IOMMU interrupt remapping is active,
in passthrough mode, or disabled entirely. This rules out the IOMMU interrupt
remapping tables as the root cause.

---

## Other Factors Ruled Out

- GPU management daemon (supergfxd) disabled entirely — same result
- NVIDIA driver version unchanged between working (7.0.3) and broken (7.0.9+) — 595.71.05
- `udev power/control=on` applied at device-add time — does not prevent disappearance after failed probe
- PX13 firmware does not support RTD3 (`_PR3` ACPI method absent) — not a factor
- ASUS firmware does not expose `dgpu_disable` WMI attribute — not a factor

---

## Suspected Cause

A regression between 7.0.5 and 7.0.9 in one of:

1. **PCIe MSI allocation** for devices on downstream buses behind an AMD PCIe root
   complex on Strix Halo. The MSI request fails before or independently of the IOMMU
   interrupt remapping layer (since disabling interrupt remapping entirely with
   `intremap=off` does not help).

2. **PCIe hotplug slot power control** — the write to `/sys/bus/pci/slots/N/power`
   regressed on 7.0.9+, preventing the GPU from being power cycled into a state where
   MSI allocation succeeds (which appears to have been an implicit precondition on
   7.0.5 and earlier).

Bisecting between 7.0.5 and 7.0.9 would identify the responsible commit. The ASUS
ProArt PX13 (HN7306WU) with Strix Halo + RTX 4050 Max-Q is a reproducible test
platform for this regression.
