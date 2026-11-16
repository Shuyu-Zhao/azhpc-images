# AKS GPU Provisioning Time (0→1): Sync Prep

Status: Meeting prep for the AKS sync on 2026-11-16 (no design or delivery commitment)
Related: [aks-gpu-vhd-bake-vs-runtime.md](aks-gpu-vhd-bake-vs-runtime.md)

## 1. Goals for the Meeting

1. Agree that the HPC Images team owns, or co-owns, the **GPU layer of a dedicated AKS GPU VHD**
   (Ubuntu 24.04 AMD64 first; Ubuntu 26.04 optional).
2. Fallback: AgentBaker consumes `azhpc-images` component scripts and version pins (BOM), and
   our validation runs as a release gate.
3. Leave with a named owner on each side, a small pilot (one SKU family), and a success metric:
   seconds saved in 0→1 provisioning.

## 2. Corrections to Our Earlier Summary (confirm with AKS)

AKS said our earlier description of the prebake was not framed accurately. From AgentBaker code:

- **Prebake is not a full install.** `buildNVIDIAKernelModule` runs aks-gpu in `build-only`
  mode: it only compiles and DKMS-registers the R580 kernel module and stages the user-space
  libraries, with no GPU access. At boot, CSE still runs aks-gpu in `install-skip-build` mode:
  it loads the driver, installs the container toolkit and fabric manager, and sets up containerd
  and udev from the cached image. *Ask: how many seconds does this boot-time step still take?*
- **Prebake is on in production.** VHD release notes for Ubuntu 22.04 and 24.04 list
  `nvidia-cuda-driver-prebaked=580.159.04`. It is x86 only.
- **The shared VHD has real costs.**
  - Non-GPU nodes and opted-out GPU nodes (`--gpu-driver None`) must remove the prebaked driver
    (`cleanUpPrebakedGPUDriver`).
  - The CUDA driver loads automatically at boot.
  - The `nvidia.ko` module is rebuilt on every kernel patch.
  - GRID nodes (A10, NVv5) must remove the CUDA driver first (`cleanUpGridNodeCudaPrebake`), or
    `nvidia-smi` fails with an NVML driver/library version mismatch.
- **A dedicated GPU VHD already exists for Grace-Blackwell (arm64, Ubuntu 24.04).**
  `configureGraceBlackwell` does not use aks-gpu. It installs native packages at build time from
  `vhdbuilder/packer/gb-mai-bom.json` in three waves:
  1. DOCA-OFED
  2. Driver 580
  3. CUDA 13, container toolkit, and DCGM
- **We already have an AKS build target.** `azhpc-images` has an `azure_vm_akshost` target
  (`distros/ubuntu24.04/install_aks.sh`: DOCA and the driver only), currently limited to
  GB200/GB300. *Confirm internally whether this already feeds AKS's GB image; if so, it is our
  strongest proof point.*
- **Driver versions have drifted.** AKS uses `580.159.04`; `azhpc-images` Ubuntu 24.04 x86 uses
  `580.178.04` (`versions.json`). This is a concrete argument for shared version pins.

## 3. Questions to Raise

### A. Baseline and Targets
- What is the current 0→1 time for GPU nodes, broken down by CSE step? Steps: driver, toolkit
  and fabric manager, MIG, device plugin, DCGM, image pulls.
- What is the target (p50 and p99), and who measures it?
- How much of the remaining time is GPU work versus base setup (containerd, kubelet, networking)?
- Which SKUs dominate usage (H100/H200, A100, T4, A10)?

### B. Dedicated GPU VHD Scope
- Will there be one image per driver line (cuda-lts R580, R595, grid, grid-v20), or one image
  per SKU family?
- How does the AKS RP pick the image? Is a new image SKU or catalog entry needed?
- How do customers using `--gpu-driver None` or the GPU Operator get a driver-free image?
- Should DOCA/OFED and InfiniBand be included for ND SKUs, or only some?
- Is there a timeline, and is it funded or planned?

### C. Driver Delivery
- Keep aks-gpu in the image with a verify-only boot step, or move to native packages like the
  GB image does?
- What is still needed at boot that cannot be done at build time (device init, MIG, fabric
  manager, persistence)?
- What is the plan for kernel updates: rebuild the image every time, or use DKMS or a signed
  prebuilt module? Is Secure Boot / Trusted Launch module signing required?

### D. Build and Release Integration (key for our ownership)
- Can AgentBaker's VHD builder use an image we publish to a shared image gallery as its base?
  Or should our scripts run inside their Packer build?
- What is their release cadence (weekly?) and kernel/CVE patch SLA? Could our pipeline keep up?
- What are their compliance gates (Trivy, SBOM, image signing) and size limits?
- Who is on call when a GPU image fails in production?

### E. Validation
- Which GPU tests do they run today (e2e GPU scenarios), and on which SKUs?
- Could our SKU test matrix (nvidia-smi, DCGM diagnostics, NCCL, InfiniBand bandwidth) run as a
  release gate?

### F. Other 0→1 Work
- Prefetch is Azure Image Builder workload optimization (`vhdbuilder/prefetch`): it warms the
  image disk so first-boot reads are fast. Does it work for GPU images? Can a GPU image's
  prefetch profile be built on a non-GPU build VM?
- Container image pulls (device plugin, DCGM exporter): should they be cached, pinned, or run
  as systemd services?

### G. PIS and Ownership
- Is the GPU VHD the PIS base? Who owns the boundary between them?
- Is Ubuntu 26.04 gated on the GPU VHD? It could be an easier place for us to start owning
  things.

## 4. Collaboration Options (most impact first)

1. **We build and validate the GPU base image** (driver, toolkit, fabric manager, DCGM, DOCA)
   and publish it to a shared image gallery. AgentBaker adds the AKS layer on top.
2. **They consume our component scripts and BOM** in their VHD builder, and our validation runs
   as a release gate. Both teams share one set of version pins.
3. **Minimum:** shared version pins and SKU validation only.

Pilot suggestion: Ubuntu 24.04 x86, cuda-lts R580, H100 or A100. Measure 0→1 time against the
current prebake.

## 5. Information to Gather

**Before the meeting (our side)**
- Current consumers of the GB `azure_vm_akshost` target.
- Our build time and release cadence for Ubuntu 24.04.
- Validation SKU coverage.
- How fast we can ship a kernel patch.

**Ask AKS for**
- CSE timing telemetry (`AKS_GPU_PREBAKE` events, step durations).
- SKU usage distribution.
- VHD builder pipeline and gallery layout.
- Release SLA.
- e2e GPU test list.

## 6. Objections to Prepare For

- Their weekly cadence and security patch SLA versus our release cycle.
- Image size and keeping it lean. `install_aks.sh` is already minimal.
- Two pipelines meaning two owners during an incident.
- Kernel and driver lockstep when there are multiple driver lines.
