# SPDX-FileCopyrightText: 2024-2025 ASCP OS Project
# SPDX-License-Identifier: Apache-2.0

# Inherit common mobile ASCP stuff
$(call inherit-product, vendor/custom/config/common.mk)

# Include AOSP audio files
$(call inherit-product-if-exists, frameworks/base/data/sounds/AudioPackage14.mk)
include vendor/custom/config/aosp_audio.mk

# Include ASCP audio files
include vendor/custom/config/ascp_audio.mk

# Default notification/alarm sounds
ifeq ($(WITH_GMS),true)
PRODUCT_PRODUCT_PROPERTIES += \
    ro.config.notification_sound=Kernel.ogg \
    ro.config.alarm_alert=Fresh_morning.ogg
else
PRODUCT_PRODUCT_PROPERTIES += \
    ro.config.notification_sound=Argon.ogg \
    ro.config.alarm_alert=Hassium.ogg
endif

# Apps
PRODUCT_PACKAGES += \
    AvatarPicker \
    LatinIME

ifneq ($(PRODUCT_NO_CAMERA),true)
PRODUCT_PACKAGES += \
    Aperture
endif

ifneq ($(TARGET_EXCLUDES_AUDIOFX),true)
PRODUCT_PACKAGES += \
    AudioFX
endif

ifeq ($(PRODUCT_TYPE), go)
PRODUCT_PACKAGES += \
    Launcher3QuickStepGo

PRODUCT_DEXPREOPT_SPEED_APPS += \
    Launcher3QuickStepGo
else
PRODUCT_PACKAGES += \
    Launcher3QuickStep

PRODUCT_DEXPREOPT_SPEED_APPS += \
    Launcher3QuickStep
endif

PRODUCT_PACKAGES += \
    Launcher3Overlay

# Extra cmdline tools
PRODUCT_PACKAGES += \
    unrar \
    zstd

# Include ASCP LatinIME dictionaries
PRODUCT_PACKAGE_OVERLAYS += vendor/custom/overlay/dictionaries
PRODUCT_ENFORCE_RRO_EXCLUDED_OVERLAYS += vendor/custom/overlay/dictionaries

# Media
PRODUCT_PRODUCT_PROPERTIES += \
    media.recorder.show_manufacturer_and_model=true

# SystemUI plugins
PRODUCT_PACKAGES += \
    QuickAccessWallet

# TextClassifier
PRODUCT_PACKAGES += \
    libtextclassifier_annotator_en_model \
    libtextclassifier_annotator_universal_model \
    libtextclassifier_actions_suggestions_universal_model \
    libtextclassifier_lang_id_model

PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST += \
    system/etc/textclassifier/actions_suggestions.universal.model \
    system/etc/textclassifier/lang_id.model \
    system/etc/textclassifier/textclassifier.en.model \
    system/etc/textclassifier/textclassifier.universal.model

# TFLite service.
PRODUCT_PACKAGES += libtensorflowlite_jni

PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST += \
    system/lib/libtensorflowlite_jni.so \
    system/lib64/libtensorflowlite_jni.so

# Themes
PRODUCT_PACKAGES += \
    LineageBlackTheme \
    ThemePicker \
    ThemesStub
