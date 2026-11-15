Copyright 2020 - The LineageOS Project

Device configuration for Samsung Galaxy Tab S 10.5 LTE (SM-T805)
================================================================

Basic   | Specification List
-------:|:-------------------------
CPU     | Quad-core 1.9 GHz Cortex-A15 + Quad-core 1.3 GHz Cortex-A7
Chipset | Samsung Exynos 5420 (ARMv7, 32-bit)
GPU     | ARM Mali-T628 MP6
Memory  | 3 GB
Shipped Android Version | 4.4.2
Storage | 16/32 GB
MicroSD | Up to 128 GB
Battery | Li-Ion 7900 mAh
Dimensions | 247.3 mm x 177.3 mm x 6.6 mm
Display | 2560 x 1600 pixel, 10.5"
Rear Camera  | 8.0 MP AF
Front Camera | 2.1 MP
Modem   | Intel XMM7260 (LTE)
Release Date | July 2014

Notes for LineageOS 21.0
-------------------------

* **No recovery image is built.** `TARGET_NO_RECOVERY := true`. The SM-T805
  `RECOVERY` partition is 10 MiB; a 21.0 recovery is ~12.6 MB. TWRP
  (3.7.0_9-0 verified) stays in that slot and is the install vehicle.
  `mka bacon` therefore aborts by design — build with
  `mka bootimage systemimage` and flash the images from TWRP.
* **Partition sizes are measured**, not copied from `chagallwifi`:

  | Partition | Bytes |
  |---|---|
  | BOOT | 8388608 |
  | SYSTEM | 2506096640 |
  | USERDATA | 12629049344 |
  | CACHE | 209715200 |

* **Non-Treble layout.** `/vendor` is a symlink to `/system/vendor`;
  there is no VNDK (`ro.treble.enabled=false`, no `BOARD_VNDK_VERSION`).
  `TARGET_COPY_OUT_VENDOR` resolves to `system/vendor`.
* **Install path:** TWRP -> Install -> Install Image -> `boot.img` -> Boot,
  then `system.img` -> System; or `dd` to
  `/dev/block/bootdevice/by-name/{BOOT,SYSTEM}` (note: TWRP has no
  `/dev/block/by-name`). Format Data before the first 21.0 boot.
* Back up `EFS` before flashing anything.
