# SPDX-FileCopyrightText: 2024-2025 ASCP OS Project
# SPDX-License-Identifier: Apache-2.0

ASCP_TARGET := $(ASCP_PACKAGE_VERSION)
ASCP_OTA_PACKAGE := $(PRODUCT_OUT)/$(ASCP_TARGET).zip
ASCP_FASTBOOT_PACKAGE := $(PRODUCT_OUT)/$(ASCP_TARGET)-fastboot.zip

SHA256 := prebuilts/build-tools/path/$(HOST_PREBUILT_TAG)/sha256sum

$(ASCP_OTA_PACKAGE): $(INTERNAL_OTA_PACKAGE_TARGET)
	$(hide) ln -f $(INTERNAL_OTA_PACKAGE_TARGET) $(ASCP_OTA_PACKAGE)
	$(hide) $(SHA256) $(ASCP_OTA_PACKAGE) > $(ASCP_OTA_PACKAGE).sha256sum
	$(hide) ./vendor/custom/build/tools/createjson.py $(TARGET_DEVICE) $(PRODUCT_OUT) $(ASCP_TARGET).zip $(TARGET_BUILD_VARIANT)

$(ASCP_FASTBOOT_PACKAGE): $(INTERNAL_UPDATE_PACKAGE_TARGET)
	$(hide) ln -f $(INTERNAL_UPDATE_PACKAGE_TARGET) $(ASCP_FASTBOOT_PACKAGE)

.PHONY: bacon fastboot

bacon: $(ASCP_OTA_PACKAGE)
	@printf "╔══════════════════════════════════════╗\n"
	@printf "║            A S C P   O S              ║\n"
	@printf "║          O T A   B U I L D            ║\n"
	@printf "╚══════════════════════════════════════╝\n"
	@printf "Output  : %s\n" "$(ASCP_OTA_PACKAGE)"
	@printf "SHA256  : %s\n" "$$(awk '{print $$1}' $(ASCP_OTA_PACKAGE).sha256sum)"
	@printf "Size    : %s\n" "$$(du -hs $(ASCP_OTA_PACKAGE) | awk '{print $$1}')"
	@printf "Bytes   : %s\n" "$$(wc -c < $(ASCP_OTA_PACKAGE))"
	@printf "Type    : %s\n" "$(ASCP_BUILD_TYPE)"
	@printf "────────────────────────────────────────\n"

fastboot: $(ASCP_FASTBOOT_PACKAGE)
	@printf "╔══════════════════════════════════════╗\n"
	@printf "║            A S C P   O S              ║\n"
	@printf "║        F A S T B O O T  B U I L D      ║\n"
	@printf "╚══════════════════════════════════════╝\n"
	@printf "Output  : %s\n" "$(ASCP_FASTBOOT_PACKAGE)"
	@printf "Size    : %s\n" "$$(du -hs $(ASCP_FASTBOOT_PACKAGE) | awk '{print $$1}')"
	@printf "Bytes   : %s\n" "$$(wc -c < $(ASCP_FASTBOOT_PACKAGE))"
	@printf "Type    : %s\n" "$(ASCP_BUILD_TYPE)"
	@printf "────────────────────────────────────────\n"
