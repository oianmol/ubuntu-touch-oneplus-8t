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

## Bring-up findings (2026-11-21, continued)
- Flash boots of slot a were NOT silent crashes: the persistent journal (userdata `system-data/var/log/journal`,
  readable from the initramfs debug shell via chroot journalctl) shows Ubuntu Touch running for minutes until the
  power key was pressed. USB and display were the problems.
- Vendor image must be ext4: the OxygenOS/PE vendor is EROFS with an incompat feature the 4.19 driver rejects
  ("unidentified incompatible feature 2"). Converted vendor (1000 MiB) and odm (450 MiB) to ext4, system_a 4600 MiB.
- Android's vendor `init.qcom.usb.rc` binds USB gadget g1 (also in charger mode) so usb-moded fails with EBUSY.
  Fixed with an empty override via /usr/share/halium-overlay (device/overlay). usb-moded then gives
  `ssh -p 8022 phablet@10.15.19.82` (empty password, `sudo` works with empty password) ~27 s after boot,
  with `RNDIS_FUNCTION=ncm.usb0` so a Mac gets an interface.
- Display: lightdm exits right after starting the compositor with `waitid(pid:N, pidfd=M) failed: EINVAL`:
  GLib 2.80 uses waitid(P_PIDFD) which 4.19 lacks. Patch `device/patches/0001-wait-introduce-waitid-P_PIDFD.patch`
  (backport of the 5.4 feature). Not yet verified on the phone.
- Mir log also shows `eglSubDriverAndroid.so` / `libadreno_app_profiles.so` not found (files exist in
  /android/vendor/lib64/egl): probably a libhybris search path issue, to check if the screen stays blank.
- Tips: never press the power key while testing (logind powers off). A/B retry counters: re-run `fastboot set_active a`.

## STATUS 2026-11-21: Ubuntu Touch boots to the Lomiri session on the 8T
Slot a: Ubuntu Touch 24.04.5 (24.04-2.x daily rootfs + Halium 13 GSI), our 4.19.306 kernel, PE Android 13 vendor/odm converted to ext4.
Mir renders on the Adreno 650 (GL ES 3.2), boot spinner on screen, Lomiri user services running.
Fixes that got here (all in git): halium.config (apparmor bootparam, USB gadget functions), waitid(P_PIDFD) kernel
backport, overlay: empty init.qcom.usb.rc (stops Android binding the gadget), vndservicemanager.rc with
LD_PRELOAD libselinux_stubs.so, ext4 vendor/odm, usb-moded NCM pin. Normal power-on (power key, no cable) is
needed for normal mode: a cable at power-on makes the bootloader pass androidboot.mode=charger and UT boots
charger.target (battery logo, no display manager). `sudo reboot bootloader` from UT reaches fastboot without keys.

### What the similar UBports ports showed (checked 2026-11-21, gitlab.com/ubports/porting/community-ports)
- google-sargo (Pixel 3a, kernel 4.9, Halium 12): overlay `android/vendor/etc/init/vndservicemanager.rc` with
  `setenv LD_PRELOAD libselinux_stubs.so` (our fix is the same; the GSI ships libselinux_stubs.so). It also
  overlays vendor rc files for keymaster, fingerprint, sensors, gnss, media omx, and uses `.halium-overlay-dir` markers.
- sony-pdx225 (Xperia 10 IV, 5.4): bind-mounts its own vndservicemanager binary instead.
- nothing-spacewar (4.x/5.4, Halium 11) and xiaomi-vayu (4.14): cmdlines include `console=tty0`; usb-tethering and
  umtprd-functionfs overlays; none of the checked kernels (4.9, 4.14, Pixel 5 4.19.269) carries waitid(P_PIDFD),
  because they also lack pidfd_open so GLib falls back. Ours had pidfd_open without it, hence the backport.
- Reference clones live in `kebab-port/ref-ports/` (gitignored).
Next to do: touch/keyboard check, Wi-Fi, audio, Bluetooth, sensors, camera, modem (ofono/ril), apparmor.service,
fingerprint, proper boot.img with AVB footer, UBports recovery, remove the empty-password debug access.

### Lomiri shell crash root cause (2026-11-21): GPU nodes were root-only
`lomiri --mode=full-greeter` died with SIGSEGV ~1 s after start. gdb on a core (gdb installed on the phone from
Ubuntu arm64 debs; core dumps via DefaultLimitCORE + kernel.core_pattern=/tmp/core.%e.%p): strstr() on a garbage
pointer inside /android/system/lib64/libEGL.so, i.e. the Adreno EGL driver returned a bad extension string.
Cause: /dev/kgsl-3d0 and /dev/ion were crw------- root:root (on Android ueventd sets them; on UT the host udev creates
nodes and the rootfs ships an EMPTY stub /usr/lib/udev/rules.d/70-android.rules "replaced by device-specific rules").
The root-owned system compositor worked, the phablet shell and lightdm greeter crashed. Fix: overlay
`usr/lib/udev/rules.d/70-android.rules` (device/overlay/.../halium-overlay/) opening kgsl/ion/hgsl/drm to 0666.
Same approach in every UBports Qualcomm port (xiaomi-vayu 70-vayu.rules, sony-pdx225, samsung-q2q).
Not the cause (checked): TLS padding (GLIBC_TUNABLES is set for the user manager; LD_PRELOAD=libtls-padding was not,
adding it changed nothing), Android properties, fscrypt (the "not encrypted" message is only a status print;
the session script then picks the unencrypted target).
Still open: policykit-agent aborted via std::terminate before this fix (recheck), apparmor.service,
audiosystem-passthrough-qti.service, Wi-Fi/audio/camera/modem rules (the vayu rules file has the full Qualcomm list).

### Touch and display cutout (2026-11-21)
- Touch was dead because libinput rejected the touchscreen: "event1 - touchpanel: kernel bug: device has min == max
  on ABS_MT_WIDTH_MAJOR" (the OPLUS/Qualcomm driver reports ABS_MT_WIDTH_MAJOR and ABS_MT_PRESSURE with 0..0 range),
  so Mir never added /dev/input/event1. Fix: `etc/libinput/local-overrides.quirks` with `MatchName=touchpanel` and
  `AttrEventCode=-ABS_MT_WIDTH_MAJOR;-ABS_MT_PRESSURE;`. Gotchas: `MatchUdevType=touchscreen` is NOT a valid value
  and makes libinput drop the whole quirk file ("Failed to load the device quirks"). Verified: touch works.
- Display: panel 1080x2400 @ ~402 ppi, GRID_UNIT_PX 21 (same as spacewar/vayu). The punch-hole camera covered the status
  bar. Added `etc/deviceinfo/devices/kebab.yaml` (Names, GridUnit 21, CollapsedPanelHeight 123, DisplayCutoutsCollapsed
  "0 0 164 123" and "1055 0 25 123") with numbers from LineageOS android_device_oneplus_kebab overlay
  (cutout circle 68 px, centre 99 px from left / 68.5 px from top, status bar 123 px). To tune, edit that file.
- Tools used: python3-evdev (installed on UT) to read /dev/input/event*, dmesg [TP] lines, journal of the lomiri service.

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
