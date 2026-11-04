# LineageOS 23.2 + AOHP (Pixel 6 "oriole", OnePlus 13 "dodge")

> **Full documentation (build, install from the ROM releases, provisioning, known issues) lives in
> https://github.com/gramarye-os/aohp-lineage** — this file only covers the manifest.

Branch `lineage-23.2-aohp` of this repo holds the local manifest that reproduces the tree built on chex
(`/home/chris/lineage/android`, 2026-10-03/04; reports in `/home/chris/lineage/logs/REPORT-*.md`).
The AOHP-patched projects are the `lineage-23.2-aohp` branches of the injinj forks:
`android_build`, `platform_system_core` (branch on the existing aohp-os fork, see comment in aohp.xml), `android_system_sepolicy`,
`android_frameworks_base`, `android_packages_apps_Launcher3` (since 2026-10-06: one null-check commit on top of lineage-23.2),
`android_device_google_raviole`, `android_device_oneplus_dodge`, `android_device_osom_ingot`,
`android_device_oneplus_sm8750-common` + `android_kernel_oneplus_sm8750` (since 2026-10-22: the `vendor/oplus/aohp.config`
kernel fragment enabling SysV IPC and POSIX mqueue for the AOHP env, in use since dodge build-21 on 2026-10-09) and
`android_vendor_aohp` (private). Each is LineageOS `lineage-23.2` + the aohp-os upstream squash + the injinj
commits (sepolicy: `aohp_container_socket` moved to private policy for `sepolicy_freeze_test`; patch 0003
"drop policycap functionfs_seclabel" intentionally NOT applied - Lineage/Pixel keep the policycap).

## Reproduce

```bash
mkdir -p ~/lineage/android && cd ~/lineage/android
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --no-clone-bundle --partial-clone --clone-filter=blob:limit=10M
mkdir -p .repo/local_manifests
curl -fsSL https://raw.githubusercontent.com/injinj/local_manifests/lineage-23.2-aohp/aohp.xml -o .repo/local_manifests/aohp.xml
repo sync -c -j8 --no-tags --no-clone-bundle --optimized-fetch --prune --retry-fetches=3
```

`vendor/aohp` is a private repo: `repo sync` needs a GitHub credential with access to injinj
(e.g. `gh auth login` + `gh auth setup-git`, or a `~/.git-credentials` entry).

### AOHP binaries that are not in any repo project — `vendor/aohp/fetch-prebuilts.sh`

After `repo sync` run `vendor/aohp/fetch-prebuilts.sh` (no arguments). It downloads, sha256-verifies and places every
file the build needs that is not in git: `packages/apps/AOHPAgentDriver/rootfs/debian.tar.gz` (the `templates-*`
release of injinj/aohp-agents pinned as `TEMPLATES_TAG` in the script — `templates-20261005b` since 2026-10-05; `--release <tag>`
or `TEMPLATES_TAG=` for the newest), `packages/apps/AOHPDriver/{Android.bp,AOHPDriver.apk,initial-package-stopped-states-aohp.xml}`
(injinj/aohp-driver release, unsigned — Soong platform-signs it), `packages/apps/OpenClawAndroid/{Android.bp,OpenClawAndroid.apk}`
(injinj/openclaw release `android-aohp-*`, presigned with the injinj `aohp-apps` key, `preprocessed: true`) and the
stock `AOHPAgentDriver.apk` + `rootfs/alpine.tar.gz` (injinj/AOHPAgentDriver `prebuilts-*` release; not installed on
the phones but required by Soong analysis). Lineage's default dev platform key is byte-identical to the AOHP tree's, so
AOHPDriver keeps its platform signature without any key override. Details: `vendor/aohp/README.md` and
https://github.com/gramarye-os/aohp-lineage/blob/main/docs/build.md.

## Build (exact commands from logs/build-3.sh and logs/build-dodge-1.sh)

```bash
cd ~/lineage/android
# builds <= oriole build-5 / dodge build-3 used 'export WITH_ADB_INSECURE=true' (ro.adb.secure=0, ro.debuggable=1).
# Since build-6 / dodge-4 the build is a plain userdebug (ro.adb.secure=1) and the build host's adb public key is
# baked in via PRODUCT_ADB_KEYS := vendor/aohp/adb_keys (system + recovery ramdisk): put YOUR ~/.android/adbkey.pub
# in that file (one key per line) before building, or you get the RSA dialog / no adb in recovery.
source build/envsetup.sh
breakfast oriole                   # Pixel 6: = lunch lineage_oriole-bp4a-userdebug + build_kernel (repo-inits/syncs android_kernel_google_gs-6.1_manifest into out-kernel/, Kleaf build, ~10 min)
m -j10 bacon                       # -> out/target/product/oriole/lineage-23.2-*-UNOFFICIAL-oriole.zip, boot.img, dtbo.img, vendor_boot.img
# OnePlus 13 (kernel built in-tree from kernel/oneplus/sm8750, INLINE_KERNEL_BUILDING):
breakfast dodge                    # lineage_dodge-bp4a-userdebug
m -j10 bacon                       # -> out/target/product/dodge/lineage-23.2-*-UNOFFICIAL-dodge.zip, boot/dtbo/init_boot/vbmeta/vendor_boot/recovery.img
```

`brunch oriole` / `brunch dodge` is the one-step equivalent of breakfast + `m bacon`. Flashing: fastboot the
boot images, Lineage recovery → Factory reset → Apply update from ADB → `adb sideload <zip>` — step by step in
https://github.com/gramarye-os/aohp-lineage/blob/main/docs/install-oriole.md and `docs/install-dodge.md`; the built ROMs are
published as releases there. Build time on chex (32 threads, -j10, CPUQuota 1000 %): oriole ~2.5 h cold, dodge 1 h 53 min.

Updating an already-flashed phone to a newer build: no fastboot step is needed when the boot images did not change —
reboot to recovery, *Apply update → Apply from ADB*, `adb sideload <new zip>`, reboot; /data (envs, Driver settings,
Keystore secrets) is kept. The 2026-10-05 builds (oriole build-4, dodge build-2) were produced exactly this way as
incremental `m -j10 bacon` runs after changing system/sepolicy, the Driver APK and the Debian template
(logs/build-4.sh, logs/build-dodge-2.sh).
