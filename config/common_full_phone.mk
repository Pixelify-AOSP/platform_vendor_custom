# SPDX-FileCopyrightText: 2024-2025 ASCP OS Project
# SPDX-License-Identifier: Apache-2.0

# Inherit mobile full common ASCP stuff
$(call inherit-product, vendor/custom/config/common_mobile.mk)

# Enable support of one-handed mode
PRODUCT_PRODUCT_PROPERTIES += \
    ro.support_one_handed_mode?=true

$(call inherit-product, vendor/custom/config/telephony.mk)
