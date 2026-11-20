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

## Current state of the phone (as of this plan)
- Slot a: overwritten by earlier experiments (pmOS boot.img + empty dtbo, later LineageOS dtbo/vbmeta/recovery)
- Slot b: unknown content, was hanging at the OnePlus logo. May hold earlier iOS-port payloads
  (see `~/oneplus/work/payload/*.img`, `~/oneplus/mu-silicium/Mu-kebab.img`)
- `copy-partitions` run once, so slot b firmware should now match slot a
- LineageOS 24.0 install was in progress: recovery flashed, data formatted, zip to sideload
- Pixel Experience Plus 13 (`~/oneplus/downloads/pe-rom`) is refused by the LOS 24 recovery
  (SPL downgrade). It would only install from a recovery with an older SPL.

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
