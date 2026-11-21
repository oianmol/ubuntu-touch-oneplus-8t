#!/bin/bash
# Build exp/ourkernel-peramdisk.img: our freshly built kernel + the stock Pixel Experience ramdisk + stock DTB.
# Used to tell a kernel problem from a Halium-ramdisk problem. For fastboot boot only; never flash it.
set -e
cd "$(dirname "$0")/.."
docker run --rm -v kebab_kernel_src:/src -v "$PWD/exp":/exp -v "$PWD/device":/dev1:ro kebab-halium-build bash -c '
set -e
K=/src/work/workdir/downloads/KERNEL_OBJ/arch/arm64/boot/Image
M=/src/work/workdir/downloads/android_system_tools_mkbootimg/mkbootimg.py
python3 $M --kernel $K --ramdisk /exp/pe-ramdisk.bin --dtb /dev1/kebab-stock.dtb --dtb_offset 0x01f00000 \
 --base 0x00000000 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --second_offset 0x00000000 --tags_offset 0x00000100 \
 --pagesize 4096 --header_version 2 --os_version 13.0.0 --os_patch_level 2024-01 \
 --cmdline "androidboot.console=ttyMSM0 androidboot.hardware=qcom androidboot.memcg=1 androidboot.usbcontroller=a600000.dwc3 cgroup.memory=nokmem,nosocket loop.max_part=7 lpm_levels.sleep_disabled=1 msm_rtb.filter=0x237 reboot=panic_warm service_locator.enable=1 swiotlb=2048 buildvariant=userdebug security=selinux" \
 -o /exp/ourkernel-peramdisk.img'
ls -la exp/ourkernel-peramdisk.img
