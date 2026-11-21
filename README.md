# Ubuntu Touch on the OnePlus 8T (`kebab`) — unofficial Halium 13 port

Work-in-progress port of [Ubuntu Touch](https://ubuntu-touch.io/) (24.04-2.x) to the **OnePlus 8T, KB2001**
(Snapdragon 865, SM8250). It boots to the Lomiri session with GPU rendering, touch, a correct display cutout and
Wi-Fi. Audio, Bluetooth, sensors, camera and the modem are not done yet (table below).

This is **not** an official UBports port and is not affiliated with UBports. There was no existing SM8250 port to
start from, so this repo records what it took, including the dead ends, so the next person can skip them.
`PLAN.md` is the raw engineering log; this file is the guide.

> **Warning.** Everything here needs an **unlocked bootloader (which wipes the phone)** and rewrites partitions in
> `super`. Back up first (a full partition backup, not just your data). You can brick the phone. Use at your own risk.
>
> The `ut/debug-overlay` used while bringing the port up turns **off adb key verification** (`ADBD_SECURE=0`) and the
> rescue network allows **SSH with an empty password over USB**. That is for bring-up only. Remove it before using the
> phone for anything real.

## Status

Tested on one KB2001 (Indian variant), 2026-11-21. "Verified" means checked on the phone, not assumed.

| Area | State |
|---|---|
| Boot to Lomiri session | Verified. Slot a: UT 24.04 rootfs + Halium 13 GSI, our 4.19.306 kernel, Android 13 vendor |
| GPU (Adreno 650, GLES 3.2, Mir) | Verified (needed udev rules, see Lessons) |
| Display, punch-hole cutout, grid unit | Verified |
| Touch | Verified (needed a libinput quirk) |
| USB rescue network (NCM) | Verified |
| Wi-Fi (QCA6390 via CNSS + qcacld) | Verified, connects and has internet; interface name pinned to `wlan0` so saved networks survive reboots |
| Audio output (speaker) | Works at the HAL level: `paplay` is audible. **Notification sounds and ringtone previews fail**: `media-hub-server` aborts, see Lessons. Kernel patch `0002` fixes it: with it, booted from RAM, Settings sound previews play (confirmed by ear; not yet flashed to `boot_a`, log-level checks pending) |
| Bluetooth, sensors, camera, modem/calls/SMS, fingerprint, haptics, flashlight | Not tested |
| `apparmor.service` | Fixed with a drop-in (see Lessons): the service now runs its reload and succeeds. Loaded-profile count not yet checked with `aa-status` |
| Proper `boot.img` with AVB footer, UBports recovery, OTA channel | Not done. Currently flashed with a debug boot image |

## How it works

- **Halium 13**, because the vendor partition comes from an Android 13 build (Pixel Experience Plus 13 for
  `kebab`, build `TQ3A.230901.001.B1`, the same build id as the phone's own OxygenOS 13).
- **Kernel:** LineageOS `android_kernel_oneplus_sm8250`, branch `lineage-20` (downstream Qualcomm 4.19.306, not GKI),
  defconfig `vendor/kona-perf_defconfig vendor/debugfs.config` plus `device/halium.config`. Built with clang in Docker.
- **Rootfs:** UBports daily 24.04-2.x rootfs + the Halium 13 arm64 GSI as the Android container, assembled by
  `ut/make-system-img.sh`, with the device tarball (`device/overlay`) merged in.
- Dynamic partitions + A/B: Ubuntu Touch goes in slot a (`system_a`, `vendor_a`, `odm_a`).

## Repository layout

| Path | What |
|---|---|
| `device/deviceinfo` | Halium `deviceinfo` (boot image geometry, cmdline, kernel source and defconfigs) |
| `device/halium.config` | Kernel config fragment: namespaces, cgroups, binderfs, AppArmor, SysV IPC, USB gadget functions |
| `device/patches/` | Kernel patches applied by `build.sh` |
| `device/overlay/system/` | Files merged into the rootfs: udev rules, libinput quirk, `device-hacks` (Wi-Fi), deviceinfo YAML, halium-overlay Android rc overrides, systemd drop-ins |
| `build.sh`, `Dockerfile` | Docker build of the kernel and device tarball (`./build.sh prefetch`, then `./build.sh`) |
| `ut/make-system-img.sh`, `ut/debug-overlay/` | Builds the sparse ext4 rootfs image; debug overlay (**insecure**, see warning) |
| `exp/make-halium-ncm.sh` | Boot image with a Halium initramfs patched to use a USB NCM gadget (macOS has no RNDIS driver) |
| `exp/make-hybrid.sh`, `exp/pe-config.txt` | Test boot with the stock ramdisk; the stock kernel config for diffing |

## Building

Needs Docker. On macOS the kernel tree must live in a **Docker volume**, not a bind mount (case-insensitive
filesystem). You also need to provide, in `ut/`: the UBports rootfs tarball for `24.04-2.x` and the Halium 13 arm64 GSI
(`halium_halium_arm64.tar.xz`), and the Android 13 vendor/odm images (not included, they are Google/OnePlus blobs).

```
./build.sh prefetch          # clone the kernel into the kebab_kernel_src volume
./build.sh                   # kernel + boot image + device_kebab.tar.xz into ./out
./exp/make-halium-ncm.sh     # debug boot image with NCM USB networking -> exp/halium-ncm.img
SIZE=4600M ./ut/make-system-img.sh   # rootfs -> ut/system.img
```

**Vendor and odm must be ext4.** The OxygenOS / Pixel Experience vendor is EROFS with an incompat feature the 4.19
driver rejects (`unidentified incompatible feature 2`). Extract it and repack, for example:

```
fsck.erofs --extract=/x/vendor vendor.img      # erofs-utils
mke2fs -t ext4 -O ^metadata_csum -L vendor -d /x/vendor vendor-ext4.img 1000M
mke2fs -t ext4 -O ^metadata_csum -L odm    -d /x/odm    odm-ext4.img    450M
```

## Flashing (the sequence that worked)

Test first with `fastboot boot exp/halium-ncm.img`, which writes nothing. Only then write flash. This **destroys
the data and whatever is in the slot you flash**; the phone must be bootloader-unlocked and you need room in `super`
(we gave up the LineageOS install that was there).

```
fastboot reboot fastboot                                   # fastbootd, for logical partitions
fastboot create-logical-partition system_a <bytes>         # sizes: system 4600M rootfs, vendor 1000M, odm 450M
fastboot create-logical-partition vendor_a <bytes>
fastboot create-logical-partition odm_a <bytes>
fastboot flash system_a ut/system.img
fastboot flash vendor_a ut/vendor-ext4.img
fastboot flash odm_a    ut/odm-ext4.img
fastboot flash vbmeta_a exp/vbmeta-disabled.img            # vbmeta with verity+verification disabled (flags=3), tracked in this repo
fastboot flash dtbo_a   <dtbo.img>                         # a stock 8T dtbo: the Pixel Experience one, or LineageOS's (both boot)
fastboot flash boot_a   exp/halium-ncm.img
fastboot set_active a
fastboot erase userdata
fastboot reboot
```

Boot with the **power key and no USB cable**. A cable at power-on makes the bootloader pass
`androidboot.mode=charger`, and Ubuntu Touch then boots to `charger.target` (battery logo, no display manager). If it
looks stuck, re-run `fastboot set_active a` to reset the A/B retry counter. From a running UT,
`sudo reboot bootloader` reaches fastboot without the key combination.

Debug access: with the debug overlay, `usb-moded` rescue mode gives SSH on `10.15.19.82:8022` over USB (an NCM link,
so it works on macOS) until the display manager starts; after that use `adb` (enable Developer mode in Settings) or
the persistent journal.

## Lessons (what actually broke, and the fix)

1. **Kernel config.** `kona-perf_defconfig` sets `CC_WERROR=y` (the clang used for Halium 13 breaks on this old
   tree: turn it off), `SECURITY_APPARMOR_BOOTPARAM_VALUE=0` (AppArmor silently off: set 1), and has only NCM among
   the USB gadget functions (add RNDIS/ECM/ACM for usb-moded). Build with `LLVM_IAS=1` and `BRAND_SHOW_FLAG=oneplus`
   (the latter selects the OnePlus charger/haptics code paths), image name `Image`, no `deviceinfo_kernel_arch`.
2. **Android init grabs the USB gadget.** The vendor `init.qcom.usb.rc` binds gadget `g1` (also in charger mode), so
   `usb-moded` fails with EBUSY. Overlay an empty `init.qcom.usb.rc` via `usr/share/halium-overlay`.
3. **`vndservicemanager` needs `libselinux_stubs.so`.** Overlay its rc with `setenv LD_PRELOAD libselinux_stubs.so`
   (same fix as google-sargo).
4. **GLib 2.80 needs `waitid(P_PIDFD)`**, which 4.19 lacks even though it has `pidfd_open`. lightdm dies with
   `waitid(pid, pidfd) failed: EINVAL`. Patch `0001` backports it from 5.4.
5. **The Lomiri shell segfaulted inside the Adreno EGL driver** because `/dev/kgsl-3d0` and `/dev/ion` were
   `root:root 0600`. On Android `ueventd` fixes that; on UT the rootfs ships an empty `70-android.rules`. Overlay one
   that opens kgsl/ion/hgsl/drm to 0666. Found with gdb on a core dump.
6. **Touch was dead** because libinput rejects the panel: `device has min == max on ABS_MT_WIDTH_MAJOR`. A quirk
   (`MatchName=touchpanel`, `AttrEventCode=-ABS_MT_WIDTH_MAJOR;-ABS_MT_PRESSURE;`) fixes it. `MatchUdevType=touchscreen`
   is not a valid value and makes libinput drop the whole quirk file.
7. **Display cutout.** `etc/deviceinfo/devices/kebab.yaml`: grid unit 21, status bar 123 px, cutouts from the
   LineageOS device overlay.
8. **Wi-Fi.** The chip and firmware were fine (CNSS reaches MHI mission mode); the in-kernel qcacld driver only
   creates `wlan0` once userspace writes `ON` to `/dev/wlan`, which the Android Wi-Fi HAL does on Android. The
   `device-hacks` script does it after the container starts.
9. **`apparmor.service` always failed.** Its `ExecStartPre`, `wipe-aa-cache-on-channel-switch.py`, returns 1 on any
   system that is not system-image (OTA) based, which a tarball install never is. A drop-in
   `apparmor.service.d/zz-kebab-nonfatal-cache-wipe.conf` makes it non-fatal. The `zz-` prefix matters: drop-ins merge
   by filename and the original `lxc-android-config.conf` would otherwise re-add the fatal step after the reset.
10. **`media-hub-server` aborts** (`apparmor::Context cannot be created for empty name`) whenever an app opens a
    playback session, so notification sounds, ringtone previews and media playback fail even though the speaker works.
    Root cause: the kernel returns `ENOPROTOOPT` for `SO_PEERSEC` on Unix sockets, because this tree's AppArmor
    never records a peer label for `AF_UNIX` (no `unix_stream_connect` hook; mainline got that in 6.7, Ubuntu kernels
    carry it as a patch). The session D-Bus daemon therefore has no label to give
    (`AppArmorSecurityContextUnknown`). Patch `0002` adds the hook. With it, booted via `fastboot boot` (RAM only), the Settings sound previews play; confirmed by ear on 2026-11-21. Not yet flashed to `boot_a`.

11. **Saved Wi-Fi networks "forgot their password" after reboots.** The Wi-Fi interface is created as `wlan0` and
    systemd-udevd sometimes renames it to `wlp1s0` depending on timing. Saved profiles (netplan-generated NetworkManager
    files) are bound to the interface name, so after a rename NetworkManager ignores them and asks again. Pin the name
    with `etc/systemd/network/10-kebab-wlan.link` (`OriginalName=wlan0`, `NamePolicy=`, `Name=wlan0`). One clean boot
    verified; a second reboot is still to be checked.

Other gotchas: never press the power key while testing (logind powers off); the kernel log buffer wraps in minutes on
this phone because of touch-driver spam, so capture `dmesg` right after boot; the stock A/B retry counter can send you
back to the bootloader.

## Reference ports used

UBports `oneplus-salami` (OnePlus 11, Halium 13) for packaging; `google-sargo`, `sony-pdx225`, `nothing-spacewar`,
`xiaomi-vayu` and `samsung-q2q` community ports for overlay patterns (vndservicemanager, udev rules, `device-hacks`).
Find them under `gitlab.com/ubports/porting/community-ports`.

## Contributing

Issues and PRs welcome, especially from other SM8250 owners (OnePlus 8 / 8 Pro / 9 share this SoC and much of the
vendor stack). Please include `journalctl -b` or `dmesg` captured right after boot.

No license has been chosen yet; until one is added, reuse needs the author's permission.
