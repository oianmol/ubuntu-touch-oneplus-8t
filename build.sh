#!/bin/bash
# Build the kebab halium kernel + boot image. Phase 0 ONLY builds images; it does NOT touch the phone.
#
# macOS is case-insensitive -> the Linux kernel tree MUST live in a Docker volume, never a bind mount.
# Runs UBports halium-generic-adaptation-build-tools in the halium build container, with ./device/
# (deviceinfo + halium.config + stock dtb/dtbo) as the port config.
#
#   ./build.sh prefetch    clone the kernel (shallow) into the volume and sanity check it
#   ./build.sh [args]      full build (args go to build-tools build.sh, e.g. -k = kernel only);
#                          images land in ./out
#
# Layout inside the kebab_kernel_src volume:
#   /src/build-tools                                   halium-generic-adaptation-build-tools
#   /src/work/{deviceinfo,halium.config,...}           HERE for build.sh (it sources ./deviceinfo)
#   /src/work/workdir/downloads/android_kernel_oneplus_sm8250  build-tools reuses a kernel clone found here
set -xe
cd "$(dirname "$0")"
mkdir -p out

KDIR=android_kernel_oneplus_sm8250

if [ "$1" = prefetch ]; then
  docker run --rm -v kebab_kernel_src:/src --entrypoint sh alpine/git -c '
    set -e
    mkdir -p /src/work/workdir/downloads
    cd /src/work/workdir/downloads
    [ -d '"$KDIR"' ] || git clone --depth 1 -b lineage-20 \
      https://github.com/LineageOS/android_kernel_oneplus_sm8250.git '"$KDIR"'
    cd '"$KDIR"'
    git log --oneline -1
    head -4 Makefile
    ls arch/arm64/configs/vendor | grep -E "^kona-perf_defconfig$"
  '
  exit 0
fi

# No --platform flag: the image is already amd64, and with the flag docker fails the local lookup.
docker run --rm \
  -v kebab_kernel_src:/src \
  -v "$PWD/device":/port:ro \
  -v "$PWD/out":/out \
  kebab-halium-build \
  bash -c '
    set -xe
    cd /src
    [ -d build-tools ] || git clone \
      https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools build-tools
    mkdir -p work
    cp /port/deviceinfo /port/halium.config /port/kebab-stock.dtb /port/dtbo.img work/
    cd work
    # The kernel merges "halium.config" as a %.config target, which only searches arch/arm64/configs/.
    K=/src/work/workdir/downloads/android_kernel_oneplus_sm8250
    [ ! -d $K ] || cp halium.config $K/arch/arm64/configs/halium.config
    # Kernel Makefile adds -no-integrated-as unless LLVM_IAS=1, which sends clang asm output to the GCC 4.9
    # binutils (rejects newer clang output: "junk at end of line"). Use the integrated assembler instead.
    # (No apostrophes in comments here: this whole block is one single-quoted bash -c string.)
    export LLVM_IAS=1
    ../build-tools/build.sh "$@"
    cp -v out/*.img /out/ 2>/dev/null || true
  ' _ "$@"

echo "Images in ./out/ (if any) — nothing has been flashed."
