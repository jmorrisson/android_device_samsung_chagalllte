#
# Copyright (C) 2018 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Inherit from chagall-common
include device/samsung/chagall-common/BoardConfigCommon.mk

LOCAL_PATH := device/samsung/chagalllte

# Include path
TARGET_SPECIFIC_HEADER_PATH += $(LOCAL_PATH)/include

# Assert
TARGET_OTA_ASSERT_DEVICE := chagalllte,SM-T805

# Kernel
TARGET_KERNEL_CONFIG := lineageos_chagalllte_defconfig

# HIDL
DEVICE_MANIFEST_FILE += $(LOCAL_PATH)/manifest.xml

# Legacy BLOB support
# rild on this device lives at /system/vendor/bin/hw/rild and is built for API 27.
# /vendor is a symlink to /system/vendor on this (non-Treble) device.
TARGET_PROCESS_SDK_VERSION_OVERRIDE += \
    /system/vendor/bin/hw/rild=27

# RIL
BOARD_PROVIDES_LIBRIL := true
BOARD_MODEM_TYPE := xmm7260

# Partitions
# Measured on SM-T805 (T805YDOU1CVG1): see device tree README.
BOARD_BOOTIMAGE_PARTITION_SIZE := 8388608
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2506096640
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12629049344
BOARD_CACHEIMAGE_PARTITION_SIZE := 209715200
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_FLASH_BLOCK_SIZE := 4096

# No recovery image.
# The SM-T805 RECOVERY partition is 10 MiB and a LineageOS 21.0 recovery is ~12.6 MB.
# TWRP 3.7.0_9-0 already occupies that slot and is the install vehicle; shipping a
# recovery would either fail the size assert or overwrite TWRP.
# NOTE: with this set, `mka bacon` aborts by design (non_ab_ota.py:583-585).
TARGET_NO_RECOVERY := true

# Shims
TARGET_LD_SHIM_LIBS += \
    /vendor/bin/gpsd|/vendor/lib/libshim_gpsd.so \
    /vendor/lib/libsec-ril.so|libcutils_shim.so

# Inherit from the proprietary version
-include vendor/samsung/chagalllte/BoardConfigVendor.mk
