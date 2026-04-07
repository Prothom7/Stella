#!/bin/bash

# This script adds USDZ files to the Xcode project

PBXPROJ="Stella.xcodeproj/project.pbxproj"
BACKUP="${PBXPROJ}.backup"

# Backup original
cp "$PBXPROJ" "$BACKUP"

# Convert to XML for easier editing
plutil -convert xml1 "$PBXPROJ"

# For each USDZ file, add it to the resources section
for file in sun.usdz mars.usdz earth.usdz ISS_stationary.usdz; do
    if ! grep -q "$file" "$PBXPROJ"; then
        echo "Note: $file not yet in pbxproj"
    fi
done

# Convert back to binary
plutil -convert binary1 "$PBXPROJ"

echo "Done processing resources"
