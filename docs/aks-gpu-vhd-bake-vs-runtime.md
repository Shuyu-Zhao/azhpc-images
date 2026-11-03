# AKS GPU VHD: Bake-Time vs. Runtime Component Split

Status: Technical exploration (no final design or delivery commitment)
Scope: Dedicated AKS GPU VHD, **Ubuntu 24.04, AMD64, NVIDIA CUDA (non-GRID) drivers**

## Background

AKS and the Azure HPC/AI Images team are exploring reuse of `azhpc-images` GPU components to
build dedicated AKS GPU VHDs and reduce GPU node provisioning time (Oct 9–15, 2026 discussion).

- AKS today uses a shared Linux VHD for GPU and non-GPU nodes; GPU drivers are cached in the
  VHD and installed/configured during CSE.
- **0→1** (first node from a base image) benefits from pre-installed drivers in a dedicated GPU
  VHD. **1→N** (scale-out) is addressed by PIS (Pre-Provisioned Image Snapshots).
- AKS feedback: open to `aks-gpu` or native packages; prioritize Ubuntu 24.04 AMD64; Ubuntu 26.04
  is a possible additional target; also explore prefetch optimization.

References:
- https://github.com/Azure/AgentBaker/tree/main/vhdbuilder/packer
- https://github.com/Azure/aks-gpu
- https://github.com/Azure/azhpc-images

## Current State in AgentBaker

- `vhdbuilder/packer/install-dependencies.sh` caches the `aks-gpu-cuda-lts` driver image in the
  VHD. With the opt-in `NVIDIA_CUDA_PREBAKE` feature flag, `buildNVIDIAKernelModule` runs aks-gpu
  in `build-only` mode to compile/DKMS-register the kernel module against the VHD kernel and write
  `/opt/azure/aks-gpu/dkms-marker` (saves ~100s of in-CSE DKMS compile).
- At node boot, `parts/linux/cloud-init/artifacts/cse_config_gpu.sh` (`configGPUDrivers`) still
  runs the aks-gpu container (`install-skip-build` when the marker matches), which:
  - copies userspace libs into `/usr/lib/x86_64-linux-gnu` and runs `ldconfig`,
  - installs NVIDIA Fabric Manager (`fm_run_package_installer.sh`),
  - installs the NVIDIA Container Toolkit, writes the containerd runtime drop-in and udev rules.
- `configureManagedGPUExperience` installs DCGM / dcgm-exporter / device plugin packages from
  cache during CSE and starts them.
- `configureGraceBlackwell` (arm64 GB VHD) already demonstrates the fully baked model: drivers,
  DOCA, DCGM and device plugin installed at VHD build time via a pinned BOM.

**Takeaway:** the kernel compile is already removable from boot; most remaining boot-time cost is
the userspace/Fabric Manager/toolkit/managed-experience install steps.

## Guiding Rule

> **Bake** anything that depends only on *(OS, kernel, driver version, architecture)*.
> **Defer to runtime** anything that depends on *the physical device, the VM SKU, cluster/customer
> configuration, licenses/secrets, or Kubernetes node identity*.

A useful middle category is **"install at bake time, activate at runtime"**: the package and
systemd unit are in the image, gated by systemd `Condition*=` directives or enabled by CSE.

## Bake Into the Image

| Component | Notes | azhpc-images source |
|---|---|---|
| Nouveau blacklist + `update-initramfs` | Device-independent | `packer/scripts/prerequisites.sh` |
| NVIDIA driver (kernel module + userspace in standard paths) | Pin version (`nvidia-driver-pinning-<ver>`), `nvidia-open` (proprietary for V100). Hold/pin the kernel so DKMS doesn't rebuild at boot | `components/install_nvidiagpudriver.sh` |
| `nvidia-modprobe`, `nvidia-persistenced` unit | Install now; enable persistence mode at boot | `components/configure_nvidia_persistence.sh` |
| NVIDIA Fabric Manager | Must exactly match driver version. Move out of aks-gpu boot path. Unit enabled but conditioned on NVSwitch presence | `components/install_nvidia_fabric_manager.sh` |
| NVIDIA Container Toolkit, `nvidia-ctk`, containerd `10-nvidia-runtime.toml`, char-dev udev rules, CDI refresh unit | Static configuration | `components/install_nvidia_container_toolkit.sh` |
| DCGM, dcgm-exporter, device plugin, DRA driver binaries | Installed but **disabled**; CSE enables per cluster mode | `components/install_dcgm.sh` |
| SKU customization scripts + topology files | Scripts only; executed at runtime | `components/setup_sku_customizations.sh`, `topology/` |
| `nvidia-peermem`, DOCA/OFED (RDMA SKUs only) | Install DOCA/OFED before the driver. Large; consider a separate image flavor or a later phase | `components/install_doca.sh` |

## Keep at Runtime (CSE)

| Step | Reason |
|---|---|
| `nvidia-modprobe -u -c0`, `nvidia-smi` validation, `ldconfig`, enable persistence mode | Requires the device |
| Start Fabric Manager; SKU topology setup; load `nvidia-peermem` | SKU-dependent (IMDS `vmSize`) |
| MIG partitioning and MIG strategy | Customer configuration |
| Device plugin vs. DRA vs. none; enable dcgm-exporter; node labels | Cluster configuration |
| CDI spec generation; containerd/kubelet restart | Needs device enumeration |
| GRID driver (A10, NVv5) | Different driver family + licensing; out of current scope |
| `--gpu-driver None` / bring-your-own driver | A baked driver conflicts with GPU Operator; route these nodes to the shared VHD |
| Fallback rebuild on kernel/driver marker mismatch | Safety net for VHD/CSE version skew |

## Do Not Bake Into the AKS Node Image

- CUDA toolkit, NCCL, MPI, other HPC user-space libraries: workloads ship these in containers.
- Host `/etc/nccl.conf`: not visible to pods.

## Open Questions for the Technical Sync

1. **aks-gpu vs. native packages.** Native apt (as in azhpc-images) makes baking straightforward
   and removes the container step from boot. aks-gpu `build-only` only moves the compile.
2. **Signed precompiled modules.** Ubuntu's `linux-modules-nvidia-*-azure` packages avoid DKMS and
   the compiler toolchain, and are Secure Boot / Trusted Launch friendly, but may lag NVIDIA
   driver releases.
3. **Prefetch.** AgentBaker `vhdbuilder/prefetch` warms disk blocks during image optimization.
   Extend its file list to baked GPU artifacts (`nvidia.ko`, `libcuda`, `nvidia-smi`,
   Fabric Manager, DCGM) to further improve 0→1.
4. **Image size.** Once the driver is baked, drop the cached aks-gpu container image from the VHD.
5. **Kernel coupling.** Define the policy for kernel updates (unattended-upgrades, DKMS
   autoinstall) so a baked module never mismatches the booted kernel.
6. **Representative SKU** for a joint experiment (e.g., ND H100 v5 to cover Fabric Manager +
   RDMA, or NC A100 v4 for a simpler first pass).
