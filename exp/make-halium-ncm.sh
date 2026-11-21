#!/bin/bash
# Build exp/halium-ncm.img: our kernel + Halium initramfs patched so its debug network uses a USB NCM gadget
# SYSTEMPART=/dev/mapper/x OUTNAME=halium-debug.img ./exp/make-halium-ncm.sh  -> forces the initramfs debug shell
# (macOS has no RNDIS driver; this kernel has NCM built in). For fastboot boot only; never flash it.
set -e
cd "$(dirname "$0")/.."
docker run --rm -e SYSTEMPART="${SYSTEMPART:-/dev/mapper/system}" -e OUTNAME="${OUTNAME:-halium-ncm.img}" -v kebab_kernel_src:/src -v "$PWD/exp":/exp -v "$PWD/device":/dev1:ro kebab-halium-build bash -c '
set -e
D=/src/work/workdir/downloads
rm -rf /tmp/rd && mkdir /tmp/rd && cd /tmp/rd
gzip -dc $D/halium-boot-ramdisk.img | cpio -idm 2>/dev/null
python3 - <<PY
p="scripts/panic/telnet"; s=open(p).read(); o=s
s=s.replace("USB_FUNCTIONS=rndis","USB_FUNCTIONS=ncm")
a="    mkdir \$GADGET_DIR/g1/configs/c.1\n"
assert a in s
s=s.replace(a,"    if echo \$USB_FUNCTIONS | grep -q \"ncm\"; then mkdir \$GADGET_DIR/g1/functions/ncm.usb0; fi\n"+a,1)
b="    echo \$USB_FUNCTIONS | grep -q \"mass_storage\" && ln -s"
assert b in s
s=s.replace(b,"    if echo \$USB_FUNCTIONS | grep -q \"ncm\"; then ln -s \$GADGET_DIR/g1/functions/ncm.usb0 \$GADGET_DIR/g1/configs/c.1; fi\n"+b,1)
assert s!=o; open(p,"w").write(s); print("patched telnet handler")
PY
grep -n "ncm" scripts/panic/telnet
find . | cpio -o -H newc 2>/dev/null | gzip -9 > /exp/halium-ncm-ramdisk.img
K=$D/KERNEL_OBJ/arch/arm64/boot/Image
python3 $D/android_system_tools_mkbootimg/mkbootimg.py --kernel $K --ramdisk /exp/halium-ncm-ramdisk.img \
 --dtb /dev1/kebab-stock.dtb --dtb_offset 0x01f00000 --base 0x00000000 --kernel_offset 0x00008000 \
 --ramdisk_offset 0x01000000 --second_offset 0x00000000 --tags_offset 0x00000100 --pagesize 4096 --header_version 2 \
 --os_version 13.0.0 --os_patch_level 2024-01 \
 --cmdline "androidboot.hardware=qcom androidboot.memcg=1 androidboot.usbcontroller=a600000.dwc3 cgroup.memory=nokmem,nosocket loop.max_part=7 lpm_levels.sleep_disabled=1 msm_rtb.filter=0x237 reboot=panic_warm service_locator.enable=1 swiotlb=2048 systempart=$SYSTEMPART" \
 -o /exp/$OUTNAME'
ls -la exp/${OUTNAME:-halium-ncm.img}
