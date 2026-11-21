---
name: "OnePlus 8T"
description: "Unofficial community port of Ubuntu Touch to the OnePlus 8T (KB2001/KB2003/KB2005, codename kebab) using Halium 13. Early stage: boots to Lomiri with GPU, touch, display and Wi-Fi."
# subforum: "number/oneplus-8t"   # add once a forum category exists (post in the forum's General section first)
deviceType: "phone"
price:
  min: 400
  max: 500
  currency: "USD"
  currencySymbol: "$"
deviceInfo:
  - id: "cpu"
    value: "Octa-core Kryo 585 (1x2.84 GHz + 3x2.42 GHz + 4x1.8 GHz)"
  - id: "chipset"
    value: "Qualcomm Snapdragon 865 5G (SM8250)"
  - id: "gpu"
    value: "Adreno 650"
  - id: "rom"
    value: "128 GB / 256 GB UFS 3.1"
  - id: "ram"
    value: "8 GB / 12 GB"
  - id: "android"
    value: "Android 11 (OxygenOS 11), Android 13 vendor used for the port"
  - id: "battery"
    value: "4500 mAh"
  - id: "display"
    value: "6.55 in AMOLED, 1080x2400, 120 Hz"
  - id: "rearCamera"
    value: "48 MP + 16 MP ultrawide + 5 MP macro + 2 MP mono"
  - id: "frontCamera"
    value: "16 MP"
  - id: "arch"
    value: "arm64"
  - id: "dimensions"
    value: "160.7 x 74.1 x 8.4 mm"
  - id: "weight"
    value: "188 g"
  - id: "releaseDate"
    value: "October 2020"
contributors:
  - name: "Anmol Verma"
    role: "Maintainer"
    # forum: ""   # forums.ubports.com profile link
sources:
  portType: "external"
  issuesLink: "https://github.com/oianmol/ubuntu-touch-oneplus-8t/issues"
externalLinks:
  - name: "Porting guide and source (GitHub)"
    link: "https://github.com/oianmol/ubuntu-touch-oneplus-8t"
unimplementedFeatures:
  - name: "Cellular modem (calls, SMS, mobile data)"
  - name: "Cameras"
  - name: "Bluetooth, sensors, fingerprint"
---
