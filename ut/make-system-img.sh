#!/bin/bash
# Build ut/system.img (sparse ext4) = verified UBports rootfs + Halium 13 GSI + our device tarball + debug overlay.
# Same steps as build-tools/prepare-fake-ota.sh + system-image-from-ota.sh: tar --numeric-owner over a system/
# tree, mke2fs -d, img2simg. Runs as root in a docker volume (ownership preserved, case-sensitive FS).
# Never flashes anything.   SIZE=6000M ./ut/make-system-img.sh
set -e
cd "$(dirname "$0")/.."
SIZE="${SIZE:-6000M}"
ROOTFS=$(basename "$(ls ut/rootfs-*.tar.xz | head -1)")
for f in "ut/$ROOTFS" ut/halium_halium_arm64.tar.xz out/device_kebab.tar.xz; do [ -f "$f" ] || { echo "missing $f"; exit 1; }; done
docker volume rm -f kebab_ut_work >/dev/null
docker run --rm -v kebab_ut_work:/w -v "$PWD/ut":/ut -v "$PWD/out":/out:ro -e SIZE="$SIZE" -e ROOTFS="$ROOTFS" \
  kebab-halium-build bash -ec '
apt-get update -qq && apt-get install -y -qq --no-install-recommends e2fsprogs android-sdk-libsparse-utils xz-utils >/dev/null
cd /w
echo "== unpack rootfs";        xzcat /ut/$ROOTFS | tar --numeric-owner -xf -
echo "== unpack halium GSI";    xzcat /ut/halium_halium_arm64.tar.xz | tar --numeric-owner -xf -
echo "== unpack device tarball"; xzcat /out/device_kebab.tar.xz | tar --numeric-owner -xf -
echo "== debug overlay";        cp -a /ut/debug-overlay/system/. system/
A=system/var/lib/lxc/android
[ -e $A/system.img ] && mv $A/system.img $A/android-rootfs.img
ls -la $A/ | head -12; echo "partitions/:"; ls -la partitions
echo "== tree size: $(du -sm system | cut -f1) MiB, android-rootfs.img: $(du -m $A/android-rootfs.img | cut -f1) MiB"
echo "== mke2fs $SIZE"; mke2fs -t ext4 -O ^metadata_csum rootfs.img $SIZE -d system >/dev/null
echo "== img2simg"; img2simg rootfs.img system.img
cp -v system.img /ut/system.img; ls -la /ut/system.img'
