---
portType: "Halium 13.0"
kernelVersion: "4.19.306"
installLink: "https://github.com/oianmol/ubuntu-touch-oneplus-8t#flashing-the-sequence-that-worked"
portStatus:
  - categoryName: "Actors"
    features:
      - id: "manualBrightness"
        value: "+"
      - id: "notificationLed"
        value: "+"
      - id: "torchlight"
        value: "+"
      - id: "vibration"
        value: "+"
  - categoryName: "Camera"
    features:
      - id: "flashlight"
        value: "?"
      - id: "photo"
        value: "?"
      - id: "video"
        value: "?"
      - id: "switchCamera"
        value: "?"
  - categoryName: "Cellular"
    features:
      - id: "carrierInfo"
        value: "-"
      - id: "dataConnection"
        value: "-"
      - id: "dualSim"
        value: "-"
      - id: "calls"
        value: "-"
      - id: "volte"
        value: "-"
      - id: "mms"
        value: "-"
      - id: "pinUnlock"
        value: "-"
      - id: "sms"
        value: "-"
      - id: "audioRoutings"
        value: "-"
      - id: "voiceCall"
        value: "-"
      - id: "volumeControl"
        value: "-"
  - categoryName: "Endurance"
    features:
      - id: "batteryLifetimeTest"
        value: "?"
      - id: "noRebootTest"
        value: "?"
  - categoryName: "GPU"
    features:
      - id: "uiBoot"
        value: "+"
      - id: "videoAcceleration"
        value: "?"
  - categoryName: "Misc"
    features:
      - id: "waydroid"
        value: "?"
      - id: "apparmorPatches"
        value: "+-"
      - id: "batteryPercentage"
        value: "+"
      - id: "offlineCharging"
        value: "?"
      - id: "onlineCharging"
        value: "?"
      - id: "recoveryImage"
        value: "-"
      - id: "factoryReset"
        value: "?"
      - id: "rtcTime"
        value: "-"
      - id: "sdCard"
        value: "x"
      - id: "shutdown"
        value: "+"
      - id: "wirelessCharging"
        value: "x"
      - id: "wirelessExternalMonitor"
        value: "?"
  - categoryName: "Network"
    features:
      - id: "bluetooth"
        value: "+-"
      - id: "flightMode"
        value: "+-"
      - id: "fmRadio"
        value: "?"
      - id: "hotspot"
        value: "?"
      - id: "nfc"
        value: "?"
      - id: "wifi"
        value: "+"
  - categoryName: "Sensors"
    features:
      - id: "autoBrightness"
        value: "+"
      - id: "fingerprint"
        value: "?"
      - id: "gps"
        value: "?"
      - id: "proximity"
        value: "+"
      - id: "rotation"
        value: "+"
      - id: "touchscreen"
        value: "+"
  - categoryName: "Sound"
    features:
      - id: "earphones"
        value: "?"
      - id: "loudspeaker"
        value: "+"
      - id: "microphone"
        value: "+"
      - id: "volumeControl"
        value: "+"
  - categoryName: "USB"
    features:
      - id: "mtp"
        value: "?"
      - id: "adb"
        value: "+"
---

<section id="preinstall">

## Pre-install

- Requires an **unlocked bootloader**, which wipes the phone. Back up everything first, including a full partition backup.
- There is **no UBports Installer support yet**: installation is manual with fastboot and fastbootd, see the install link.
- The vendor and odm partitions must be repacked from EROFS to ext4.

</section>

<section id="notes">

## Notes

- Early-stage port, tested on a single KB2001. The rootfs currently ships with a debug overlay (empty-password SSH over USB, adb key verification off) that must be removed before everyday use.
- Audio output works through the speaker. Playback via media-hub needs the AppArmor `AF_UNIX` peer-label kernel patch included in the source repo.
- Features marked "-" are not implemented yet; "?" means untested.

</section>
