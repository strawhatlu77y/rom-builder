#!/bin/bash
set -e

echo "=============================================="
echo " LineageOS 23.2 VEUX / PEUX - VANILLA"
echo "=============================================="

# ============================================================
# 1. Clean local manifest and initialize source
# ============================================================

echo "=============================================="
echo " Cleaning local manifests"
echo "=============================================="

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

repo init \
    -u https://github.com/accupara/los23.2.git \
    -b lineage-23.2 \
    --git-lfs \
    --depth=1

echo "LineageOS 23.2 source initialized."

# ============================================================
# 2. VEUX local manifest
# ============================================================

cat > .repo/local_manifests/veux.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>

    <!-- VEUX Device Tree -->
    <project
        name="xiaomi-sm6375-devs/android_device_xiaomi_veux"
        path="device/xiaomi/veux"
        revision="lineage-23.2"
        depth="1" />

    <!-- SM6375 Common Device Tree -->
    <project
        name="xiaomi-sm6375-devs/android_device_xiaomi_sm6375-common"
        path="device/xiaomi/sm6375-common"
        revision="lineage-23.2"
        depth="1" />

    <!-- VEUX/SM6375 Kernel -->
    <project
        name="CaesiumOS/kernel_xiaomi_sm6375"
        path="kernel/xiaomi/sm6375"
        revision="30e3b032c8f27780f6011bc61c4c4b655985c9bb"
        depth="1" />

    <!-- Xiaomi Hardware -->
    <project
        name="xiaomi-sm6375-devs/android_hardware_xiaomi"
        path="hardware/xiaomi"
        revision="lineage-23.2"
        depth="1" />

    <!-- VEUX Proprietary Vendor -->
    <project
        name="Xiaomi-sm6375-developers/vendor_xiaomi_veux"
        path="vendor/xiaomi/veux"
        revision="bka"
        depth="1" />

    <!-- SM6375 Common Proprietary Vendor -->
    <project
        name="crdroidandroid/proprietary_vendor_xiaomi_sm6375-common"
        path="vendor/xiaomi/sm6375-common"
        revision="16.0"
        depth="1" />

</manifest>
EOF

echo "Local manifest created."

# ============================================================
# 3. Crave resync
# ============================================================

echo "=============================================="
echo " Running Crave resync"
echo "=============================================="

/opt/crave/resync.sh

# ============================================================
# 4. Verify required repositories
# ============================================================

echo "=============================================="
echo " Verifying source tree"
echo "=============================================="

for DIR in \
    device/xiaomi/veux \
    device/xiaomi/sm6375-common \
    hardware/xiaomi \
    kernel/xiaomi/sm6375 \
    vendor/xiaomi/veux \
    vendor/xiaomi/sm6375-common
do
    if [ ! -d "$DIR" ]; then
        echo "ERROR: Missing required directory: $DIR"
        exit 1
    fi
done

echo "Required repositories found."

# ============================================================
# 5. Verify required files
# ============================================================

for FILE in \
    device/xiaomi/veux/Android.bp \
    device/xiaomi/veux/AndroidProducts.mk \
    device/xiaomi/veux/BoardConfig.mk \
    device/xiaomi/veux/device.mk \
    device/xiaomi/veux/lineage_veux.mk \
    device/xiaomi/veux/lineage.dependencies \
    device/xiaomi/veux/proprietary-files.txt \
    device/xiaomi/veux/extract-files.py \
    device/xiaomi/sm6375-common/Android.bp \
    device/xiaomi/sm6375-common/BoardConfigCommon.mk \
    device/xiaomi/sm6375-common/common.mk \
    device/xiaomi/sm6375-common/lineage.dependencies \
    device/xiaomi/sm6375-common/proprietary-files.txt \
    device/xiaomi/sm6375-common/extract-files.py \
    kernel/xiaomi/sm6375/arch/arm64/configs/veux_defconfig \
    vendor/xiaomi/veux/veux-vendor.mk \
    vendor/xiaomi/veux/Android.bp \
    vendor/xiaomi/sm6375-common/sm6375-common-vendor.mk \
    vendor/xiaomi/sm6375-common/Android.bp
do
    if [ ! -f "$FILE" ]; then
        echo "ERROR: Missing required file: $FILE"
        exit 1
    fi
done

echo "Required files found."

# ============================================================
# 6. Verify manifest content
# ============================================================

echo "=============================================="
echo " Validating local manifest"
echo "=============================================="

grep -q "xiaomi-sm6375-devs/android_device_xiaomi_veux" .repo/local_manifests/veux.xml
grep -q "xiaomi-sm6375-devs/android_device_xiaomi_sm6375-common" .repo/local_manifests/veux.xml
grep -q "dereference23/kernel_xiaomi_sm6375" .repo/local_manifests/veux.xml
grep -q "xiaomi-sm6375-devs/android_hardware_xiaomi" .repo/local_manifests/veux.xml
grep -q "Xiaomi-sm6375-developers/vendor_xiaomi_veux" .repo/local_manifests/veux.xml
grep -q "crdroidandroid/proprietary_vendor_xiaomi_sm6375-common" .repo/local_manifests/veux.xml

echo "Manifest repositories verified."

# ============================================================
# 7. Verify resolved commits
# ============================================================

echo "=============================================="
echo " Resolved repository commits"
echo "=============================================="

echo "VEUX:"
git -C device/xiaomi/veux rev-parse HEAD

echo
echo "SM6375 COMMON:"
git -C device/xiaomi/sm6375-common rev-parse HEAD

echo
echo "KERNEL:"
git -C kernel/xiaomi/sm6375 rev-parse HEAD

echo
echo "HARDWARE/XIAOMI:"
git -C hardware/xiaomi rev-parse HEAD

echo
echo "VEUX VENDOR:"
git -C vendor/xiaomi/veux rev-parse HEAD

echo
echo "SM6375 COMMON VENDOR:"
git -C vendor/xiaomi/sm6375-common rev-parse HEAD

# ============================================================
# 8. Verify VEUX / common inheritance
# ============================================================

echo "=============================================="
echo " Verifying device inheritance"
echo "=============================================="

grep -q "device/xiaomi/sm6375-common/common.mk" \
    device/xiaomi/veux/device.mk

grep -q "vendor/xiaomi/veux/veux-vendor.mk" \
    device/xiaomi/veux/device.mk

grep -q "vendor/xiaomi/sm6375-common/sm6375-common-vendor.mk" \
    device/xiaomi/sm6375-common/common.mk

echo "Device/common/vendor inheritance verified."

# ============================================================
# 9. Verify proprietary lists
# ============================================================

echo "=============================================="
echo " Verifying proprietary lists"
echo "=============================================="

VEUX_PROP_LINES="$(wc -l < device/xiaomi/veux/proprietary-files.txt)"
COMMON_PROP_LINES="$(wc -l < device/xiaomi/sm6375-common/proprietary-files.txt)"

echo "VEUX proprietary lines   : $VEUX_PROP_LINES"
echo "COMMON proprietary lines : $COMMON_PROP_LINES"

if [ "$VEUX_PROP_LINES" -le 100 ]; then
    echo "ERROR: VEUX proprietary list unexpectedly small."
    exit 1
fi

if [ "$COMMON_PROP_LINES" -le 100 ]; then
    echo "ERROR: COMMON proprietary list unexpectedly small."
    exit 1
fi

grep -q "OS1.0.13.0.TKCEUXM" \
    device/xiaomi/veux/proprietary-files.txt

grep -q "OS2.0.9.0.UMQEUXM" \
    device/xiaomi/sm6375-common/proprietary-files.txt

echo "Proprietary list sources verified."

# ============================================================
# 10. Verify extraction tooling
# ============================================================

echo "=============================================="
echo " Verifying extraction tooling"
echo "=============================================="

python3 --version

python3 -m py_compile \
    device/xiaomi/veux/extract-files.py \
    device/xiaomi/sm6375-common/extract-files.py

echo "Extraction scripts are syntactically valid."

# ============================================================
# 11. Verify kernel
# ============================================================

echo "=============================================="
echo " Checking kernel"
echo "=============================================="

EXPECTED_KERNEL_COMMIT="30e3b032c8f27780f6011bc61c4c4b655985c9bb"
ACTUAL_KERNEL_COMMIT="$(git -C kernel/xiaomi/sm6375 rev-parse HEAD)"

echo "Expected kernel commit:"
echo "$EXPECTED_KERNEL_COMMIT"

echo "Actual kernel commit:"
echo "$ACTUAL_KERNEL_COMMIT"

if [ "$ACTUAL_KERNEL_COMMIT" != "$EXPECTED_KERNEL_COMMIT" ]; then
    echo "ERROR: Kernel commit mismatch."
    exit 1
fi

if [ ! -f kernel/xiaomi/sm6375/arch/arm64/configs/veux_defconfig ]; then
    echo "ERROR: veux_defconfig not found."
    exit 1
fi

grep -q "CONFIG_NFC_PN557=y" \
    kernel/xiaomi/sm6375/arch/arm64/configs/veux_defconfig

grep -q "CONFIG_NFC_QTI_I2C=y" \
    kernel/xiaomi/sm6375/arch/arm64/configs/veux_defconfig

echo "Kernel and veux_defconfig verified."

# ============================================================
# 12. Verify board configuration
# ============================================================

echo "=============================================="
echo " Checking BoardConfig"
echo "=============================================="

grep -q "TARGET_KERNEL_CONFIG := veux_defconfig" \
    device/xiaomi/veux/BoardConfig.mk

grep -q "TARGET_KERNEL_SOURCE := kernel/xiaomi/sm6375" \
    device/xiaomi/sm6375-common/BoardConfigCommon.mk

grep -q "BOARD_KERNEL_IMAGE_NAME := Image" \
    device/xiaomi/sm6375-common/BoardConfigCommon.mk

grep -q "BOARD_BOOT_HEADER_VERSION := 3" \
    device/xiaomi/sm6375-common/BoardConfigCommon.mk

grep -q "BOARD_USES_GENERIC_KERNEL_IMAGE := true" \
    device/xiaomi/sm6375-common/BoardConfigCommon.mk

echo "Board configuration verified."

# ============================================================
# 13. Verify Virtual A/B / Dynamic Partitions / fastbootd
# ============================================================

echo "=============================================="
echo " Checking A/B and partition configuration"
echo "=============================================="

grep -Rqs \
    "PRODUCT_USE_DYNAMIC_PARTITIONS" \
    device/xiaomi/sm6375-common

grep -Rqs \
    "virtual_ab_ota/launch_with_vendor_ramdisk.mk" \
    device/xiaomi/sm6375-common

grep -Rqs \
    "fastbootd" \
    device/xiaomi/sm6375-common device/xiaomi/veux

echo "Dynamic partitions verified."
echo "Virtual A/B verified."
echo "fastbootd configuration verified."

# ============================================================
# 14. Verify BootControl
# ============================================================

echo "=============================================="
echo " Checking QTI BootControl"
echo "=============================================="

grep -Rqs \
    "android.hardware.boot-service.qti" \
    device/xiaomi/sm6375-common device/xiaomi/veux

grep -Rqs \
    "android.hardware.boot-service.qti.recovery" \
    device/xiaomi/sm6375-common device/xiaomi/veux

grep -Rqs \
    "android.hardware.boot-service.qti" \
    hardware/qcom-caf/bootctrl

grep -Rqs \
    "android.hardware.boot-service.qti.recovery" \
    hardware/qcom-caf/bootctrl

echo "QTI BootControl configuration verified."

# ============================================================
# 15. Vanilla build checks
# ============================================================

echo "=============================================="
echo " Checking VANILLA build configuration"
echo "=============================================="

echo "No GApps repository is included."
echo "No MindTheGapps is included."
echo "No NikGapps is included."
echo "No BiTGApps is included."
echo "No OpenGApps is included."
echo "No MIUI Camera addon is included."
echo "No Dolby addon is included."
echo "No ViPER4Android addon is included."

if grep -RniE \
    'MindTheGapps|NikGapps|BiTGApps|OpenGApps|FlameGApps|LiteGapps|vendor/gapps' \
    .repo/local_manifests \
    device/xiaomi/veux \
    device/xiaomi/sm6375-common \
    2>/dev/null; then
    echo "ERROR: GApps reference detected."
    exit 1
fi

if grep -RniE \
    'miuicamera|MiuiCamera|vendor/sony/dolby|ViPER4AndroidFX|RemovePackagesVeux' \
    .repo/local_manifests \
    device/xiaomi/veux \
    device/xiaomi/sm6375-common \
    2>/dev/null; then
    echo "ERROR: Old/custom addon reference detected."
    exit 1
fi

echo "Vanilla dependency checks passed."

# ============================================================
# 16. Verify product makefile
# ============================================================

echo "=============================================="
echo " Checking product definition"
echo "=============================================="

grep -q "PRODUCT_NAME := lineage_veux" \
    device/xiaomi/veux/lineage_veux.mk

grep -q "PRODUCT_DEVICE := veux" \
    device/xiaomi/veux/lineage_veux.mk

grep -q "PRODUCT_BRAND := Redmi" \
    device/xiaomi/veux/lineage_veux.mk

echo "Product definition verified."

# ============================================================
# 17. Build environment
# ============================================================

export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss

# ============================================================
# 18. Start build environment
# ============================================================

echo "=============================================="
echo " Starting build environment"
echo "=============================================="

source build/envsetup.sh

breakfast veux

# ============================================================
# 19. Resolved target variables
# ============================================================

echo "=============================================="
echo " Resolved target variables"
echo "=============================================="

TARGET_PRODUCT_RESOLVED="$(get_build_var TARGET_PRODUCT)"
TARGET_DEVICE_RESOLVED="$(get_build_var TARGET_DEVICE)"
TARGET_ARCH_RESOLVED="$(get_build_var TARGET_ARCH)"
TARGET_KERNEL_SOURCE_RESOLVED="$(get_build_var TARGET_KERNEL_SOURCE)"
TARGET_KERNEL_CONFIG_RESOLVED="$(get_build_var TARGET_KERNEL_CONFIG)"
TARGET_BUILD_VARIANT_RESOLVED="$(get_build_var TARGET_BUILD_VARIANT)"

echo "TARGET_PRODUCT       = $TARGET_PRODUCT_RESOLVED"
echo "TARGET_DEVICE        = $TARGET_DEVICE_RESOLVED"
echo "TARGET_ARCH          = $TARGET_ARCH_RESOLVED"
echo "TARGET_KERNEL_SOURCE = $TARGET_KERNEL_SOURCE_RESOLVED"
echo "TARGET_KERNEL_CONFIG = $TARGET_KERNEL_CONFIG_RESOLVED"
echo "TARGET_BUILD_VARIANT = $TARGET_BUILD_VARIANT_RESOLVED"

[ "$TARGET_PRODUCT_RESOLVED" = "lineage_veux" ]
[ "$TARGET_DEVICE_RESOLVED" = "veux" ]
[ "$TARGET_KERNEL_SOURCE_RESOLVED" = "kernel/xiaomi/sm6375" ]
[ "$TARGET_KERNEL_CONFIG_RESOLVED" = "veux_defconfig" ]

echo "Target configuration verified."

# ============================================================
# 20. Pre-build output directory check
# ============================================================

echo "=============================================="
echo " Preparing output directory"
echo "=============================================="

mkdir -p out/target/product/veux

echo "Output directory ready."

# ============================================================
# 21. Build test / full ROM build
# ============================================================

echo "=============================================="
echo " Starting LineageOS 23.2 VANILLA build"
echo "=============================================="

echo "Build target: mka bacon"

mka bacon

# ============================================================
# 22. Collect output
# ============================================================

echo "=============================================="
echo " Collecting build artifacts"
echo "=============================================="

mkdir -p imgs_output

cp out/target/product/veux/boot.img \
    imgs_output/ 2>/dev/null || true

cp out/target/product/veux/dtbo.img \
    imgs_output/ 2>/dev/null || true

cp out/target/product/veux/recovery.img \
    imgs_output/ 2>/dev/null || true

cp out/target/product/veux/vendor_boot.img \
    imgs_output/ 2>/dev/null || true

cp out/target/product/veux/vbmeta.img \
    imgs_output/ 2>/dev/null || true

cp out/target/product/veux/vbmeta_system.img \
    imgs_output/ 2>/dev/null || true

# ============================================================
# 23. Build output
# ============================================================

echo "=============================================="
echo " BUILD OUTPUT"
echo "=============================================="

find out/target/product/veux \
    -maxdepth 1 \
    -type f \
    -name "lineage-*.zip" \
    -print || true

echo "=============================================="
echo " ZIP FILES"
echo "=============================================="

ls -lh \
    out/target/product/veux/*.zip \
    2>/dev/null || true

echo "=============================================="
echo " IMAGE OUTPUT"
echo "=============================================="

ls -lh \
    imgs_output/ \
    2>/dev/null || true

# ============================================================
# 24. SHA256
# ============================================================

echo "=============================================="
echo " SHA256"
echo "=============================================="

for FILE in \
    out/target/product/veux/*.zip \
    imgs_output/*.img
do
    if [ -f "$FILE" ]; then
        sha256sum "$FILE"
    fi
done

# ============================================================
# DONE
# ============================================================

echo "=============================================="
echo " BUILD FINISHED"
echo "=============================================="
echo " LineageOS 23.2 VEUX / PEUX"
echo " VANILLA - NO GAPPS"
echo "=============================================="
