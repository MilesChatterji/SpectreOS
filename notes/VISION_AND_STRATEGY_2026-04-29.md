# SpectreOS Vision & Strategy
**Date:** 2026-04-29  
**Context:** Strategic review conversation covering project identity, roadmap sequencing, and tooling decisions.

---

## Project Identity

SpectreOS is an opinionated NixOS derivative in the spirit of Garuda Linux's relationship to Arch. It does not need its own package repositories to earn this label. What earns it:

- A custom installer that produces a SpectreOS experience
- Original UI work via a Noctalia fork/contribution
- A GUI updater that abstracts NixOS complexity
- Coherent branding, philosophy, and target audience
- Original hardware integration work (ambient light, DialPad, GPU offload)

**The label is earned at the installer milestone.** Until someone who isn't the developer can install it, it is a sophisticated personal configuration with a name and a vision.

---

## Target Audience

People who want the power of NixOS but are turned off by the from-scratch learning curve. SpectreOS gives them a curated, working starting point that is designed to be *read and learned from* — surfacing NixOS's complexity in a structured way rather than hiding it. Focus areas: aesthetics, privacy, and creativity.

Users can swap to GNOME, remove Noctalia, or modify anything declaratively at will. Modularity is a feature, not an afterthought — and NixOS makes this stronger here than it could be on any other base.

---

## Roadmap Sequencing Decisions

### 1. Barebones Installer First
Ship the installer before the GUI updater and polished Noctalia widgets. It earns the label early and is the most effective recruiting tool for contributors. People contribute to things they can install, not configs they have to manually apply.

### 2. iGPU-Only for v1
- Simpler hardware detection logic
- Testable inside VMs on the same machine
- Covers the vast majority of modern laptops
- NVIDIA dGPU support added in a subsequent release

### 3. Noctalia Strategy
Attempt upstream PR contribution first (power management, auto-brightness, keyboard backlight widgets). If maintainers accept and maintain it — ideal. If not, maintain a fork with an automated patch-on-release workflow (`git format-patch` / `git am`) so each new Noctalia release requires minimal manual effort to rebase SpectreOS changes onto.

### 4. Installer + GUI Updater Developed Together
Not the same tool, but developed in parallel. The updater abstracts `nixos-rebuild switch` and `home-manager switch` behind a GUI — a meaningful differentiator for the target audience.

---

## VM Testing Strategy

Test the installer inside QEMU/KVM VMs on the same machine before touching real hardware. This gives three things at once:

1. Installer validation in a controlled environment
2. Virtualization capability proven as a SpectreOS feature (relevant to the creative/developer audience)
3. A natural risk progression: iGPU VM → NVIDIA VM (VFIO passthrough) → real dedicated hardware

NixOS's declarative nature makes this loop fast — blow away the VM, re-test from scratch, no ambiguous state.

---

## Tooling Decisions

### Hypervisor: virt-manager / QEMU / KVM
Chosen over VMware Workstation for the following reasons:
- KVM is in-kernel — no proprietary kernel modules to maintain. On kernel 7.0, VMware Workstation modules are likely not available.
- Performance is near-native for this use case (virtio drivers, KVM CPU acceleration)
- VFIO GPU passthrough is the better story for future NVIDIA VM testing
- No Windows VMs needed — the one area where Workstation has an edge is irrelevant here

### Windows Strategy
Cloud-delivered Windows (subscribe, connect via app, cancel anytime) rather than local VMs. Better performance on optimized cloud hardware, no licensing overhead, no storage/RAM cost on the local machine. Aligns with the SpectreOS philosophy of keeping the local environment clean and Linux-native.

---

## Summary

SpectreOS has a coherent identity, a defined audience, and a clear path to earning the derivative OS label. The remaining work is execution. The installer is the priority milestone — ship it barebones, get users on it, build a contributor base from there.
