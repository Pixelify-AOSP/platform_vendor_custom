#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# SPDX-FileCopyrightText: 2024-2025 ASCP OS Project
# SPDX-License-Identifier: Apache-2.0

import argparse
import hashlib
import json
import os
import re
import sys
import zipfile


def calculate_sha256(file_path):
    hash_sha256 = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            hash_sha256.update(chunk)
    return hash_sha256.hexdigest()


def calculate_md5(file_path):
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


def read_zip_metadata(zip_path):
    metadata = {}
    if os.path.isfile(zip_path):
        try:
            with zipfile.ZipFile(zip_path, "r") as z:
                if "META-INF/com/android/metadata" in z.namelist():
                    content = z.read("META-INF/com/android/metadata").decode("utf-8", errors="ignore")
                    for line in content.splitlines():
                        if "=" in line:
                            k, v = line.split("=", 1)
                            metadata[k.strip()] = v.strip()
        except Exception as e:
            print(f"Warning reading zip metadata: {e}", file=sys.stderr)
    return metadata


def parse_buildprop(buildprop_path):
    props = {}
    if os.path.isfile(buildprop_path):
        with open(buildprop_path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    props[k.strip()] = v.strip()
    return props


def extract_version(file_name, props):
    match = re.search(r"ASCP-v([0-9]+(?:\.[0-9]+)*)", file_name)
    if match:
        return match.group(1)
    if "ro.ascp.version.base" in props:
        return props["ro.ascp.version.base"]
    if "ro.ascp.build.version" in props:
        v = props["ro.ascp.build.version"]
        parts = v.split(".")
        if len(parts) >= 2:
            return f"{parts[0]}.{parts[1]}"
        return v
    return "6.3"


def build_file_entry(zip_path, file_name, target_device, version, props, metadata, is_official):
    size = os.path.getsize(zip_path) if os.path.isfile(zip_path) else 0
    sha256 = calculate_sha256(zip_path) if os.path.isfile(zip_path) else ""

    patch_level = (
        metadata.get("post-security-patch-level")
        or props.get("ro.build.version.security_patch")
        or "2026-09-01"
    )
    sdk_level_str = (
        metadata.get("post-sdk-level")
        or props.get("ro.build.version.sdk")
        or "36"
    )
    try:
        sdk_level = int(sdk_level_str)
    except ValueError:
        sdk_level = 36

    if is_official:
        url = f"https://sourceforge.net/projects/project-ascp/files/{target_device}/{version}/{file_name}/download"
    else:
        url = f"https://sourceforge.net/projects/project-ascp-unofficial/files/{target_device}/{version}/{file_name}/download"

    entry = {
        "filename": file_name,
        "os_patch_level": patch_level,
        "os_sdk_level": sdk_level,
        "sha256": sha256,
        "size": size,
        "url": url,
    }

    if "ota-property-files" in metadata:
        entry["ota_property_files"] = metadata["ota-property-files"]

    return entry


def generate_json(target_device, product_out, file_name, build_variant, incremental_file=None):
    zip_path = os.path.join(product_out, file_name)
    buildprop_path = os.path.join(product_out, "system", "build.prop")
    props = parse_buildprop(buildprop_path)
    metadata = read_zip_metadata(zip_path)

    version = extract_version(file_name, props)
    variant_str = (build_variant or "OFFICIAL").upper()
    is_official = variant_str == "OFFICIAL" or "OFFICIAL" in file_name

    # Determine datetime timestamp
    timestamp = 0
    if "post-timestamp" in metadata:
        try:
            timestamp = int(metadata["post-timestamp"])
        except ValueError:
            pass
    if timestamp == 0 and "ro.system.build.date.utc" in props:
        try:
            timestamp = int(props["ro.system.build.date.utc"])
        except ValueError:
            pass
    if timestamp == 0 and os.path.isfile(zip_path):
        timestamp = int(os.path.getmtime(zip_path))

    # Full OTA file entry
    full_file_entry = build_file_entry(
        zip_path, file_name, target_device, version, props, metadata, is_official
    )

    update_item = {
        "datetime": timestamp,
        "files": [full_file_entry],
        "type": variant_str,
        "version": version,
    }

    # Incremental entry if provided
    if incremental_file:
        inc_zip_path = os.path.join(product_out, incremental_file)
        if os.path.isfile(inc_zip_path):
            inc_metadata = read_zip_metadata(inc_zip_path)
            inc_file_entry = build_file_entry(
                inc_zip_path, incremental_file, target_device, version, props, inc_metadata, is_official
            )
            update_item["incremental"] = [inc_file_entry]

    # Primary output: Array matching official_devices/API/updater/{device}.json
    updater_json_data = [update_item]

    output_path = os.path.join(product_out, f"{target_device}.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(updater_json_data, f, indent=2)
    print(f"Generated Updater feed JSON: {output_path}")

    # If official_devices repo exists in root, automatically sync official_devices/API/updater/{device}.json
    official_updater_dir = os.path.join("official_devices", "API", "updater")
    if os.path.isdir(official_updater_dir):
        official_updater_path = os.path.join(official_updater_dir, f"{target_device}.json")
        with open(official_updater_path, "w", encoding="utf-8") as f:
            json.dump(updater_json_data, f, indent=2)
        print(f"Synced to official_devices: {official_updater_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate a JSON file for Updater feed.")
    parser.add_argument("target_device", help="Target device name")
    parser.add_argument("product_out", help="Product output directory")
    parser.add_argument("file_name", help="File name for full OTA")
    parser.add_argument("build_variant", help="Build variant (OFFICIAL/UNOFFICIAL)")
    parser.add_argument("--incremental", dest="incremental_file", default=None, help="File name for incremental OTA (optional)")

    args = parser.parse_args()
    generate_json(
        args.target_device,
        args.product_out,
        args.file_name,
        args.build_variant,
        args.incremental_file,
    )


if __name__ == "__main__":
    main()
