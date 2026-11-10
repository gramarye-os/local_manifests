#!/bin/bash
# Apply the AOHP patch series to a Kleaf kernel workspace after Lineage's build_kernel has synced it.
#
#   kernel-patches/apply.sh <kernel-source>            e.g. google/gs-6.1
#
# Expects ANDROID_BUILD_TOP (or cwd = Android tree). For <src> it looks in kernel-patches/<src>/:
#   *.patch        git format-patch files, applied in order to the aosp/ (kernel/common) checkout
#   user.bazelrc   copied to the workspace root (Kleaf reads it; here it selects the from-source
#                  GKI so the patched gki_defconfig is what boots)
# Idempotent: a patch whose subject is already in the aosp history is skipped, so re-running after
# a build without a sync is fine. A patch that fails to apply stops the build - fix it here, it is
# a five-minute job (the Lineage pin bumps ~3x/year, see README).
set -euo pipefail
SRC=${1:?kernel source, e.g. google/gs-6.1}
TOP=${ANDROID_BUILD_TOP:-$PWD}
HERE=$(cd "$(dirname "$0")" && pwd)
WS="$TOP/out-kernel/$SRC"
PD="$HERE/$SRC"
[ -d "$PD" ] || { echo "kernel-patches: nothing for $SRC"; exit 0; }
[ -d "$WS/aosp/.git" ] || { echo "kernel-patches: $WS/aosp is not a git checkout (build_kernel not synced?)"; exit 1; }
if [ -f "$PD/user.bazelrc" ]; then
  cp "$PD/user.bazelrc" "$WS/user.bazelrc"
  echo "kernel-patches: installed user.bazelrc"
fi
cd "$WS/aosp"
git config user.name  >/dev/null 2>&1 || git config user.name  "AOHP build"
git config user.email >/dev/null 2>&1 || git config user.email "build@aohp.invalid"
BASE=$(git rev-parse --short HEAD)
for p in "$PD"/*.patch; do
  [ -e "$p" ] || break
  subj=$(grep -m1 '^Subject:' "$p" | sed -E 's/^Subject: (\[PATCH[^]]*\] )?//')
  if git log --format=%s -n 50 | grep -qxF "$subj"; then
    echo "kernel-patches: already applied: $subj"; continue
  fi
  echo "kernel-patches: applying $(basename "$p")"
  git am --3way --keep-non-patch "$p" || { git am --abort; echo "kernel-patches: FAILED $(basename "$p") on $BASE"; exit 1; }
done
echo "kernel-patches: aosp now $(git describe --tags --always) ($BASE + $(git rev-list --count $BASE..HEAD) patches)"
