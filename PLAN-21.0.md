# LineageOS 21.0 on SM-T805 (chagalllte) — Research & Port Plan

**Date:** 2026-11-15  
**Target:** `lineage-21.0` / Android 14 / `chagalllte` / Exynos 5420 / kernel 3.4.113 / armv7  
**Goal:** boot LOS 21.0 with **GPS, camera, RIL** preserved from the working 19.1 build.

> **Redacted copy.** This is the public copy of the working research document: the bench
> device's serial number and the author's local absolute paths have been removed. Everything
> else — measurements, source-code citations, decisions and evidence — is unchanged.

---

## 0. Verdict

**Feasible for a solo effort — roughly 2–4 weekends.** The reason is that the hard part
already exists: a maintained **LOS 21.0 port of the sibling `chagallwifi` (SM-T800)** by
retiredtab, plus **salih4187's working LOS 21.0 port of `ha3g` (SM-N900, same Exynos 5420,
same Samsung RIL stack, same legacy HAL1 camera)**.

What does **not** exist publicly:

| Missing piece | Impact | Workaround |
|---|---|---|
| `device/samsung/chagalllte` @ 21.0 | High (but mechanical) | Rebuild from chagallwifi 21.0 + the 19.1 LTE delta (~17 files) |
| `vendor/samsung/{chagalllte,chagall-common,universal5420-common}` @ 21.0 | Medium | Reuse the 19.1 vendor trees already on your disk, or re-extract |
| camera in `universal5420-common` @ 21.0 | Medium | Deliberately disabled by retiredtab (`PRODUCT_NO_CAMERA := true`); port salih's block |

Not required at 21.0 (contrary to the 22.0/23.x situation):

- **No eBPF backport.** The 583-commit `exynos5420-legacy` kernel work targets 23.x userspace.
  salih's ha3g runs LOS 21.0 with **zero** BPF support and a 3.4 kernel.
- **No LineageOS-UL platform forks.** salih's working manifest is stock LOS 21.0 + 6 forks.
- **No Treble re-architecture.** This is a **non-Treble** device: `/vendor` is a symlink into
  `/system/vendor`, `ro.treble.enabled=false`, `ro.product.vndk.version` is empty and no tree
  sets `BOARD_VNDK_VERSION`. Builds therefore use `TARGET_COPY_OUT_VENDOR := system/vendor`
  (`core/board_config.mk:673-677`) and 32-bit binder. salih's working 21.0 `ha3g` is likewise
  non-VNDK — no VNDK work is needed (§4.3.2).

**One hardware constraint found on the bench (2026-11-15):** the SM-T805 `RECOVERY` partition
is only **10 MiB**, while a LOS 21.0 recovery image is ~12.6 MB. **A 21.0 recovery cannot be
built or flashed on this device** — the build ships none, and `mka bacon` refuses to produce an
OTA zip at all (`non_ab_ota.py:583-585`, see §4.7). This costs nothing in practice:
**TWRP is already installed** in that slot and becomes the permanent flashing vehicle — builds
are installed as `boot.img` + `system.img`, not as a zip (§4.3.1, §4.9). Everything else in the
PIT matches `chagallwifi` exactly.

### 0.1 Open items before flashing

| # | Item | Status |
|---|---|---|
| 1 | Read the physical partition table from the tablet | ✅ **done 2026-11-15** — full PIT in §4.3.1, cross-checked inside TWRP |
| 2 | Confirm `chagalllte` PIT ≡ `chagallwifi` PIT | ❌ **differs** — `RECOVERY` is 10 MiB vs 13.49 MiB ⇒ **no 21.0 recovery image**. Non-issue: **TWRP is already installed** and stays (§4.3.1, §4.9) |
| 3 | Confirm TWRP boots and can flash images | ✅ **done 2026-11-15** — TWRP **3.7.0_9-0**, `/boot` + `/system_image` targets present (§4.9.1) |
| 4 | Fork `chagallwifi` → `android_device_samsung_chagalllte`, stage the 3 vendor trees | ✅ **done 2026-11-16** — device tree + 3 vendor trees generated, committed and **published** under `jmorrisson` (§4.2, §4.6, Appendix G) |
| 5 | Confirm `libshim_gpsd` satisfies LTE `gpsd` symbols | decided at build/first-boot (fallbacks in Appendix B) |

**Bench device (used for the measurements below):** SM-T805 (serial number removed),
bootloader `T805YDOU1CVG1`, currently running `lineage_chagalllte 19.1-20261102-UNOFFICIAL`
(Android 12, patch `2025-03-05`), USB `VID_04E8&PID_6860`.

---

## 1. Verified upstream state (checked 2026-11-15)

| Repository | Branch | Last commit | Role |
|---|---|---|---|
| `retiredtab/android_device_samsung_chagallwifi` | `lineage-21.0` | 2024-11-13 | **Template device tree** (boots LOS 21) |
| `retiredtab/android_device_samsung_chagall-common` | `lineage-21.0` | 2026-01-07 | Shared chagall config (**includes Dec-2025-SPL boot fix**) |
| `retiredtab/android_device_samsung_universal5420-common` | `lineage-21.0` | 2025-03-05 | Shared SoC config, **camera disabled** |
| `salih4187/android_device_samsung_chagalllte` | `lineage-19.1` | 2026-11-02 | **LTE delta source** (no 21.0 branch exists) |
| `salih4187/android_device_samsung_universal5420-common` | `lineage-21.0` | 2025-11-07 | **Camera-enabled common tree** (Phase 2 source) |
| `salih4187/android_device_samsung_ha3g` | `lineage-21.0` | — | **Proof-of-concept**: LOS 21 + modem + camera on Exynos 5420 |
| `salih4187/android_kernel_samsung_exynos5420` | `lineage-21.0-new` / `lineage-18.1` | — | Kernel (both have `lineageos_chagalllte_defconfig`) |
| `salih4187/android_hardware_samsung` | `lineage-21` | — | `libril`, `libsecril-client(-sap)`, camera HAL sources |
| `LineageOS/android_hardware_samsung_slsi_exynos5` | `lineage-18.1` | — | exynos5 platform (unchanged since 18.1) |
| `salih4187/android_hardware_samsung_slsi_exynos5420` | `lineage-18.1` | — | exynos5420 platform |
| `LineageOS/android_hardware_samsung_slsi_openmax` | `lineage-19.1` | — | OpenMAX video |
| `LineageOS/android_device_samsung_slsi_sepolicy` | `lineage-21` | — | SoC SELinux |
| `LineageOS/android_hardware_ril` | in LOS 21.0 `default.xml` | — | `rild`, `libreference-ril` — **still shipped** |
| `exynos5420-legacy/*` | `lineage-21-ul` | — | **Not needed** for 21.0 |

### Verified platform facts that de-risk the port

1. **Legacy HAL1 camera survives into Android 14.**
   `LineageOS/android_hardware_interfaces@lineage-21.0` still contains
   `camera/device/1.0/default/Android.bp` and `camera/provider/2.4/default/Android.bp`.
   `TARGET_HAS_LEGACY_CAMERA_HAL1 := true` (already in the common BoardConfig) is honoured.
2. **Legacy RIL survives.** `hardware/ril` is in the LOS 21.0 default manifest, and
   `hardware/samsung/ril/libril` builds `libril` when `BOARD_PROVIDES_LIBRIL := true`.
3. **`TARGET_NEEDS_NETD_DIRECT_CONNECT_RULE` is a no-op on plain LOS.** The flag only exists
   in LineageOS-UL's `android_system_netd`. It is absent from LOS **19.1 and 21.0** netd, yet
   your 19.1 build has working mobile data → safe to keep (or drop).
4. **`PRODUCT_NO_CAMERA := true`** in retiredtab's `universal5420-common/device-common.mk:68`
   is why the wifi tree has no camera. Nothing else blocks it.
5. **`chagall-common` 19.1 → 21.0 delta is one added file** (`manifests/device_framework_matrix.xml`)
   plus the livedisplay removal, so shared config needs no port work.

---

## 2. Tree layout / inheritance chain

```
device/samsung/chagalllte            <- to be created (~17 files from 19.1 + 21.0 base)
  BoardConfig.mk  ->  include device/samsung/chagall-common/BoardConfigCommon.mk
  device.mk       ->  inherit device/samsung/chagall-common/device-common.mk
        |
device/samsung/chagall-common        <- retiredtab @ lineage-21.0, unmodified
  BoardConfigCommon.mk -> include device/samsung/universal5420-common/BoardConfigCommon.mk
  device-common.mk     -> inherit vendor/samsung/chagall-common/chagall-common-vendor.mk
        |
device/samsung/universal5420-common  <- retiredtab @ lineage-21.0 (+ camera patch in Phase 2)
  device-common.mk -> inherit hardware/samsung_slsi/{exynos5,exynos5420}/*.mk
                   -> inherit vendor/samsung/universal5420-common/*-vendor.mk
```

Three vendor trees are required because each device-common inherits its own:

```
vendor/samsung/chagalllte/chagalllte-vendor.mk
vendor/samsung/chagall-common/chagall-common-vendor.mk
vendor/samsung/universal5420-common/universal5420-common-vendor.mk
```

---

## 3. The LTE delta — exact file list

`device/samsung/chagalllte` @ 21.0 = `chagallwifi` @ 21.0 **plus** these files from
`chagalllte` @ 19.1, and these edits.

### 3.1 Files taken verbatim from `chagalllte` @ 19.1

| Path | Purpose |
|---|---|
| `configs/init/rild.rc` | RIL daemon service (`vendor.ril-daemon`) |
| `ramdisk/etc/init.baseband.rc` | `cbd -d -txmm7160 -bh -mh -p 13`, `/efs`, `mmcblk0p13` symlink |
| `ramdisk/Android.mk` | installs both `.rc` files into `/vendor/etc/init/hw` |
| `include/telephony/ril.h`, `ril_commands_vendor.h`, `ril_unsol_commands_vendor.h` | Samsung RIL extensions (`TARGET_SPECIFIC_HEADER_PATH`) |
| `overlay/frameworks/base/core/res/res/values/config.xml` | `networkAttributes` incl. `mobile_*`, `config_radio_access_family=GSM\|WCDMA\|LTE`, `rmnet0` |
| `overlay/frameworks/base/core/res/res/xml/power_profile.xml` | LTE power profile |
| `overlay/frameworks/base/packages/SystemUI/res/values/config.xml` | `config_mobile_data` bits |
| `overlay/packages/services/Telephony/res/values/config.xml` | Telephony tunables |
| `overlay/packages/services/Telephony/res/values/network_mode.xml` | 2G/3G/4G mode list |
| `overlay/packages/apps/Dialer/.../callrecord/res/values/config.xml` | call recording |
| `overlay/packages/apps/Mms/res/xml/mms_config.xml` | MMS APN config |
| `shims/libcutils/{Android.mk,jstring.h,strdup16to8.cpp,strdup8to16.cpp}` | `libcutils_shim` for `libsec-ril.so` |
| `configs/gps/gps.xml` | **byte-identical to wifi's** — copy either |

### 3.2 Files that must be merged (19.1 LTE content + 21.0 base)

| File | Action |
|---|---|
| `BoardConfig.mk` | Start from 19.1; fix partition sizes + `PROCESS_SDK` path (see §4.3) |
| `device.mk` | 19.1 + swap `libshim_gps` → `libshim_gpsd`/`libshim_dmitry_gps` + add `libcutils_shim` |
| `system_prop.mk` | 19.1 verbatim (RIL props) |
| `AndroidProducts.mk`, `Android.mk` | `s/chagallwifi/chagalllte/` |
| `lineage_chagalllte.mk` | 19.1, but `full_base_telephony.mk` + `common_full_phone.mk` |
| `manifest.xml` | 19.1 verbatim (radio@1.0, radio.deprecated@1.0, ISap) |
| `proprietary-files.txt` | 19.1 verbatim (106 lines = wifi's 100 + 6) |
| `extract-files.sh`, `setup-makefiles.sh`, `lineage.dependencies` | `s/chagallwifi/chagalllte/` |
| `ramdisk/etc/init.target.rc` | 19.1 verbatim (imports baseband rc) |

### 3.3 The actual blob delta (6 lines)

```
lib/libwrappergps.so:vendor/lib/libwrappergps.so
# RIL
# cbd, from boot.img and pinned to stop removal when extracting from system image
bin/cbd:vendor/bin/cbd|18702d167b658d9d5c02eb7590efccedbd35063e
lib/libsec-ril.so:vendor/lib/libsec-ril.so
```

Everything else (100 entries) is shared with `chagallwifi` / `universal5420-common`.

---

## 4. Phase 1 — bootable LTE build, camera disabled

**Outcome:** LOS 21.0 boots, Wi-Fi/BT/audio/display work, RIL enumerates, no camera.

### 4.1 Workspace

```bash
mkdir -p ~/android/lineage && cd ~/android/lineage
repo init -u https://github.com/LineageOS/android.git -b lineage-21.0 --git-lfs
mkdir -p .repo/local_manifests
cp local_manifests.xml .repo/local_manifests/chagalllte.xml
repo sync -c -j"$(nproc)" --force-sync --no-clone-bundle --no-tags
```

Environment: Ubuntu 22.04/24.04, ≥16 GB RAM (32 GB comfortable), ≥300 GB free, `ccache` 50 GB.

### 4.2 `local_manifests.xml` draft

The device tree and all three vendor trees are published under `jmorrisson`
(`lineage-21.0` branch, pushed 2026-11-16). The two common *device* trees still come from
`retiredtab`; the vendor trees are ours (see Appendix G for how they were generated).

```xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- ===== devices ===== -->
  <project name="jmorrisson/android_device_samsung_chagalllte"
           path="device/samsung/chagalllte"      remote="github" revision="lineage-21.0" />
  <project name="retiredtab/android_device_samsung_chagall-common"
           path="device/samsung/chagall-common"  remote="github" revision="lineage-21.0" />
  <project name="retiredtab/android_device_samsung_universal5420-common"
           path="device/samsung/universal5420-common" remote="github" revision="lineage-21.0" />

  <!-- ===== kernel ===== -->
  <project name="salih4187/android_kernel_samsung_exynos5420"
           path="kernel/samsung/exynos5420"      remote="github" revision="lineage-21.0-new" />

  <!-- ===== hardware ===== -->
  <project name="salih4187/android_hardware_samsung"
           path="hardware/samsung"               remote="github" revision="lineage-21" />
  <project name="salih4187/android_hardware_samsung_slsi_exynos"
           path="hardware/samsung_slsi/exynos"   remote="github" revision="lineage-21.0" />
  <project name="LineageOS/android_hardware_samsung_slsi_exynos5"
           path="hardware/samsung_slsi/exynos5"  remote="github" revision="lineage-18.1" />
  <project name="salih4187/android_hardware_samsung_slsi_exynos5420"
           path="hardware/samsung_slsi/exynos5420" remote="github" revision="lineage-18.1" />
  <project name="LineageOS/android_hardware_samsung_slsi_openmax"
           path="hardware/samsung_slsi/openmax"  remote="github" revision="lineage-19.1" />
  <project name="LineageOS/android_device_samsung_slsi_sepolicy"
           path="device/samsung_slsi/sepolicy"   remote="github" revision="lineage-21" />

  <!-- ===== vendor ===== -->
  <project name="jmorrisson/android_vendor_samsung_chagalllte"
           path="vendor/samsung/chagalllte"      remote="github" revision="lineage-21.0" />
  <project name="jmorrisson/android_vendor_samsung_chagall-common"
           path="vendor/samsung/chagall-common"  remote="github" revision="lineage-21.0" />
  <project name="jmorrisson/android_vendor_samsung_universal5420-common"
           path="vendor/samsung/universal5420-common" remote="github" revision="lineage-21.0" />
</manifest>
```

> `hardware/ril` needs **no** entry — it is already in LOS 21.0 `default.xml` (verified).
> Do **not** add `LineageOS-UL` remotes; they are not needed and will drag in the 21-UL forks.

### 4.3 `device/samsung/chagalllte/BoardConfig.mk` (target content)

```make
# Inherit from chagall-common
include device/samsung/chagall-common/BoardConfigCommon.mk

LOCAL_PATH := device/samsung/chagalllte

# Include path (Samsung RIL headers)
TARGET_SPECIFIC_HEADER_PATH += $(LOCAL_PATH)/include

# Assert
TARGET_OTA_ASSERT_DEVICE := chagalllte,SM-T805

# Kernel
TARGET_KERNEL_CONFIG := lineageos_chagalllte_defconfig

# HIDL
DEVICE_MANIFEST_FILE += $(LOCAL_PATH)/manifest.xml

# Legacy BLOB support (rild is a prebuilt built for API 27)
TARGET_PROCESS_SDK_VERSION_OVERRIDE += \
    /vendor/bin/hw/rild=27

# Modem
BOARD_PROVIDES_LIBRIL := true
BOARD_MODEM_TYPE := xmm7260

# Network routing (dead flag on plain LOS, kept for parity with 19.1)
# TARGET_NEEDS_NETD_DIRECT_CONNECT_RULE := true

# Partitions — measured on this SM-T805 (see §4.3.1)
BOARD_BOOTIMAGE_PARTITION_SIZE := 8388608
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2506096640
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12629049344
BOARD_CACHEIMAGE_PARTITION_SIZE := 209715200
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_FLASH_BLOCK_SIZE := 4096

# Recovery: the T805 RECOVERY partition is 10 485 760 B and a LOS 21.0 recovery.img is
# ~12.6 MB. TWRP already occupies that slot — ship no recovery image so it is never
# overwritten, and flash every build from TWRP (§4.9).
TARGET_NO_RECOVERY := true

# Shims
TARGET_LD_SHIM_LIBS += \
    /vendor/bin/gpsd|/vendor/lib/libshim_gpsd.so \
    /vendor/lib/libsec-ril.so|libcutils_shim.so

# Inherit from the proprietary version
-include vendor/samsung/chagalllte/BoardConfigVendor.mk
```

#### 4.3.1 Partition table — measured on hardware (2026-11-15)

Read from the running 19.1 build (`lineage_chagalllte`, `19.1-20261102`, patch `2025-03-05`,
bootloader `T805YDOU1CVG1`) with `/sys/class/block/*/size` + `blockdev --getsize64`
(`/proc/partitions` is SELinux-blocked for `shell`).

| # | by-name | Bytes | MiB | Notes |
|---|---|---|---|---|
| p1 | BOTA0 | 4 194 304 | 4 | |
| p2 | BOTA1 | 4 194 304 | 4 | |
| p3 | EFS | 20 971 520 | 20 | IMEI / radio NV — **back this up** |
| p4 | m9kefs1 | 4 194 304 | 4 | |
| p5 | m9kefs2 | 4 194 304 | 4 | |
| p6 | m9kefs3 | 4 194 304 | 4 | |
| p7 | CARRIER | 4 194 304 | 4 | |
| p8 | PARAM | 8 388 608 | 8 | |
| p9 | **BOOT** | **8 388 608** | **8** | |
| p10 | **RECOVERY** | **10 485 760** | **10** | ⚠ smaller than chagallwifi |
| p11 | OTA | 10 485 760 | 10 | |
| p12 | CDMA-RADIO | 4 194 304 | 4 | |
| p13 | RADIO | 50 331 648 | 48 | modem firmware |
| p14 | TOMBSTONES | 4 194 304 | 4 | |
| p15 | TDATA | 4 194 304 | 4 | |
| p16 | PERSDATA | 12 582 912 | 12 | |
| p17 | RESERVED2 | 4 194 304 | 4 | |
| p18 | **SYSTEM** | **2 506 096 640** | **2390** | ✅ identical to chagallwifi |
| p19 | **CACHE** | **209 715 200** | **200** | |
| p20 | HIDDEN | 241 172 480 | 230 | |
| p21 | **USERDATA** | **12 629 049 344** | **12044** | |
| — | mmcblk0 | 15 762 133 504 | 15 031 | 14.68 GiB total |

**The T805 PIT is not the T800 PIT.** `boot`, `system`, `cache` and `userdata` match the
chagallwifi values exactly — **`RECOVERY` is 10 MiB, not 13.49 MiB.**

Consequences:

1. `BOARD_RECOVERYIMAGE_PARTITION_SIZE := 13485760` (the chagallwifi value) is **wrong here**:
   the build would emit a ~12.6 MB image that cannot fit, and a forced flash would spill into
   `OTA` / `CDMA-RADIO`.
2. **A LOS 21.0 recovery cannot be shipped on this device.** retiredtab's own build log records
   `recovery.img = 12 619 792 B` (12.03 MiB) — 2.6 MiB over the partition.
3. `TARGET_NO_RECOVERY := true` is honoured by 21.0: `build/make/core/board_config.mk:510-513`
   clears `BUILDING_RECOVERY_IMAGE`, and `core/Makefile:290-296` then never sets
   `INSTALLED_RECOVERYIMAGE_TARGET` — no `recovery.img`, and `core/Makefile:5833-5835` writes
   `no_recovery=true` into `misc_info.txt`, which makes the OTA generator abort (§4.7).
4. **TWRP stays.** It is already installed in `RECOVERY` (and fits the 10 MiB slot), so the
   device needs no LOS recovery at all: every 21.0 build is flashed from TWRP as
   `boot.img` + `system.img` (§4.9).

> This is a net win, not a compromise: TWRP gives image install, `dd`, backup/restore and
> `adb push` on a partition that could never hold a LOS 21.0 recovery anyway.

**Headroom for the ROM** (p18 = 2390 MiB): 19.1 fills ~1.2 GB of the ext4 filesystem; a 21.0
phone build lands around 2.0–2.4 GB. Tight but sufficient. If `system.img` exceeds the
partition, trim before repartitioning: drop `common_full_phone.mk` extras
(`common_full_tablet_wifionly.mk` + explicit phone packages), and check
`WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY := true` (already set in the common tree).

#### 4.3.2 Vendor layout — measured on hardware (2026-11-15)

Read from the running 19.1 build. This is the **non-Treble, vendor-in-system** layout, and it
is what the 21.0 build must reproduce.

| Fact | Value | Source |
|---|---|---|
| `/vendor` | symlink → `/system/vendor` | `ls -ld /vendor` |
| `/system/vendor` | real directory (11 entries, contains `bin/`, `etc/`, `lib/`) | `ls -ld /system/vendor` |
| `ro.treble.enabled` | `false` | `getprop` |
| `ro.product.vndk.version` | *(unset)* | `getprop` |
| `BOARD_VNDK_VERSION` | not set in any tree | grep of all `*.mk`/`*.bp` |
| `TARGET_COPY_OUT_VENDOR` | `system/vendor` (default when no vendor image) | `core/board_config.mk:673-677` |
| `rild` | `/system/vendor/bin/hw/rild` | `ls` |
| `gpsd` | `/system/vendor/bin/gpsd` | `ls` |
| `cbd` | `/system/vendor/bin/cbd` | `ls` |
| `libsec-ril.so` | `/system/vendor/lib/libsec-ril.so` | `ls` |
| ABI | `armeabi-v7a`,`armeabi` only — no 64-bit | `getprop ro.product.cpu.abilist` |

Consequences:

- **No VNDK work.** `TARGET_VNDK_USE_CORE_VARIANT := true` is present in
  `universal5420-common/BoardConfigCommon.mk:56` but is inert without `BOARD_VNDK_VERSION`;
  keep it for parity, expect no effect. Legacy blobs link against `/system/vendor/lib` plus the
  system libs exactly as on 19.1 — the VNDK-34 breakage risk does not apply here.
- **`/vendor/...` paths in `TARGET_LD_SHIM_LIBS` and `PRODUCT_COPY_FILES` are correct** because
  `/vendor` resolves to `/system/vendor` at runtime.
- **`TARGET_PROCESS_SDK_VERSION_OVERRIDE += /vendor/bin/hw/rild=27`** targets the real binary
  location (§4.3), not a typo.
- The 21.0 build emits **`system.img` only** — there is no `vendor.img` to flash (§4.7, §4.9).

### 4.4 `device/samsung/chagalllte/device.mk` (target content)

```make
LOCAL_PATH := device/samsung/chagalllte

DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# GPS
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/gps/gps.xml:$(TARGET_COPY_OUT_VENDOR)/etc/gps.xml

# Permissions
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.telephony.gsm.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.telephony.gsm.xml

# Ramdisk
PRODUCT_PACKAGES += \
    init.baseband.rc \
    init.target.rc

# Radio
PRODUCT_PACKAGES += \
    libprotobuf-cpp-full \
    libxml2 \
    rild \
    libril \
    libreference-ril \
    android.hardware.radio@1.0 \
    android.hardware.radio.deprecated@1.0

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/configs/init/rild.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/rild.rc

# Shims (libcutils_shim for libsec-ril, libshim_gpsd for gpsd)
PRODUCT_PACKAGES += \
    libcutils_shim \
    libshim_gpsd

# Vendor security patch level
PRODUCT_PROPERTY_OVERRIDES += \
    ro.lineage.build.vendor_security_patch=2016-07-01

# System properties
-include $(LOCAL_PATH)/system_prop.mk

# Inherit from chagall-common
$(call inherit-product, device/samsung/chagall-common/device-common.mk)

# Proprietary
$(call inherit-product-if-exists, vendor/samsung/chagalllte/chagalllte-vendor.mk)
```

**Why `libshim_gpsd` and not `libshim_gps`:** `libshim_gps` (salih's 6-line SensorManager stub)
has **no build rule at all** in any 19.1/21.0 tree — it exists only as a `.cpp` in
`salih/universal5420-common/libshims/libshim_gps/`. The LTE variant ships the *same*
`/vendor/bin/gpsd` blob as wifi, and wifi @ 21.0 already links it against `libshim_gpsd`
(which implements the same SensorManager symbols correctly). Fallback is documented in
Appendix B.

### 4.5 `lineage_chagalllte.mk`

```make
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, device/samsung/chagalllte/device.mk)
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_DEVICE := chagalllte
PRODUCT_NAME := lineage_chagalllte
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-T805
PRODUCT_MANUFACTURER := samsung
PRODUCT_GMS_CLIENTID_BASE := android-samsung

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=chagallltezh \
    PRIVATE_BUILD_DESC="chagallltezh-user 6.0.1 MMB29K T805ZHU1CQB1 release-keys"

BUILD_FINGERPRINT := samsung/chagallltezh/chagalllte:6.0.1/MMB29K/T805ZHU1CQB1:user/release-keys
```

These are the values the tablet actually reports
(`adb shell getprop ro.build.fingerprint` → `samsung/chagallltezh/...T805ZHU1CQB1...`,
`ro.build.description` → `chagallltezh-user 6.0.1 MMB29K T805ZHU1CQB1 release-keys`),
so the 19.1 tree's `PRODUCT_NAME=chagallltexx` was made consistent with its own
fingerprint. Cosmetic only — it affects `ro.build.*`, not the kernel or HALs.

### 4.6 Vendor blobs

> **Already staged locally (2026-11-15).** All three vendor trees were regenerated on this PC
> from the tablet's own 19.1 install and committed as git repos at
> a local staging root holding `vendor/samsung/{chagalllte,chagall-common,universal5420-common}`.
> They use the 21.0 layout (`Android.mk` + `Android.bp` + `<name>-vendor.mk` +
> `BoardConfigVendor.mk`) and were validated: 95 + 57 + 20 `PRODUCT_COPY_FILES` entries,
> **every source present on disk, zero destination overlaps between the trees**.
> Copy them into the Linux tree, or fall back to Option A below. Recipe + caveats: Appendix G.

**Option A — reuse the 19.1 build tree (fastest, ~30 min).**
Your 19.1 build already has all three vendor trees. `extract_utils` output is
format-compatible (`<device>-vendor.mk` + module definitions), so copy them across:

```bash
cp -a ~/android/lineage-19.1/vendor/samsung/chagalllte          ~/android/lineage/vendor/samsung/
cp -a ~/android/lineage-19.1/vendor/samsung/chagall-common      ~/android/lineage/vendor/samsung/
cp -a ~/android/lineage-19.1/vendor/samsung/universal5420-common ~/android/lineage/vendor/samsung/
```

**Option B — regenerate (cleaner, ~1 h).** Needs a full 19.1 dump (`system.img` — it already
contains `/system/vendor`, so there is no `vendor.img` — or a TWRP backup) at `$DUMP`:

```bash
cd device/samsung/chagalllte && ./extract-files.sh "$DUMP"
cd ../universal5420-common    && ./extract-files.sh "$DUMP"
```

> **`chagall-common/extract-files.sh` cannot regenerate its own tree.** Run directly it just
> delegates to `./../../samsung/universal5420-common/extract-files.sh` (which extracts the
> *universal* list), and its own 57-entry `proprietary-files.txt` is never read. The
> `if [ "${BASH_SOURCE[0]}" != "${0}" ]; then return; fi` guard shows it is designed to be
> *sourced* by a caller that sets `DEVICE_COMMON=chagall-common` — nothing in the 19.1/21.0
> trees does that, so the 19.1 chagall-common vendor tree must have been generated by hand
> years ago. Drive `extract_utils.sh` directly instead — see `run-extract-chagall-common.sh`
> in Appendix G — or use the already-staged tree.
> Blob lists: `chagallwifi` 100 lines, `chagalllte` 106 (+`libwrappergps.so`, `cbd`,
> `libsec-ril.so`), `universal5420-common` 44, `chagall-common` 57 entries.

### 4.7 Build

```bash
source build/envsetup.sh
lunch lineage_chagalllte-userdebug
mka bootimage systemimage -j"$(nproc)"
```

Output: `out/target/product/chagalllte/boot.img` + `system.img`.

**Do not use `mka bacon` on this device — it cannot work.** The chain is fully verified:

| Step | Evidence |
|---|---|
| 1. `TARGET_NO_RECOVERY := true` leaves `INSTALLED_RECOVERYIMAGE_TARGET` empty | `build/make/core/Makefile:283,290-296` |
| 2. No recovery image ⇒ `no_recovery=true` written into `META/misc_info.txt` | `core/Makefile:5833-5835` |
| 3. Non-A/B OTA generator refuses such a build **before writing anything** | `tools/releasetools/non_ab_ota.py:583-585` |

```text
common.ExternalError: --- target build has specified no recovery ---
```

So `bacon` aborts in seconds and **never emits a zip**. That is the safe failure: there is no
`lineage-21.0-*.zip` that could run `WriteRawImage("/recovery", "recovery.img")` over TWRP
(`non_ab_ota.py:204`). Also note there is no `vendor.img`: `/vendor` lives inside `system.img`
as `/system/vendor` (the device has no vendor partition — §4.3.1).

A plain `mka` (default `droid`) also works and additionally builds the rest of the images; it
still produces no recovery and no zip, because both depend on `INSTALLED_RECOVERYIMAGE_TARGET`.

### 4.8 Expected failures and fixes

| Symptom | Cause | Fix |
|---|---|---|
| `--- target build has specified no recovery ---` | ran `mka bacon` with `TARGET_NO_RECOVERY := true` | **expected** — build `mka bootimage systemimage` and flash from TWRP (§4.7, §4.9) |
| `recovery.img too large` | T805 `RECOVERY` is 10 MiB; 21.0 recovery is ~12.6 MB | **not fixable** — `TARGET_NO_RECOVERY := true` (done above), ship no recovery |
| `system.img too large` | 19.1 cap was 2.1 GB | `2506096640` = measured partition size (done above) |
| `module "libshim_gps" in PRODUCT_PACKAGES has nothing to install` | missing build rule | replaced by `libshim_gpsd` (done above) |
| `error: cannot find libGLES_mali.so shim` | none | `libgutils` shim already in common tree |
| Neverallow failures | legacy HAL1 camera / RIL | `SELINUX_IGNORE_NEVERALLOWS := true` already in common |
| Boot loops after Dec 2025 SPL | livedisplay HAL | already fixed at tip of `chagall-common` (2026-01-07) |
| `rild` segfault on start | legacy blob + 64-bit `libcutils` | `libcutils_shim` (done above) |

### 4.9 Installing from TWRP (verified on the device, 2026-11-15)

TWRP occupies `RECOVERY` and fits its 10 MiB, so it is the permanent flashing vehicle.
`TARGET_NO_RECOVERY := true` means the 21.0 build **never touches `RECOVERY`** — TWRP survives
every flash. This is the intended configuration, not a workaround.

Because **no OTA zip is produced** (§4.7), the install path is image flashing. TWRP does this
natively and needs no `adb sideload`.

#### 4.9.1 TWRP — measured facts

Booted into recovery and read from the device:

| Item | Value |
|---|---|
| Version | **TWRP 3.7.0_9-0** (built 2022-10-16, Android 6.0.1 base) |
| Device id | `chagalllte` / `SM_T805Y` |
| Image targets | `/boot`, `/system_image` → `SYSTEM`, `/recovery`, `/modem`, `/hidden_image` |
| `by-name` path | **`/dev/block/bootdevice/by-name/…`** |
| `/dev/block/by-name` | **does not exist in TWRP** (it exists in booted Android 12) |
| `/data` free | 10.7 GB |
| Micro-SD | 59.5 GB free, mounted at `/external_sd` |
| Encryption | `ro.crypto.state=unencrypted` — no decryption step |

TWRP's own sizes agree with the Android-side PIT exactly:

| Partition | `blockdev --getsize64` |
|---|---|
| BOOT | 8 388 608 |
| RECOVERY | 10 485 760 |
| SYSTEM | 2 506 096 640 |
| USERDATA | 12 629 049 344 |
| CACHE | 209 715 200 |
| EFS | 20 971 520 |

> **Path gotcha:** every `dd` below must use `/dev/block/bootdevice/by-name/…` when run inside
> TWRP. Copy-pasting `/dev/block/by-name/…` from a booted-system shell will fail with
> "No such file or directory". The GUI paths are unaffected.

**0. Back up `EFS` first** (p3, 20 MiB — holds IMEI and radio NV; the only truly irreplaceable
partition):

```bash
adb reboot recovery
adb shell "dd if=/dev/block/bootdevice/by-name/EFS of=/external_sd/efs.img bs=4M"
adb pull /external_sd/efs.img
```

**A. Push the images**

`system.img` is ~2.4 GB, so push to the micro-SD — it survives the data wipe in step D:

```bash
adb push out/target/product/chagalllte/boot.img   /external_sd/boot.img
adb push out/target/product/chagalllte/system.img /external_sd/system.img
```

(`/sdcard` also works — 10.7 GB free — but `Format Data` in step D erases it.)

**B. Flash from the TWRP GUI (recommended for the first install)**

```text
Install -> Install Image -> external_sd/boot.img   -> select "Boot"   -> Swipe
Install -> Install Image -> external_sd/system.img -> select "System" -> Swipe
```

TWRP writes the raw ext4 image directly; it does not need to understand the filesystem.

**C. Or flash by `dd` (faster, scriptable, same result)**

```bash
adb shell "dd if=/external_sd/boot.img   of=/dev/block/bootdevice/by-name/BOOT   bs=4M"
adb shell "dd if=/external_sd/system.img of=/dev/block/bootdevice/by-name/SYSTEM bs=4M"
adb shell sync
```

Never `dd` an image larger than the target partition. Both paths are safe to re-run; nothing
outside `BOOT` and `SYSTEM` is written.

**Validate before writing:**

```bash
adb shell "blockdev --getsize64 /dev/block/bootdevice/by-name/BOOT"     # 8388608
adb shell "blockdev --getsize64 /dev/block/bootdevice/by-name/SYSTEM"   # 2506096640
ls -l out/target/product/chagalllte/boot.img out/target/product/chagalllte/system.img
```

`boot.img` must be ≤ 8 388 608 B and `system.img` ≤ 2 506 096 640 B. The build's own
`assert-max-image-size` (fed by the measured values in §4.3) already enforces both.

**D. Wipe data before first boot** — 19.1 → 21.0 changes keystore/APEX state, so a dirty
`/data` will not boot:

```text
TWRP -> Wipe -> Format Data -> type "yes"
```

(`Format Data`, not "Advanced Wipe": it recreates the filesystem the 21.0 build expects.)

**Re-flashing a later 21.0 build:** repeat A → B/C. No wipe needed between 21.0 builds.

> If a flashable zip is ever wanted for convenience, it must be hand-rolled around TWRP's
> `update-binary` (`package_extract_file("system.img",
> "/dev/block/bootdevice/by-name/SYSTEM")`), because `bacon` structurally refuses this
> configuration. Not required — image flashing is fewer steps.

---

## 5. Phase 2 — camera (the main porting work)

**Effort: 4–12 h.** The camera HAL for this SoC is **source-built inside the common tree** —
there are no camera blobs to extract.

What retiredtab disabled (all reversible):

| File | Disabled state | Enable by |
|---|---|---|
| `universal5420-common/device-common.mk:61-68` | camera packages commented + `PRODUCT_NO_CAMERA := true` | uncomment 4 packages, delete the flag |
| `universal5420-common/device-common.mk:210-223` | `libshim_camera` commented | add `libshim_camera` to `PRODUCT_PACKAGES` |
| `universal5420-common/camera/Android.mk` | renamed `Android.mk.old` | rename back → builds `libexynoscamera` + `camera.universal5420` |
| `universal5420-common/libshims/libshim_camera/Android.mk` | renamed `Android.mk.old` | rename back → builds `libshim_camera` |
| `universal5420-common/BoardConfigCommon.mk:167` | shim line commented | `/vendor/lib/libexynoscamera.so\|/vendor/lib/libshim_camera.so` |

The four packages resolve as:

| Module | Source |
|---|---|
| `android.hardware.camera.provider@2.4-impl.exynos5420` | `universal5420-common/hardware/camera/provider/Android.bp` |
| `camera.device@1.0-impl.exynos5420` | `universal5420-common/hardware/camera/device/Android.bp` |
| `camera.universal5420` (`/vendor/lib/hw/camera.universal5420.so`) | `universal5420-common/camera/Android.mk` |
| `libexynoscamera` | same `Android.mk` |

⚠️ **Do not copy salih's `device-common.mk` wholesale.** His 21.0 branch is a *different
lineage* of the tree (it still has `android.hardware.ir@1.0-service.samsung`,
`android.hardware.power-service.exynos`, HIDL vibrator, `BOARD_USE_HEVCDEC_SUPPORT := false`).
Diff against retiredtab is 427 insertions / 365 deletions across 39 files. Port **only** the
camera-specific hunks listed above.

Optional extras worth stealing from salih's tree, one at a time, only if the corresponding
feature is broken: `configs/egl.cfg` + `BOARD_EGL_CFG`, `OVERRIDE_RS_DRIVER`, `BOARD_USE_CSC_HW := false`.

---

## 6. Phase 3 — GPS + RIL validation

### GPS path on LTE
`libwrappergps.so` (blob) → `gpsd` → modem via RIL. On 21.0 gpsd needs the SensorManager
interposition because `libsensor_vendor`'s API changed. Shims already wired in §4.3.

Check:
```bash
adb shell getprop | grep -i gps
adb shell dumpsys location | head -40
adb logcat -s gpsd:G libwrappergps:G Gnss:* | head
```

Success: fix within ~2 min outdoors, satellites > 0, `gpsd` stays alive (no `linker` errors).

### RIL path
```
rild (prebuilt, /vendor/bin/hw/rild -c 1 -l /vendor/lib/libsec-ril.so)
  -> libsec-ril.so (+ libcutils_shim, cbd)
  -> cpboot-daemon: cbd -d -txmm7160 -bh -mh -p 13
```
Check:
```bash
adb shell getprop | grep -E 'rild|telephony|radio'
adb shell dumpsys telephony.registry | head -60
adb shell logcat -b radio | head -100
```
Success: SIM detected, network registered, call + SMS + mobile data, LTE attach, airplane
toggle recovers.

⚠️ Note the inconsistency inherited from 19.1: `BOARD_MODEM_TYPE := xmm7260` (only sets
`-DSAMSUNG_NEXT_GEN_MODEM`) while `cbd` is invoked with `-txmm7160`. It works on 19.1;
do not "fix" it silently.

---

## 7. Risk register

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| 1 | `RECOVERY` partition is 10 MiB; a LOS 21.0 recovery is ~12.6 MB | **Certain (measured)** | **None** — TWRP 3.7.0_9-0 verified installed and booting | `TARGET_NO_RECOVERY := true` keeps TWRP untouched; flash from TWRP (§4.9) |
| 2 | Legacy blobs break on Bionic 14 | Med | High | **no VNDK on this device** (§4.3.2), so 19.1-era blobs keep their existing link surface; existing shims (`libcutils_shim`, `libgutils`, `libshim_gpsd`); salih's ha3g 21.0 runs the same blob style on the same SoC → strong signal |
| 3 | RIL fails (radio@1.0 on A14) | Med | High | ha3g 21.0 runs RIL on the same stack; `TARGET_PROCESS_SDK_VERSION_OVERRIDE` already applied |
| 4 | Camera HAL1 removed from 21.0 interfaces | **Low** | High | verified present in `lineage-21.0` (camera/device/1.0, provider/2.4) |
| 5 | `libshim_gpsd` insufficient for LTE gpsd | Med | Med | add `libshim_dmitry_gps` entry; last resort build salih's `libshim_gps` (Appendix B) |
| 6 | SELinux denials block `cbd`/`rild` | Med | High | neverallow ignore already on; add `sepolicy/vendor` rules from 19.1 if denials appear |
| 7 | Kernel missing 21.0 fixes | Low | High | use `lineage-21.0-new` (22 commits over 19.1: binder cred/SELinux, OFD locks, USB gadget CVEs) |
| 8 | Dec-2025 security patches break boot | Low | High | tip of `chagall-common` already removes `vendor.lineage.livedisplay` |
| 9 | User bricks device by flashing wrong partition sizes | Low | Critical | only `dd` into `by-name` targets after checking `blockdev --getsize64`; keep a TWRP backup of `efs` |
| 10 | No public vendor trees for 21.0 | **Certain** | Low | reuse 19.1 vendor trees (Option A) |

---

## 8. Effort estimate

| Phase | Work | Hours |
|---|---|---|
| 0 | repo init/sync, toolchain, ccache warm | 2–4 |
| 1 | Assemble `chagalllte` 21.0 tree (17 files + 4 merges) | 3–5 |
| 2 | Vendor blobs (copy or re-extract) | 1–3 |
| 3 | First successful build (`mka bootimage systemimage`) | 3-8 |
| 3b | TWRP install path (Install Image, or `dd` directly) | 1-2 |
| 4 | Boot debugging (init, SELinux, display, audio) | 4–12 |
| 5 | Camera port + validation | 4–12 |
| 6 | GPS/RIL/data validation | 3–10 |
| — | **Total** | **21–57 h (~2–4 weekends)** |

First build on a fresh tree: 2.5–5 h on 8 cores without ccache; subsequent builds 10–30 min.

---

## 9. Acceptance / test plan

**Boot & base**
- [ ] Boots to setup wizard, no bootloop
- [ ] TWRP still boots and can write `boot.img` + `system.img` (21.0 ships no recovery by design — §4.3.1)
- [ ] `getprop ro.build.version.release` → `14`, `ro.lineage.version` contains `21.0`
- [ ] Display 2560×1600, brightness slider, rotation, auto-brightness
- [ ] Wi-Fi (2.4/5 GHz), Bluetooth (pair + A2DP), audio speaker/headphones/mic
- [ ] Charging, battery stats, deep sleep (`dumpsys deviceidle`, overnight drain < 3 %/h)

**Camera (Phase 2)**
- [ ] Rear 8 MP photo, front 2.1 MP photo
- [ ] Video record rear + front, playback
- [ ] Flash/torch, autofocus, Camera2 API level reported ≥ LEGACY
- [ ] No `libexynoscamera` / `libshim_camera` errors in logcat

**GPS**
- [ ] `gpsd` running, no linker errors
- [ ] Cold TTFF < 120 s outdoors, ≥ 6 satellites
- [ ] Location in Maps, no `GC` wakelock leak

**RIL**
- [ ] SIM detected, carrier name correct
- [ ] Voice call in/out, in-call audio, hangup
- [ ] SMS in/out, MMS
- [ ] Mobile data (LTE), speedtest, tethering
- [ ] Airplane mode toggle ×3 recovers network
- [ ] `cbd` and `rild` survive 24 h uptime

**Regression vs 19.1**
- [ ] Sensors (accel/gyro/light/proximity/magnetic/grip), touch keys, IR blaster
- [ ] Hardware video decode (YouTube 1080p), no green frames
- [ ] MHL/HDMI out (optional)

---

## Appendix A — files to create (checklist)

```
device/samsung/chagalllte/
├── Android.mk                  (s/chagallwifi/chagalllte/)
├── AndroidProducts.mk          (s/chagallwifi/chagalllte/)
├── BoardConfig.mk              (§4.3)
├── device.mk                   (§4.4)
├── extract-files.sh            (s/chagallwifi/chagalllte/)
├── lineage.dependencies        (chagall-common)
├── lineage_chagalllte.mk       (§4.5)
├── manifest.xml                (19.1 verbatim)
├── proprietary-files.txt       (19.1 verbatim)
├── setup-makefiles.sh          (s/chagallwifi/chagalllte/)
├── system_prop.mk              (19.1 verbatim)
├── configs/gps/gps.xml
├── configs/init/rild.rc
├── include/telephony/{ril.h,ril_commands_vendor.h,ril_unsol_commands_vendor.h}
├── overlay/frameworks/base/core/res/res/values/config.xml
├── overlay/frameworks/base/core/res/res/xml/power_profile.xml
├── overlay/frameworks/base/packages/SystemUI/res/values/config.xml
├── overlay/packages/apps/Dialer/.../res/values/config.xml
├── overlay/packages/apps/Mms/res/xml/mms_config.xml
├── overlay/packages/services/Telephony/res/values/{config.xml,network_mode.xml}
├── ramdisk/Android.mk
├── ramdisk/etc/{init.baseband.rc,init.target.rc}
└── shims/libcutils/{Android.mk,jstring.h,strdup16to8.cpp,strdup8to16.cpp}
```

## Appendix B — fallback `libshim_gps` module

Only if neither `libshim_gpsd` nor `libshim_dmitry_gps` resolves `gpsd`'s symbols.

`device/samsung/chagalllte/libshims/libshim_gps/Android.bp`:
```bp
cc_library_shared {
    name: "libshim_gps",
    proprietary: true,
    srcs: ["libshim_gps.cpp"],
}
```

`libshim_gps.cpp` (from `salih/universal5420-common@lineage-21.0`):
```cpp
#include <stdlib.h>
extern "C" void _ZNK7android13SensorManager13getSensorListEPPKPKNS_6SensorE();
extern "C" void _ZNK7android13SensorManager13getSensorListEPPKPKNS_6SensorE(){}
extern "C" void _ZN7android13SensorManager16createEventQueueENS_7String8Ei();
extern "C" void _ZN7android13SensorManager16createEventQueueENS_7String8Ei(){}
```

Then in `BoardConfig.mk`:
```make
TARGET_LD_SHIM_LIBS += /vendor/bin/gpsd|/vendor/lib/libshim_gps.so
```
and `PRODUCT_PACKAGES += libshim_gps` in `device.mk`.

## Appendix C — key upstream commits to read before starting

| Commit | Why |
|---|---|
| `chagallwifi: increase recovery partition size again due to LineageOS 21 code getting fatter` (2024-11-13) | partition sizing rationale |
| `chagall-common: remove vendor.lineage.livedisplay because OS won't boot after Dec 2025 security patches` (2026-01-07) | mandatory for current 21.0 |
| `chagalllte: Update RIL for S` (2026-11-02) | latest RIL blob/prop state |
| `Revert "Camera: Fix Camera recording"` (salih, 2025-11-07) | camera recording state on 21.0 |

## Appendix D — what would make this a 22.0/23.x task instead

For reference only: LOS 22.0+ requires `kernel/bpf`, `CONFIG_BPF_SYSCALL`, seccomp-bpf rewrite,
cgroup2, `dm-verity`, `renameat2`, `d_is_negative`, `div64`, `IFA_FLAGS`, utsname spoofing
(583 commits / 300 files), **plus** ~55 LineageOS-UL platform forks. That is why 21.0 is the
right target: none of it is needed here.

## Appendix E — why `mka bacon` cannot work here (source evidence)

All line numbers are `LineageOS/android_build@lineage-21.0`.

| File | Lines | What it does |
|---|---|---|
| `core/board_config.mk` | 503-518 | `BUILDING_RECOVERY_IMAGE` cleared when `TARGET_NO_RECOVERY` is true |
| `core/Makefile` | 283-296 | `INSTALLED_RECOVERYIMAGE_TARGET` only set `ifdef BUILDING_RECOVERY_IMAGE` |
| `core/Makefile` | 3546-3559 | `RECOVERY_FROM_BOOT_PATCH` only defined when `INSTALLED_RECOVERYIMAGE_TARGET` is non-empty |
| `core/Makefile` | 5833-5835 | `ifeq ($(INSTALLED_RECOVERYIMAGE_TARGET),)` → `echo "no_recovery=true" >> misc_info.txt` |
| `tools/releasetools/non_ab_ota.py` | 583-585 | `if info_dict["no_recovery"] == "true": raise ExternalError(...)` — first statement in `GenerateNonAbOtaPackage` |
| `tools/releasetools/non_ab_ota.py` | 152 | `assert HasRecoveryPatch(...)` — would also fail |
| `tools/releasetools/non_ab_ota.py` | 204 | `script.WriteRawImage("/recovery", "recovery.img")` — the destructive step that is never reached |

`vendor_lineage/build/tasks/bacon.mk` merely symlinks `$(INTERNAL_OTA_PACKAGE_TARGET)` to
`lineage-$(LINEAGE_VERSION).zip`, so when the OTA writer raises, `bacon` fails and no file is
created. Net effect: **the build cannot damage TWRP.**

## Appendix F — how the partition table was measured (reproducible)

```bash
adb devices -l                                   # <serial>  device
adb shell "ls -l /dev/block/platform/*/by-name"  # by-name -> mmcblk0pN
adb shell "blockdev --getsize64 /dev/block/mmcblk0p10"   # 10485760  (RECOVERY)
adb shell "blockdev --getsize64 /dev/block/mmcblk0p18"   # 2506096640 (SYSTEM)
adb shell "cat /sys/class/block/mmcblk0pN/size"          # 512-byte sectors
```

Cross-checked a second time from **inside TWRP** (`/sbin` has `blockdev`):

```bash
adb reboot recovery
adb shell "blockdev --getsize64 /dev/block/bootdevice/by-name/SYSTEM"   # 2506096640
adb shell "getprop ro.twrp.version"                                     # 3.7.0_9-0
```

All six partition sizes matched the Android-side values byte-for-byte.

Notes from the session:

- **`/dev/block/by-name` and `/dev/block/bootdevice/by-name` are not interchangeable.**
  The booted 19.1 system exposes `/dev/block/by-name/…`; TWRP exposes only
  `/dev/block/bootdevice/by-name/…`. Scripts that run in recovery must use the latter.
- `cat /proc/partitions` → **Permission denied** for the `shell` user on 19.1; use
  `/sys/class/block/*/size` (world-readable) or `blockdev` instead.
- `adb root` restarted adbd and the transport stayed `offline` until the cable was physically
  re-plugged. **Don't run `adb root` for this** — it is not needed.
- Cross-check: `/proc/partitions` values × 1024 must equal `blockdev --getsize64`.

## Appendix G — how the vendor trees were staged (2026-11-15)

No public 21.0 vendor repos exist for this platform (`exynos5420/*` stops at 18.1,
`retiredtab` never published vendor repos), so all three were rebuilt from the tablet's own
19.1 install — which is the ideal source, because the blobs on the device are already
post-fixup (see below).

**Toolchain (Windows host, WSL1 AlmaLinux, Windows platform-tools).**

The 21.0 `extract_utils.sh` needs a Linux `llvm-objdump` and `patchelf`. Neither exists on the
machine, so:

- `patchelf` — downloaded from
  `LineageOS/android_prebuilts_extract-tools@lineage-21.0` (`linux-x86/bin/patchelf-0_18`) and
  installed as `prebuilts/extract-tools/linux-x86/bin/patchelf-{0_8,0_9,0_17_2,0_18}`.
- `llvm-objdump` — GNU binutils installed into `/opt/root` with
  `dnf --nogpgcheck --installroot=/opt/root install binutils` (the host rpmdb could not be
  written to), then a wrapper at
  `prebuilts/clang/host/linux-x86/llvm-binutils-stable/llvm-objdump` runs it through
  `/opt/root/lib64/ld-linux-x86-64.so.2 --library-path` and rewrites the GNU `-f`
  `file format elf32-little` into llvm's `file format elf32-littlearm` (which is the exact
  string `elf_format_android()` matches on).
- `adb` — a wrapper script (`/opt/tools/bin/adb`) around the Windows `adb.exe` that:
  translates `pull` destinations with `wslpath -w`, **creates missing parent directories**
  (Windows `adb pull` does not, Linux `adb pull` does — without this every blob fails),
  strips CR from `get-state`/`devices`/`shell` output (CRLF breaks
  `[[ "$(adb get-state)" == device ]]`, which otherwise loops forever), and no-ops `adb root`.

**Extraction drivers** (`buildroot/run-extract-*.sh`):

```bash
run-extract-universal.sh        # bash $DIR/extract-files.sh -n   (tree's own script)
run-extract-chagall-common.sh   # setup_vendor chagall-common samsung $ROOT true true + extract + setup-makefiles.sh
run-extract-chagalllte.sh       # same shape for chagalllte, with guarded fixups
```

The drivers pass an absolute `ANDROID_ROOT`, because `extract_utils` otherwise builds
relative `adb pull` destinations (`./../../../vendor/...`) which the Windows `adb` resolves
against the wrong directory.

**Fixups are conditional in the chagalllte driver** — pulling from a built 19.1 system means
they are already applied. It reported:

```
libsec-ril.so: protobuf dependency already fixed
libsec-ril.so: gpsd path already /vendor/bin/gpsd
gpsd: SSL method already patched
```

**The NXP caveat.** 84 `vendor/etc/nxp/**/…ControlParams…txt` files listed by the LTE
`proprietary-files.txt` do not exist anywhere on the 19.1 install (`/system/vendor/etc/nxp`
does not exist; neither does `/system/etc/nxp`). They were downloaded from the public
`exynos5420/android_vendor_samsung_chagallwifi@lineage-18.1` repo
(`proprietary/vendor/etc/nxp/...`) — identical static NXP calibration data. If you regenerate
from your own 19.1 `vendor/` tree instead, you get the originals.

**Validation run against the generated trees:**

| Vendor tree | `PRODUCT_COPY_FILES` | Sources missing on disk | Destination overlaps |
|---|---|---|---|
| `universal5420-common` | 20 | 0 | 0 |
| `chagall-common` | 57 | 0 | 0 |
| `chagalllte` | 95 | 0 | 0 |

`chagalllte` overlaps were checked against both common trees (a duplicate
`PRODUCT_COPY_FILES` destination aborts the build).

**Repos created — local paths and published URLs (public, branch `lineage-21.0`):**

| Local path | GitHub | Commit |
|---|---|---|
| `chagalllte-21.0` | `https://github.com/jmorrisson/android_device_samsung_chagalllte` | `22eb2ca` |
| `buildroot/vendor/samsung/chagalllte` | `https://github.com/jmorrisson/android_vendor_samsung_chagalllte` | `346d7e2` |
| `buildroot/vendor/samsung/chagall-common` | `https://github.com/jmorrisson/android_vendor_samsung_chagall-common` | `8c78a59` |
| `buildroot/vendor/samsung/universal5420-common` | `https://github.com/jmorrisson/android_vendor_samsung_universal5420-common` | `193e805` |

All four were verified after the push (`git ls-remote` commit hash == local HEAD).

All four include a `.gitattributes` (`* text=auto eol=lf`) and were committed with
`core.autocrlf=false`, so a fresh clone on Linux gets LF line endings regardless of the
Windows-side defaults.
