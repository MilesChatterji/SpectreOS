# NVIDIA Driver Logs – Troubleshooting Insight

**Date**: Current  
**Scope**: Review of logs after `nixos-rebuild switch`; no changes made.

---

## Current State

- **Kernel**: 6.18.9 (not 6.19 in this boot)
- **NVIDIA driver**: 580.119.02 (loaded and running)
- **GPU**: NVIDIA GeForce RTX 4050 Laptop GPU
- **Devices**: `/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-modeset`, `/dev/nvidia-uvm` all present with expected major numbers (195, 511)

So on this boot the NVIDIA stack is loaded and device nodes exist.

---

## Errors Seen in Logs

### 1. udev mknod failures (NVIDIA-related)

At boot, udev reports:

```text
nvidia: Process '... mknod -m 666 /dev/nvidiactl c 195 255' failed with exit code 1.
nvidia: Process '... mknod -m 666 /dev/nvidia${i} c 195 ${i}; done' failed with exit code 1.
```

**What this is**: The NVIDIA udev rules try to create `/dev/nvidiactl` and `/dev/nvidia0`, etc., with `mknod`. Those rules are failing (exit code 1).

**Why it might happen**:

- **Timing/race**: udev runs the rule before the NVIDIA kernel module has fully registered its major number (195) or before `/proc/driver/nvidia/gpus/*/information` is ready. Then `mknod` can fail (e.g. “device or resource busy”, or wrong state).
- **Already present**: If the kernel or another path already created the nodes, `mknod` might fail when trying to create them again.
- **Sandbox/permissions**: Less likely, but udev’s environment could affect `mknod` in some setups.

**Impact**: In your case the devices are present and have the right major/minor numbers. So either the kernel created them, or udev succeeded on a retry, or another mechanism created them. Functionally, NVIDIA is working despite these udev messages.

**Conclusion**: These are noisy udev messages rather than a sign that the driver or kernel 6.18.9 is broken. They’re worth being aware of but don’t require action unless you see missing `/dev/nvidia*` or apps failing to use the GPU.

---

### 2. Kernel 6.19 vs 6.18.9

You mentioned errors “around the nvidia drivers for kernel 6.19”. From the logs we only see a boot with **6.18.9**. So either:

- The “6.19” errors happened on a different boot (e.g. you tried 6.19, had issues, then booted back into 6.18.9), or  
- The rebuild pulled in something related to a 6.19 kernel (e.g. default or `linuxPackages_latest` moved to 6.19) and the errors appeared during build or when trying to boot that kernel.

**If the problem was with 6.19**:

- NixOS with `boot.kernelPackages = pkgs.linuxPackages_latest` will eventually give you 6.19 when nixpkgs updates.
- NVIDIA’s out-of-tree driver can lag behind new kernel versions. If 6.19 changed kernel APIs or device registration, the current NVIDIA driver (580.119.02) might not be fully compatible yet, leading to build failures or load/runtime errors on 6.19 only.
- Staying on 6.18.9 (e.g. by pinning `boot.kernelPackages` to a 6.18 kernel set) is a reasonable workaround until NVIDIA or nixpkgs adapt.

So: the logs we inspected are for 6.18.9; any “kernel 6.19” issues would show up when you actually boot or build for 6.19.

---

### 3. Other log messages (not NVIDIA driver bugs)

- **ACPI BIOS errors** (`\_SB.PCI0.GPP4._S0W`, etc.): firmware/ACPI table issue, common on some laptops, not an NVIDIA bug.
- **atkbd “Failed to enable keyboard”**: keyboard controller resume/suspend; often harmless.
- **asus_wmi / asus probe failed**: ASUS WMI or device probe; unrelated to NVIDIA.
- **cs35l41-hda Enable failed**: audio codec; unrelated to NVIDIA.
- **Electron coredumps / nix daemon assert**: application/nix bugs, not GPU driver.

None of these indicate an NVIDIA kernel driver bug.

---

## Summary Table

| Item                    | Status / Note                                      |
|-------------------------|-----------------------------------------------------|
| Kernel (this boot)      | 6.18.9                                              |
| NVIDIA driver           | 580.119.02 loaded and in use                        |
| /dev/nvidia*            | Present, major 195 (and 511 for uvm)                |
| udev mknod errors       | Present but non-fatal; devices exist                |
| Suspend/resume (NVIDIA) | nvidia-suspend / nvidia-resume services ran successfully |
| Kernel 6.19             | Not in this boot; 6.19 issues would be on 6.19 boot/build |

---

## If You See Real “6.19” Failures

When you do boot or build for kernel 6.19, typical possibilities:

1. **NVIDIA kernel module doesn’t build**  
   - Build log will show compiler/ABI errors in the NVIDIA tree.  
   - Mitigation: Stay on 6.18 (e.g. `pkgs.linuxPackages_6_18` or current stable) until nixpkgs/NVIDIA support 6.19.

2. **Module loads but udev/device nodes are wrong**  
   - Could be different major number or registration order on 6.19.  
   - The same udev mknod rules might need to be updated for 6.19; that’s usually in nixpkgs or NVIDIA’s udev rules.

3. **Runtime errors only on 6.19**  
   - Check `dmesg` and `journalctl -b` for “nvidia”/“NVRM”/“nvidia-drm” after booting 6.19.  
   - If you have a 6.19 boot, we can interpret those logs the same way as above.

---

## Bottom Line

- On **this** boot (6.18.9): NVIDIA driver and devices are fine; the only NVIDIA-related messages are udev mknod failures that didn’t prevent the devices from existing.
- **Kernel 6.19**: Not seen in this boot; if you have a 6.19 build or boot and get new errors, those would need to be checked separately (and possibly worked around by staying on 6.18 for a while).

No actions were taken; this is diagnostic insight only.
