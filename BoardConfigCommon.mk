#
# Copyright (C) 2023-2026 The LineageOS Project
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

COMMON_PATH := device/samsung/sm8150-common

# A/B
AB_OTA_UPDATER := false

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a76

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a76

# Audio
AUDIOSERVER_MULTILIB := 32
AUDIO_FEATURE_ENABLED_EXTENDED_COMPRESS_FORMAT := true
AUDIO_FEATURE_ENABLED_INSTANCE_ID := true
AUDIO_FEATURE_ENABLED_PROXY_DEVICE := true

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := msmnile
TARGET_NO_BOOTLOADER := true

# Platform
BOARD_USES_QCOM_HARDWARE := true
TARGET_BOARD_PLATFORM := msmnile

# Boot image
# Header v1 with the stock Samsung load offsets from the stock T865XXU6DXJ1 boot.img
# header: base 0x0, kernel 0x8000, ramdisk 0x0, second 0x0, tags 0x1e00000, page 4096
# (verified on device for boot and recovery).
BOARD_BOOT_HEADER_VERSION := 1
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_MKBOOTIMG_ARGS += \
    --header_version $(BOARD_BOOT_HEADER_VERSION) \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x00000000 \
    --second_offset 0x00000000 \
    --tags_offset 0x01e00000

# Stock cmdline plus androidboot.boot_devices for first stage by-name links
# (UFS host node soc/1d84000.ufshc from the stock DT and sepolicy).
BOARD_KERNEL_CMDLINE := \
    console=null \
    androidboot.hardware=qcom \
    androidboot.console=ttyMSM0 \
    androidboot.memcg=1 \
    lpm_levels.sleep_disabled=1 \
    video=vfb:640x400,bpp=32,memsize=3072000 \
    msm_rtb.filter=0x237 \
    service_locator.enable=1 \
    swiotlb=2048 \
    androidboot.usbcontroller=a600000.dwc3 \
    firmware_class.path=/vendor/firmware_mnt/image \
    loop.max_part=7 \
    androidboot.boot_devices=soc/1d84000.ufshc

# Kernel
# The Samsung bootloader needs the stock "Image-dtb" layout:
# "UNCOMPRESSED_IMG" + le32 size + Image + concatenated dtbs (arch/arm64/boot/Makefile).
# BOARD_INCLUDE_DTB_IN_BOOTIMG must stay undefined: the build tests it with ifdef,
# so even an explicit "false" would add a dtb section.
BOARD_KERNEL_IMAGE_NAME := Image-dtb
BOARD_KERNEL_SEPARATED_DTBO := true
TARGET_KERNEL_SOURCE := kernel/samsung/sm8150

# Kernel toolchain: clang r416183b for compiling, GNU ld from the GCC 4.9 prefix for
# linking (CONFIG_MODVERSIONS + ld.lld fails on R_AARCH64_ABS32 against __crc_*).
# The 4.14 Makefile predates LLVM=1, so every tool is passed explicitly. Paths are
# absolute because BUILD_TOP is still empty while the board config is parsed.
TARGET_KERNEL_CLANG_PATH := $(abspath prebuilts/clang/kernel/linux-x86/clang-r416183b)
SAMSUNG_KERNEL_GCC64 := $(abspath prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin)/aarch64-linux-android-
SAMSUNG_KERNEL_GCC32 := $(abspath prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin)/arm-linux-androideabi-
KERNEL_CC := CC=$(TARGET_KERNEL_CLANG_PATH)/bin/clang
KERNEL_CLANG_TRIPLE := CLANG_TRIPLE=aarch64-linux-gnu-
# Device tree overlays: the bootloader applies dtbo.img on top of the appended dtbs,
# which therefore need __symbols__ (stock dtbs have them). The defconfig leaves
# CONFIG_BUILD_ARM64_DT_OVERLAY unset; passing it as a make variable makes
# arch/arm64/Makefile export DTC_FLAGS=-@ without touching .config.
TARGET_KERNEL_ADDITIONAL_FLAGS := \
    HOSTCC=$(TARGET_KERNEL_CLANG_PATH)/bin/clang \
    HOSTCXX=$(TARGET_KERNEL_CLANG_PATH)/bin/clang++ \
    HOSTAR=$(TARGET_KERNEL_CLANG_PATH)/bin/llvm-ar \
    HOSTLD=$(TARGET_KERNEL_CLANG_PATH)/bin/ld.lld \
    CROSS_COMPILE=$(SAMSUNG_KERNEL_GCC64) \
    CROSS_COMPILE_ARM32=$(SAMSUNG_KERNEL_GCC32) \
    CONFIG_BUILD_ARM64_DT_OVERLAY=y

# Filesystem
TARGET_FS_CONFIG_GEN := $(COMMON_PATH)/config.fs

BOARD_ROOT_EXTRA_FOLDERS += \
    carrier \
    dqmdbg \
    efs

# The root file system is read-only, so init cannot create these at boot
BOARD_ROOT_EXTRA_SYMLINKS += \
    /vendor/bt_firmware:/bt_firmware \
    /vendor/dsp:/dsp \
    /vendor/firmware_mnt:/firmware

# File systems: system, system_ext and product are
# ext4 with the LineageOS reserved size, so GApps and addon.d packages can be installed
# from recovery; vendor and odm are EROFS. Set TARGET_RO_FILE_SYSTEM_TYPE := erofs to
# build all logical partitions as EROFS instead (same switch as exynos9820-common).
# The fstab accepts both types for every logical partition.
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
ifneq ($(TARGET_RO_FILE_SYSTEM_TYPE),)
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := $(TARGET_RO_FILE_SYSTEM_TYPE)
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := $(TARGET_RO_FILE_SYSTEM_TYPE)
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := $(TARGET_RO_FILE_SYSTEM_TYPE)
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := $(TARGET_RO_FILE_SYSTEM_TYPE)
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := $(TARGET_RO_FILE_SYSTEM_TYPE)
else
-include vendor/lineage/config/BoardConfigReservedSize.mk
endif
BOARD_EROFS_COMPRESSOR := lz4
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4

TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_VENDOR := vendor

BOARD_USES_METADATA_PARTITION := true
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)

# Dynamic partitions in the stock SYSTEM partition only, like
# exynos9820-common: the metadata device is system, so the build uses it as
# the only super block device and adds androidboot.super_partition=system. A retrofit
# super on a single block device is not supported by the release tools (lpmake writes a
# single file where build_super_image expects split images). The stock VENDOR partition
# is not used. The device BoardConfig sets the size; the group gets "super - 4 MiB".
BOARD_SUPER_PARTITION_METADATA_DEVICE := system
BOARD_SUPER_PARTITION_GROUPS := samsung_dynamic_partitions
BOARD_SAMSUNG_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor odm
# BOARD_SAMSUNG_DYNAMIC_PARTITIONS_SIZE is set in the device BoardConfig.mk

# HIDL / VINTF
DEVICE_MANIFEST_FILE += $(COMMON_PATH)/vintf/manifest.xml
ifneq ($(TARGET_IS_WIFI-ONLY),true)
DEVICE_MANIFEST_FILE += $(COMMON_PATH)/vintf/network_manifest.xml
endif
DEVICE_MATRIX_FILE := hardware/qcom-caf/common/compatibility_matrix.xml
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += \
    hardware/qcom-caf/common/vendor_framework_compatibility_matrix.xml \
    hardware/samsung/vintf/samsung_framework_compatibility_matrix.xml

# Media
TARGET_USES_ION := true

# Properties
TARGET_PRODUCT_PROP += $(COMMON_PATH)/product.prop
TARGET_VENDOR_PROP += $(COMMON_PATH)/vendor.prop

# Recovery
BOARD_HAS_DOWNLOAD_MODE := true
BOARD_INCLUDE_RECOVERY_DTBO := true
TARGET_RECOVERY_FSTAB := $(COMMON_PATH)/init/fstab.qcom
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888

# RIL
ENABLE_VENDOR_RIL_SERVICE := true

# Security patch (stock vendor ro.vendor.build.security_patch, T865XXU6DXE1)
VENDOR_SECURITY_PATCH := 2023-08-01

# SEPolicy
include device/lineage/sepolicy/libion/sepolicy.mk
include device/lineage/sepolicy/libperfmgr/sepolicy.mk
include device/qcom/sepolicy_vndr/SEPolicy.mk
BOARD_VENDOR_SEPOLICY_DIRS += $(COMMON_PATH)/sepolicy/vendor
PRODUCT_PUBLIC_SEPOLICY_DIRS += $(COMMON_PATH)/sepolicy/public
PRODUCT_PRIVATE_SEPOLICY_DIRS += $(COMMON_PATH)/sepolicy/private

# Release tools: the update package also writes dtbo.img
TARGET_RELEASETOOLS_EXTENSIONS := $(COMMON_PATH)

# Verified Boot: vbmeta is flashed with verification and hashtree disabled (flags 3)
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# Wi-Fi
BOARD_WLAN_DEVICE := qcwcn
BOARD_HOSTAPD_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_$(BOARD_WLAN_DEVICE)
BOARD_WPA_SUPPLICANT_PRIVATE_LIB_EVENT := "ON"
WIFI_DRIVER_DEFAULT := qca_cld3
WIFI_DRIVER_STATE_CTRL_PARAM := "/dev/wlan"
WIFI_DRIVER_STATE_OFF := "OFF"
WIFI_DRIVER_STATE_ON := "ON"
WIFI_HIDL_FEATURE_DUAL_INTERFACE := true
WIFI_HIDL_UNIFIED_SUPPLICANT_SERVICE_RC_ENTRY := true
WPA_SUPPLICANT_VERSION := VER_0_8_X

# Include the proprietary files BoardConfig
-include vendor/samsung/sm8150-common/BoardConfigVendor.mk
