# SPDX-FileCopyrightText: 2024-2025 ASCP OS Project
# SPDX-License-Identifier: Apache-2.0

ASCP_ANDROID_VERSION := 17
ASCP_BASE_VERSION := 6.0
ASCP_BUILD_DATE := $(shell date -u +%Y%m%d-%H%M)

ASCP_MAINTAINER ?= Unofficial
ASCP_MAINTAINER_LINK ?= https://github.com/ASCP-staging

# Device/brand/region codes for package naming
ASCP_DEVICE_CODE := $(shell echo $(TARGET_PRODUCT) | cut -c1-3 | tr a-z A-Z)
ASCP_BRAND_CODE := AC
ASCP_REGION_CODE := ID

# Verify device against official list
_ASCP_VERIFY := $(shell python3 vendor/custom/tools/ascp_verify.py \
    --devices  official_devices/devices.json \
    --product  $(TARGET_PRODUCT) \
    --maintainer $(ASCP_MAINTAINER) 2>/dev/null)

ASCP_BUILD_TYPE     := $(patsubst ASCP_BUILD_TYPE=%,%,\
    $(filter ASCP_BUILD_TYPE=%,$(_ASCP_VERIFY)))
ASCP_MAINTAINER_LINK := $(patsubst ASCP_MAINTAINER_LINK=%,%,\
    $(filter ASCP_MAINTAINER_LINK=%,$(_ASCP_VERIFY)))

ifeq ($(ASCP_BUILD_TYPE),OFFICIAL)
ASCP_TYPE_CODE := OF
else
ASCP_TYPE_CODE := UN
endif

ifeq ($(ASCP_BUILD_TYPE),OFFICIAL)
PRODUCT_PACKAGES += \
    Updater

PRODUCT_COPY_FILES += \
    vendor/custom/prebuilt/common/etc/init/init.ascp-updater.rc:$(TARGET_COPY_OUT_SYSTEM_EXT)/etc/init/init.ascp-updater.rc
endif

# Version string: ASCP-v6.0-<device>-<type>-<date>
ASCP_VERSION_SUFFIX := $(ASCP_ANDROID_VERSION).$(ASCP_BASE_VERSION).$(ASCP_DEVICE_CODE)$(ASCP_BRAND_CODE)$(ASCP_REGION_CODE)$(ASCP_TYPE_CODE)
ASCP_PACKAGE_VERSION := ASCP-v$(ASCP_BASE_VERSION)-$(TARGET_PRODUCT)-$(ASCP_BUILD_TYPE)-$(ASCP_BUILD_DATE)
ASCP_VERSION := ASCP OS v$(ASCP_BASE_VERSION) | Android $(ASCP_ANDROID_VERSION) | $(ASCP_BUILD_TYPE)

PRODUCT_SYSTEM_PROPERTIES += \
    ro.ascp.build.type=$(ASCP_BUILD_TYPE) \
    ro.ascp.build.version=$(ASCP_VERSION_SUFFIX) \
    ro.ascp.version.base=$(ASCP_BASE_VERSION) \
    ro.ascp.maintainer=$(ASCP_MAINTAINER) \
    ro.ascp.maintainer.link=$(ASCP_MAINTAINER_LINK) \
    ro.ascp.version=$(ASCP_PACKAGE_VERSION) \
    ro.ascp.android.version=$(ASCP_ANDROID_VERSION) \
    ro.ascp.build.date=$(ASCP_BUILD_DATE) \
    ro.ascp.device=$(TARGET_PRODUCT)
