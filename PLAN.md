# Ubuntu Touch port — OnePlus 8T (KB2001, `kebab`)

Purpose: a rollback-safe testbed for the Halium flow, and a usable Ubuntu Touch phone if it works out.
The Fold 5 port (`../q5q-port/`) is blocked on bootloader unlock; this device is not.

## Device facts
Read from the phone / verified upstream, 2026-11-20. "(verify)" = not yet confirmed on this phone.
- OnePlus 8T KB2001, SM8250 (Snapdragon 865), 12 GB, 256 GB UFS
- Bootloader UNLOCKED (`fastboot getvar unlocked` = yes). Fastboot works. Entry: Vol Up + Power
  (LineageOS wiki lists Vol Up + Vol Down + Power for the same menu)
- Original firmware: OxygenOS 13, build `TQ3A.230901.001.B1`, Android 13 vendor. A/B, dynamic `super`
- Kernel: LineageOS `android_kernel_oneplus_sm8250`, downstream 4.19, NOT GKI. lineage-24.0 is 4.19.325;
  lineage-20 (Android 13 era, used for this port) is 4.19.306, last commit 2024-02-10, cloned shallow into the
  Docker volume `kebab_kernel_src` (76958 files). Defconfig: `vendor/kona-perf_defconfig` (no oplus.config
  on lineage-20). 8T device trees: `arch/arm64/boot/dts/vendor/19805` (19811=8 Pro, 19821/19855=8).
  Stock OOS 13 kernel is also 4.19 (verify)
- Boot header v2, separate dtbo, page size 4096, kernel base 0x0. boot 96 MiB, dtbo 24 MiB,
  recovery 96 MiB (own partition). Dynamic partitions: odm product system system_ext vendor
  (from LineageOS `android_device_oneplus_sm8250-common`)
- Mainline Linux (postmarketOS 7.2.0) already ran here: display, touch, Wi-Fi, BT, NFC, battery OK;
  no modem remoteproc, no camera pipeline, no IMU/proximity sensors. That is a hardware floor, not
  the Halium result: Halium drives the Android vendor stack instead.

## Current state of the phone (2026-11-21)
- LineageOS 24.0 (nightly 2026-11-20) is installed and running from slot b. Bootloader unlocked.
  Rooted debugging (adb root) is on in Developer options.
- Slot a: boot_a holds a leftover pmOS boot.img, dtbo_a/vbmeta_a hold LineageOS images. Not used.
- Full partition backup (81 partitions, hash-verified, 1.9 GB) is in `kebab-backup/` (gitignored: it
  holds persist and modem data). Excludes super, userdata and log/dump partitions.
- Pixel Experience Plus 13 is refused by the LOS 24 recovery (SPL downgrade).

## Boot test log (all `fastboot boot`, nothing written to flash)
- 2026-11-21: the Halium boot.img from the first build never became visible. Two diagnoses came later.
- Hybrid test (our kernel + stock PE ramdisk) fell back to fastboot after ~7 s. Cause: kona-perf_defconfig
  makes AppArmor the default LSM and the Android init needs SELinux. With `security=selinux` added to the
  cmdline it behaves exactly like the stock kernel (USB `KB2001` appears at ~21 s vs 22 s stock). So the
  kernel itself is good.
- Halium ramdisk: no USB network appeared because (a) the kernel has no RNDIS/ECM/ACM configfs functions
  (only NCM) and (b) macOS has no RNDIS driver anyway. Fixed for testing by patching the initramfs panic
  handler to use an NCM gadget (`exp/make-halium-ncm.sh`). Result: USB device "Failed to boot" (Halium
  initrd, 18d1:d001) at ~9 s, interface en13 at ~11 s, ping 192.168.2.15 OK at ~17 s, telnet shell works.
- From the shell (log in `exp/halium-dmesg.txt`): kernel 4.19.306 up 24 s+ with no panic, UFS, SDE/DSI
  display bound, touch and OPLUS charger drivers probe, dynamic partitions map (`system_b` found); the
  initramfs then fails to find an Ubuntu Touch rootfs, as expected.
- Findings fixed in `halium.config`: `SECURITY_APPARMOR_BOOTPARAM_VALUE=1` (defconfig had 0, so AppArmor
  was off), USB_CONFIGFS_RNDIS/ECM/ACM. Findings not yet addressed: no `/dev/fb0` (FB=n, no fbdev
  emulation), so the initramfs cannot draw on screen; `kasan_multi_shot` and other odd params arrive via
  the bootloader cmdline.
- Other build lessons: needs `CONFIG_CC_WERROR` off, `LLVM_IAS=1`, `BRAND_SHOW_FLAG=oneplus`, no
  `deviceinfo_kernel_arch`, `deviceinfo_kernel_image_name="Image"`, recovery image disabled, overlay dir.

## Approach: Halium 13, vendor from stock OOS 13 (verify), downstream 4.19 kernel
No official UBports sm8250 port found (searches 2026-11-20 found none for kebab, instantnoodle, or sm8250).
Nearest templates, none identical:
- UBports OnePlus 11 `oneplus-salami` (Halium 13, SM8550): the only Android 13 template. Kernel
  is GKI 5.15 there, so only the device packaging transfers, not the kernel patches.
- UBports OnePlus 5/6/6T/Nord (older Halium, SDM845/MSM8998/SM7250): A/B and fastboot flow reference.
- postmarketOS `oneplus-kebab` for the working mainline DT, firmware list and fastboot flash layout.
- Third-party `scotthowson/build_kernel_instantnoodle` (Halium 10 kernel build for the OnePlus 8) as a
  config reference only. Not an official port.

Vendor source for Halium 13 (decided 2026-11-20): the Android 13 vendor from the Pixel Experience Plus
13 OTA (`~/oneplus/downloads/pe-rom/...20240127...zip`), extracted with payload-dumper-go to
`~/oneplus/work/pe-payload/out/` (vendor.img EROFS 540 MB, odm.img, boot.img, dtbo.img, vbmeta.img).
- `ro.vendor.build.version.release=13`, `ro.vendor.build.id=TQ3A.230901.001.B1`: same build id as the
  phone's original OxygenOS 13 firmware. Product model string KB2005 (global), phone is KB2001.
- Vendor fingerprint `OnePlus/OnePlus8T/OnePlus8T:13/RKQ1.211119.001/R.13ebe2e_1-170dfb`, built
  2024-01-26 (`date.utc=1706317719`), so blobs are 2024-01 vintage, not the phone's original Sept 2023.
- The OTA has no firmware partitions (no modem/xbl/abl), only software ones, so it cannot touch firmware.
- Not verified yet: the vendor's kernel-module/HAL expectations against the LineageOS 4.19 kernel;
  whether KB2005 blobs run on KB2001 (same SoC and board, different RF/region bands).
LineageOS 20 is gone from the official mirror (only 23.2 and 24.0 builds remain). LineageOS 24
vendor (Android 16) is NOT usable with Halium 13.

## Phases
0. (no phone changes) Vendor image extracted (see above). Read the PE boot.img for cmdline, offsets and
   os_patch_level. Set up Docker build env on a Linux volume (case-sensitive FS needed for the kernel).
   Write `deviceinfo`, `halium.config`. Check Ubuntu 24.04 systemd (v255) runs on a 4.19 kernel.
1. Kernel: LineageOS `android_kernel_oneplus_sm8250` (use the branch matching the vendor Android
   version) + `halium.config` (devtmpfs, namespaces, AppArmor, SYSVIPC, FHANDLE, AUTOFS, etc.).
   Build with clang. Test boot with `fastboot boot` (nothing written to flash).
2. Boot image: halium boot.img (dynparts initramfs), dtbo and vbmeta (verification disabled) to the
   inactive slot. Flash the Halium system/rootfs to a logical partition via fastbootd or recovery.
   Debug over USB (telnet on the initramfs).
3. Bring-up in this order: display + backlight, touch, USB networking, Wi-Fi, audio, battery,
   Bluetooth, GPS, sensors, camera, modem/telephony (last: the usual hard part, 8T has Qualcomm
   modem plus OnePlus RIL).
4. UBports recovery, OTA channel, installer config.

## Phase 2 plan: Ubuntu Touch rootfs into a free A/B slot (not started; first partition-modifying step)
The initramfs mounts `/dev/mapper/system_<slot>` as the rootfs, so UT needs its own logical `system`
partition. LineageOS lives in slot b, so use slot a and keep b bootable.
1. Get the UT rootfs image for 24.04 arm64 (`24.04-2.x` channel in deviceinfo) plus
   `build-tools/system-image-from-ota.sh`; build `system.img` sized `deviceinfo_system_partition_size`
   (6000M) and the device tarball already produced (`out/device_kebab.tar.xz`).
2. Check `super` free space (7.5 GB total, LineageOS uses most of it). Slot a's `system_a`, `vendor_a`,
   `product_a`, `odm_a`, `system_ext_a` logical partitions exist but may be small or empty. Likely need a
   fresh `super_empty.img` layout (LineageOS ships one) and to re-flash both slots' content, i.e. LineageOS
   in b would be rewritten too. Decide before touching anything: either repartition `super` and reinstall
   LineageOS afterwards from `kebab-lineage/dl`, or free space by shrinking LOS partitions.
3. Flash via fastbootd (`fastboot reboot fastboot`): create/resize logical partitions, flash system.img,
   flash the Android 13 vendor from `~/oneplus/work/pe-payload/out/vendor.img` (+ odm) into the matching
   slot, then flash boot.img/dtbo to the same slot, `fastboot set_active a`. Confirm the first boot with
   `fastboot boot` before writing boot_a.
4. If it fails: boot LineageOS by `fastboot set_active b`; worst case reinstall from the verified zip
   and restore partitions from `kebab-backup/`.

## Rollback
Fastboot is always reachable and the bootloader is unlocked, so a bad flash is recoverable by
flashing a LineageOS 24 install (verified hashes in `../kebab-lineage/dl`) from recovery.
Stock OOS restore is the open item: no official image source found (OnePlus pages and XDA both
block automated fetches). Get a KB2001 full OTA zip before any phase that rewrites firmware partitions.

## Risks
- No Halium 13 reference for SM8250 and a 4.19 non-GKI kernel (kernel patch set is new work)
- Halium 13 maturity (UBports docs list it; status unconfirmed)
- Cameras, modem and sensors depend on vendor HALs behaving under Halium
- Slot b history is unknown. Never flash to the slot you are not sure about
- Only flash the inactive slot while testing; keep the active slot bootable to LineageOS

## Not doing
- Touching any firmware partition (xbl, abl, modem, tz, ...) other than via a verified full OTA
- Relocking the bootloader
