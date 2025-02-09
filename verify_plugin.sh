#!/bin/bash

PLUGIN_ROOT="$HOME/IdeaProjects/DislexiaApp/local_vosk_flutter"
KOTLIN_PATH="$PLUGIN_ROOT/android/src/main/kotlin/com/example/local_vosk_flutter"
PLUGIN_FILE="$KOTLIN_PATH/LocalVoskFlutterPlugin.kt"

echo "Verifying plugin structure..."

# Check if directories exist
if [ ! -d "$PLUGIN_ROOT" ]; then
    echo "Error: Plugin root directory not found at $PLUGIN_ROOT"
    exit 1
fi

if [ ! -d "$KOTLIN_PATH" ]; then
    echo "Creating Kotlin directory structure..."
    mkdir -p "$KOTLIN_PATH"
fi

# Verify plugin file exists and has correct content
if [ ! -f "$PLUGIN_FILE" ]; then
    echo "Error: Plugin file not found at $PLUGIN_FILE"
    exit 1
fi

# Check package declaration
PACKAGE_DECLARATION=$(head -n 1 "$PLUGIN_FILE")
if [[ "$PACKAGE_DECLARATION" != "package com.example.local_vosk_flutter" ]]; then
    echo "Error: Incorrect package declaration in $PLUGIN_FILE"
    echo "Found: $PACKAGE_DECLARATION"
    echo "Expected: package com.example.local_vosk_flutter"
    exit 1
fi

# Set correct permissions
chmod -R 755 "$PLUGIN_ROOT/android"

echo "Verification complete. Directory structure and permissions are correct."

# Copy plugin file to ensure it's in the right place with the right permissions
cp "$PLUGIN_FILE" "$PLUGIN_FILE.tmp"
mv "$PLUGIN_FILE.tmp" "$PLUGIN_FILE"
chmod 644 "$PLUGIN_FILE"

echo "Plugin file has been verified and permissions have been set correctly."