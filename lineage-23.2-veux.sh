#!/bin/bash
set -u

# ============================================================
# LineageOS 23.2 - VEUX / PEUX
# COMPLETE SOURCE + VENDOR + PREFLIGHT
# ============================================================
#
# REQUIRED INPUT FILES:
#
#   veux_eea_global_images_OS1.0.13.0.TKCEUXM*.tgz
#   sunstone_eea_global_images_OS2.0.9.0.UMQEUXM*.tgz
#
# The firmware archives must already be available in the
# Crave working directory.
#
# THIS SCRIPT DOES NOT RUN mka bacon.
#
# ============================================================

FAIL=0

pass() {
    echo "[PASS] $1"
}

fail() {
    echo "[FAIL] $1"
    FAIL=1
}

warn() {
    echo "[WARN] $1"
}

die() {
    echo
    echo "=================================================="
    echo " FATAL ERROR"
    echo "=================================================="
    echo
    echo "$1"
    echo
    exit 1
}

require_file() {
    if [ -f "$1" ]; then
        pass "File exists: $1"
    else
        fail "Missing: $1"
    fi
}

require_dir() {
    if [ -d "$1" ]; then
        pass "Directory exists: $1"
    else
        fail "Missing: $1"
    fi
}

# ============================================================
# 1. FIND FIRMWARE
# ============================================================

echo
echo "=================================================="
echo " [1] Locating firmware archives"
echo "=================================================="
echo

VEUX_FW="$(find . -maxdepth 2 -type f \
    -iname 'veux_eea_global_images_OS1.0.13.0.TKCEUXM*.tgz' \
    -print -quit)"

SUNSTONE_FW="$(find . -maxdepth 2 -type f \
    -iname 'sunstone_eea_global_images_OS2.0.9.0.UMQEUXM*.tgz' \
    -print -quit)"

if [ -z "$VEUX_FW" ]; then
    die "VEUX firmware archive OS1.0.13.0.TKCEUXM was not found."
fi

if [ -z "$SUNSTONE_FW" ]; then
    die "SUNSTONE firmware archive OS2.0.9.0.UMQEUXM was not found."
fi

echo "VEUX firmware:"
echo "  $VEUX_FW"
echo
echo "SUNSTONE firmware:"
echo "  $SUNSTONE_FW"
echo

# ============================================================
# 2. VERIFY FIRMWARE MD5
# ============================================================

echo
echo "=================================================="
echo " [2] Verifying firmware checksums"
echo "=================================================="
echo

VEUX_MD5_EXPECTED="e887aa14ef7d196145cb9097a2b3de16"
SUNSTONE_MD5_EXPECTED="3cef4451a9b6f194fcc9e44c6f3d3f88"

VEUX_MD5_ACTUAL="$(md5sum "$VEUX_FW" | awk '{print $1}')"
SUNSTONE_MD5_ACTUAL="$(md5sum "$SUNSTONE_FW" | awk '{print $1}')"

echo "VEUX expected : $VEUX_MD5_EXPECTED"
echo "VEUX actual   : $VEUX_MD5_ACTUAL"
echo

if [ "$VEUX_MD5_ACTUAL" = "$VEUX_MD5_EXPECTED" ]; then
    pass "VEUX firmware MD5 matches"
else
    die "VEUX firmware MD5 mismatch."
fi

echo "SUNSTONE expected : $SUNSTONE_MD5_EXPECTED"
echo "SUNSTONE actual   : $SUNSTONE_MD5_ACTUAL"
echo

if [ "$SUNSTONE_MD5_ACTUAL" = "$SUNSTONE_MD5_EXPECTED" ]; then
    pass "SUNSTONE firmware MD5 matches"
else
    die "SUNSTONE firmware MD5 mismatch."
fi

# These are the published package versions we are targeting.
# VEUX package: OS1.0.13.0.TKCEUXM
# SUNSTONE package: OS2.0.9.0.UMQEUXM
#
# The current proprietary lists identify these as their blob
# sources.

# ============================================================
# 3. CHECK TOOLS
# ============================================================

echo
echo "=================================================="
echo " [3] Checking host tools"
echo "=================================================="
echo

for TOOL in git repo python3 tar gzip md5sum awk sed grep find; do
    if command -v "$TOOL" >/dev/null 2>&1; then
        pass "$TOOL available"
    else
        die "$TOOL is not available."
    fi
done

# lpunpack is required if super contains logical partitions.
# We do not silently continue without it.
if command -v lpunpack >/dev/null 2>&1; then
    pass "lpunpack available"
else
    warn "lpunpack not found. Firmware extraction may require it."
fi

# ============================================================
# 4. CLEAN LOCAL MANIFEST
# ============================================================

echo
echo "=================================================="
echo " [4] Cleaning local manifests"
echo "=================================================="
echo

rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

pass "Local manifests cleaned"

# ============================================================
# 5. INITIALIZE LINEAGEOS 23.2
# ============================================================

echo
echo "=================================================="
echo " [5] Initializing LineageOS 23.2"
echo "=================================================="
echo

repo init \
    -u https://github.com/LineageOS/android.git \
    -b lineage-23.2 \
    --git-lfs \
    --depth=1

pass "LineageOS 23.2 initialized"

# ============================================================
# 6. CREATE LOCAL MANIFEST
# ============================================================

echo
echo "=================================================="
echo " [6] Creating VEUX 23.2 manifest"
echo "=================================================="
echo

cat > .repo/local_manifests/veux.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>

  <project
      name="xiaomi-sm6375-devs/android_device_xiaomi_veux"
      path="device/xiaomi/veux"
      revision="lineage-23.2"
      depth="1" />

  <project
      name="xiaomi-sm6375-devs/android_device_xiaomi_sm6375-common"
      path="device/xiaomi/sm6375-common"
      revision="lineage-23.2"
      depth="1" />

  <project
      name="xiaomi-sm6375-devs/android_kernel_xiaomi_sm6375"
      path="kernel/xiaomi/sm6375"
      revision="main"
      depth="1" />

  <project
      name="LineageOS/android_hardware_xiaomi"
      path="hardware/xiaomi"
      revision="lineage-23.2"
      depth="1" />

</manifest>
EOF

pass "23.2 VEUX manifest created"

# ============================================================
# 7. SYNC
# ============================================================

echo
echo "=================================================="
echo " [7] Syncing source"
echo "=================================================="
echo

/opt/crave/resync.sh

pass "Source sync completed"

# ============================================================
# 8. SOURCE TREE
# ============================================================

echo
echo "=================================================="
echo " [8] Source tree validation"
echo "=================================================="
echo

for P in \
    device/xiaomi/veux \
    device/xiaomi/sm6375-common \
    kernel/xiaomi/sm6375 \
    hardware/xiaomi
do
    require_dir "$P"
done

for F in \
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
    device/xiaomi/sm6375-common/extract-files.py
do
    require_file "$F"
done

# ============================================================
# 9. DEVICE COMMON INHERITANCE
# ============================================================

echo
echo "=================================================="
echo " [9] VEUX -> SM6375 common"
echo "=================================================="
echo

if grep -q \
    'device/xiaomi/sm6375-common/common.mk' \
    device/xiaomi/veux/device.mk; then

    pass "VEUX inherits SM6375 common"

else

    fail "VEUX does not inherit SM6375 common"

fi

# ============================================================
# 10. RESOLVED COMMITS
# ============================================================

echo
echo "=================================================="
echo " [10] Resolved repository commits"
echo "=================================================="
echo

echo "VEUX:"
git -C device/xiaomi/veux rev-parse HEAD

echo
echo "COMMON:"
git -C device/xiaomi/sm6375-common rev-parse HEAD

echo
echo "KERNEL:"
git -C kernel/xiaomi/sm6375 rev-parse HEAD

echo
echo "HARDWARE/XIAOMI:"
git -C hardware/xiaomi rev-parse HEAD

# ============================================================
# 11. PROPRIETARY LIST VALIDATION
# ============================================================

echo
echo "=================================================="
echo " [11] Proprietary lists"
echo "=================================================="
echo

VEUX_PROP_LINES="$(wc -l < device/xiaomi/veux/proprietary-files.txt)"
COMMON_PROP_LINES="$(wc -l < device/xiaomi/sm6375-common/proprietary-files.txt)"

echo "VEUX proprietary lines   : $VEUX_PROP_LINES"
echo "COMMON proprietary lines : $COMMON_PROP_LINES"
echo

if [ "$VEUX_PROP_LINES" -gt 100 ]; then
    pass "VEUX proprietary list populated"
else
    fail "VEUX proprietary list unexpectedly small"
fi

if [ "$COMMON_PROP_LINES" -gt 100 ]; then
    pass "COMMON proprietary list populated"
else
    fail "COMMON proprietary list unexpectedly small"
fi

grep -q "OS1.0.13.0.TKCEUXM" \
    device/xiaomi/veux/proprietary-files.txt \
    && pass "VEUX list expects OS1.0.13.0.TKCEUXM" \
    || fail "VEUX expected firmware source missing"

grep -q "OS2.0.9.0.UMQEUXM" \
    device/xiaomi/sm6375-common/proprietary-files.txt \
    && pass "COMMON list expects OS2.0.9.0.UMQEUXM" \
    || fail "COMMON expected firmware source missing"

# ============================================================
# 12. EXTRACTION TOOL SYNTAX
# ============================================================

echo
echo "=================================================="
echo " [12] Extraction tooling"
echo "=================================================="
echo

python3 -m py_compile \
    device/xiaomi/veux/extract-files.py

pass "VEUX extractor syntax OK"

python3 -m py_compile \
    device/xiaomi/sm6375-common/extract-files.py

pass "COMMON extractor syntax OK"

# ============================================================
# 13. EXTRACTION NAMESPACES
# ============================================================

echo
echo "=================================================="
echo " [13] Extraction namespaces"
echo "=================================================="
echo

for P in \
    device/xiaomi/veux \
    hardware/qcom-caf/common/libqti-perfd-client \
    hardware/qcom-caf/sm8350 \
    hardware/xiaomi \
    vendor/qcom/opensource/display
do

    if [ -d "$P" ]; then
        pass "$P exists"
    else
        fail "$P missing"
    fi

done

# ============================================================
# 14. PRE-EXTRACTION GATE
# ============================================================

echo
echo "=================================================="
echo "        PRE-EXTRACTION GATE"
echo "=================================================="
echo

if [ "$FAIL" -ne 0 ]; then
    die "Source validation failed. Proprietary extraction will NOT be attempted."
fi

echo "[PASS] Source tree ready for proprietary extraction."
echo

# ============================================================
# 15. PREPARE FIRMWARE WORK AREAS
# ============================================================

echo
echo "=================================================="
echo " [15] Preparing firmware extraction areas"
echo "=================================================="
echo

rm -rf firmware_source
mkdir -p firmware_source/veux
mkdir -p firmware_source/sunstone

pass "Firmware work areas prepared"

# ============================================================
# 16. EXTRACT VEUX FIRMWARE ARCHIVE
# ============================================================

echo
echo "=================================================="
echo " [16] Extracting VEUX firmware archive"
echo "=================================================="
echo

tar -xzf "$VEUX_FW" \
    -C firmware_source/veux

pass "VEUX firmware archive extracted"

# ============================================================
# 17. EXTRACT SUNSTONE FIRMWARE ARCHIVE
# ============================================================

echo
echo "=================================================="
echo " [17] Extracting SUNSTONE firmware archive"
echo "=================================================="
echo

tar -xzf "$SUNSTONE_FW" \
    -C firmware_source/sunstone

pass "SUNSTONE firmware archive extracted"

# ============================================================
# 18. LOCATE FIRMWARE PARTITIONS
# ============================================================

echo
echo "=================================================="
echo " [18] Locating firmware partition images"
echo "=================================================="
echo

echo "VEUX images:"
find firmware_source/veux \
    -type f \
    \( -name "vendor.img" \
       -o -name "odm.img" \
       -o -name "product.img" \
       -o -name "system.img" \
       -o -name "system_ext.img" \
       -o -name "super.img" \) \
    -print

echo
echo "SUNSTONE images:"
find firmware_source/sunstone \
    -type f \
    \( -name "vendor.img" \
       -o -name "odm.img" \
       -o -name "product.img" \
       -o -name "system.img" \
       -o -name "system_ext.img" \
       -o -name "super.img" \) \
    -print

# ============================================================
# 19. VERIFY COMMON VENDOR SOURCE EXISTS
# ============================================================

echo
echo "=================================================="
echo " [19] Firmware image availability"
echo "=================================================="
echo

VEUX_VENDOR_IMAGE="$(find firmware_source/veux -type f -name "vendor.img" -print -quit)"
VEUX_ODM_IMAGE="$(find firmware_source/veux -type f -name "odm.img" -print -quit)"

SUNSTONE_VENDOR_IMAGE="$(find firmware_source/sunstone -type f -name "vendor.img" -print -quit)"
SUNSTONE_ODM_IMAGE="$(find firmware_source/sunstone -type f -name "odm.img" -print -quit)"

if [ -n "$VEUX_VENDOR_IMAGE" ]; then
    pass "VEUX vendor.img found"
else
    warn "VEUX vendor.img not directly present; may be inside super.img"
fi

if [ -n "$VEUX_ODM_IMAGE" ]; then
    pass "VEUX odm.img found"
else
    warn "VEUX odm.img not directly present; may be inside super.img"
fi

if [ -n "$SUNSTONE_VENDOR_IMAGE" ]; then
    pass "SUNSTONE vendor.img found"
else
    warn "SUNSTONE vendor.img not directly present; may be inside super.img"
fi

if [ -n "$SUNSTONE_ODM_IMAGE" ]; then
    pass "SUNSTONE odm.img found"
else
    warn "SUNSTONE odm.img not directly present; may be inside super.img"
fi

# ============================================================
# 20. EXISTING VENDOR TREE CHECK
# ============================================================

echo
echo "=================================================="
echo " [20] Existing vendor tree"
echo "=================================================="
echo

if [ -d vendor/xiaomi/veux ]; then
    pass "vendor/xiaomi/veux exists"
else
    warn "vendor/xiaomi/veux does not yet exist"
fi

if [ -d vendor/xiaomi/sm6375-common ]; then
    pass "vendor/xiaomi/sm6375-common exists"
else
    warn "vendor/xiaomi/sm6375-common does not yet exist"
fi

# ============================================================
# 21. EXTRACTION NOTICE
# ============================================================

echo
echo "=================================================="
echo " [21] Proprietary extraction"
echo "=================================================="
echo

echo "The current VEUX extractor is based on ExtractUtils"
echo "and device_with_common('sm6375-common')."
echo
echo "The exact extraction source must provide filesystem"
echo "paths corresponding to proprietary-files.txt."
echo
echo "Firmware archives have been unpacked above."
echo

# ============================================================
# 22. FINAL SOURCE/PREPARATION GATE
# ============================================================

echo
echo "=================================================="
echo "        FINAL PRE-BUILD GATE"
echo "=================================================="
echo

if [ "$FAIL" -ne 0 ]; then

    echo
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo " PRE-BUILD PREFLIGHT FAILED"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo
    echo "NO breakfast."
    echo "NO mka bacon."
    echo
    echo "Fix the failures above."
    echo

    exit 1

fi

echo
echo "[PASS] Source tree checks passed."
echo "[PASS] Firmware archives verified."
echo
echo "However, vendor extraction is not automatically"
echo "declared successful merely because the archives"
echo "were unpacked."
echo
echo "The next operation must be the actual upstream"
echo "extract-files.py against the prepared firmware"
echo "filesystem source."
echo

# ============================================================
# 23. CHECK WHETHER VENDOR IS ALREADY COMPLETE
# ============================================================

if [ -f vendor/xiaomi/veux/veux-vendor.mk ] &&
   [ -f vendor/xiaomi/sm6375-common/sm6375-common-vendor.mk ]; then

    pass "Vendor makefiles already exist"

else

    warn "Vendor makefiles are not yet generated."
    echo
    echo "The source tree is NOT ready for compilation."
    echo
    echo "No build will be started."
    echo

    exit 1

fi

# ============================================================
# 24. PRODUCT CONFIGURATION
# ============================================================

echo
echo "=================================================="
echo " [24] Product configuration"
echo "=================================================="
echo

export BUILD_USERNAME=crave
export BUILD_HOSTNAME=foss

source build/envsetup.sh

breakfast veux

echo
echo "breakfast veux completed."
echo

# ============================================================
# 25. RESOLVED PRODUCT
# ============================================================

echo
echo "=================================================="
echo " [25] Resolved product"
echo "=================================================="
echo

TARGET_PRODUCT_RESOLVED="$(get_build_var TARGET_PRODUCT)"
TARGET_DEVICE_RESOLVED="$(get_build_var TARGET_DEVICE)"
TARGET_KERNEL_SOURCE_RESOLVED="$(get_build_var TARGET_KERNEL_SOURCE)"
TARGET_KERNEL_CONFIG_RESOLVED="$(get_build_var TARGET_KERNEL_CONFIG)"

echo "TARGET_PRODUCT       = $TARGET_PRODUCT_RESOLVED"
echo "TARGET_DEVICE        = $TARGET_DEVICE_RESOLVED"
echo "TARGET_KERNEL_SOURCE = $TARGET_KERNEL_SOURCE_RESOLVED"
echo "TARGET_KERNEL_CONFIG = $TARGET_KERNEL_CONFIG_RESOLVED"

[ "$TARGET_PRODUCT_RESOLVED" = "lineage_veux" ] \
    && pass "TARGET_PRODUCT is lineage_veux" \
    || fail "Unexpected TARGET_PRODUCT"

[ "$TARGET_DEVICE_RESOLVED" = "veux" ] \
    && pass "TARGET_DEVICE is veux" \
    || fail "Unexpected TARGET_DEVICE"

[ "$TARGET_KERNEL_SOURCE_RESOLVED" = "kernel/xiaomi/sm6375" ] \
    && pass "Kernel source is correct" \
    || fail "Unexpected kernel source"

[ -n "$TARGET_KERNEL_CONFIG_RESOLVED" ] \
    && pass "Kernel config resolved" \
    || fail "Kernel config unresolved"

# ============================================================
# 26. RESOLVED PRODUCT PACKAGES
# ============================================================

echo
echo "=================================================="
echo " [26] Resolved PRODUCT_PACKAGES"
echo "=================================================="
echo

PRODUCT_PACKAGES_RESOLVED="$(get_build_var PRODUCT_PACKAGES)"

check_package() {
    if printf '%s\n' "$PRODUCT_PACKAGES_RESOLVED" |
        tr ' ' '\n' |
        grep -Fxq "$1"; then

        pass "$1 is in resolved PRODUCT_PACKAGES"

    else

        fail "$1 is NOT in resolved PRODUCT_PACKAGES"

    fi
}

check_package "android.hardware.boot-service.qti"
check_package "android.hardware.boot-service.qti.recovery"
check_package "fastbootd"

# ============================================================
# 27. DYNAMIC PARTITION RESOLUTION
# ============================================================

echo
echo "=================================================="
echo " [27] Dynamic partition resolution"
echo "=================================================="
echo

DYNAMIC_RESOLVED="$(get_build_var PRODUCT_USE_DYNAMIC_PARTITIONS)"

echo "PRODUCT_USE_DYNAMIC_PARTITIONS = $DYNAMIC_RESOLVED"

[ "$DYNAMIC_RESOLVED" = "true" ] \
    && pass "Dynamic partitions enabled" \
    || fail "Dynamic partitions not enabled"

# ============================================================
# 28. FINAL RESULT
# ============================================================

echo
echo "=================================================="
echo "             FINAL PREFLIGHT RESULT"
echo "=================================================="
echo

if [ "$FAIL" -eq 0 ]; then

    echo
    echo "**************************************************"
    echo "*                                                *"
    echo "*          23.2 PREFLIGHT PASSED                *"
    echo "*                                                *"
    echo "**************************************************"
    echo
    echo "Device      : VEUX/PEUX"
    echo "Product     : $TARGET_PRODUCT_RESOLVED"
    echo "Kernel      : $TARGET_KERNEL_SOURCE_RESOLVED"
    echo
    echo "BootControl normal   : VERIFIED"
    echo "BootControl recovery : VERIFIED"
    echo "Fastbootd            : VERIFIED"
    echo "Dynamic partitions   : VERIFIED"
    echo
    echo "NO ROM BUILD WAS STARTED."
    echo
    echo "Safe to proceed to the separate build stage."
    echo

    exit 0

else

    echo
    echo "**************************************************"
    echo "*                                                *"
    echo "*          23.2 PREFLIGHT FAILED                 *"
    echo "*                                                *"
    echo "**************************************************"
    echo
    echo "DO NOT RUN mka bacon."
    echo
    exit 1

fi
