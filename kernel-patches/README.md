# AOHP kernel patches for Kleaf (Pixel) kernels

The Pixel kernels are built by Lineage's `build_kernel` (Kleaf/Bazel) from a kernel manifest that
pins Google's `kernel/common` at an LTS tag and, by default, takes the **signed prebuilt GKI
Image**. Core options such as `CONFIG_PID_NS` therefore cannot be changed through device
fragments, and the overlayfs fix our casefolded f2fs userdata needs has to go into the GKI source.

Rather than fork the 8 GB `kernel/common` (Lineage bumps the pin ~3x a year; the fork would sit
on a stale tag), we carry a small patch series here and apply it after the kernel sync:

    scripts/lineage-build.sh:   breakfast $DEVICE          # build_kernel syncs out-kernel/<src>
                                kernel-patches/apply.sh google/gs-6.1
                                m bacon                    # build_kernel runs again, SKIP_KERNEL_SYNC=1

Per kernel source directory (`<src>` = `TARGET_KERNEL_PLATFORM_SOURCE`, e.g. `google/gs-6.1`):

- `NNNN-*.patch` - `git format-patch` output, applied with `git am --3way` to `aosp/`
  (kernel/common). Idempotent by subject.
- `user.bazelrc` - copied to the Kleaf workspace root; selects the from-source GKI
  (`--kernel_package=@//aosp --use_prebuilt_gki=false ...`).

## google/gs-6.1 (Pixel 6 oriole; also the gs101/gs201 family)

1. `overlayfs: accept non-casefolded dentries on a casefold-capable fs` - Android formats
   userdata with the f2fs casefold feature; 6.1 overlayfs refused every /data dentry, so podman fell
   back to fuse-overlayfs. Mainline grew real support in 6.13; this is the minimal 6.1 version.
2. `gki_defconfig: AOHP container options` - PID/USER/IPC namespaces, SYSVIPC, POSIX_MQUEUE,
   cgroup pids/device, CFS bandwidth, bridge netfilter, nftables, macvlan/ipvlan. Same list as
   the OnePlus (`vendor/oplus/aohp.config`) and Saga (`vendor/aohp.config`) kernels.
   **Must stay in `savedefconfig` order** - Kleaf's check_defconfig rejects the build otherwise;
   when a pin bump moves lines, take the diff Kleaf prints and regenerate the patch.

Verified on oriole cred38 (android14-6.1-2025-08_r12 + these two), 2026-11-09.

## Refreshing after a Lineage pin bump

`apply.sh` fails loudly if a patch no longer applies. Regenerate from a scratch checkout of the new
tag: apply what still applies, fix by hand, `git format-patch -<n>`, replace the files here. The
Image is unsigned GKI either way, so no KMI/ABI step is involved on our side.
