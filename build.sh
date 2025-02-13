#!/bin/bash

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "OpenDSA: Reading - Build Script"
echo "=============================="

# Funzione per il check degli errori
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Errore durante $1${NC}"
        exit 1
    fi
}

# Directory di output
OUTPUT_DIR="build/releases"
mkdir -p $OUTPUT_DIR

# Clean build
echo "Pulizia build precedente..."
flutter clean
check_error "pulizia"

# Get dependencies
echo "Installazione dipendenze..."
flutter pub get
check_error "installazione dipendenze"

# Android Build
if [[ "$OSTYPE" == "darwin"* || "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Building Android..."
    flutter build apk --release
    check_error "build Android APK"
    cp build/app/outputs/flutter-apk/app-release.apk $OUTPUT_DIR/OpenDSA-Reading.apk

    flutter build appbundle --release
    check_error "build Android Bundle"
    cp build/app/outputs/bundle/release/app-release.aab $OUTPUT_DIR/OpenDSA-Reading.aab
fi

# iOS Build (solo su macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Building iOS..."
    flutter build ios --release --no-codesign
    check_error "build iOS"
    cd ios
    xcodebuild -workspace Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Release archive -archivePath $PWD/build/Runner.xcarchive
    check_error "archive iOS"
    xcodebuild -exportArchive -archivePath $PWD/build/Runner.xcarchive -exportOptionsPlist exportOptions.plist -exportPath $PWD/build/ios
    check_error "export iOS"
    cd ..
    cp ios/build/ios/OpenDSA-Reading.ipa $OUTPUT_DIR/
fi

# Windows Build
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "Building Windows..."
    flutter build windows --release
    check_error "build Windows"
    flutter pub run msix:create
    check_error "create MSIX"
    cp build/windows/runner/Release/OpenDSA-Reading.msix $OUTPUT_DIR/
fi

# macOS Build
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Building macOS..."
    flutter build macos --release
    check_error "build macOS"
    cd macos
    xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release archive -archivePath $PWD/build/Runner.xcarchive
    check_error "archive macOS"
    cd ..
    cp build/macos/Build/Products/Release/OpenDSA-Reading.app $OUTPUT_DIR/
fi

# Linux Build
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Building Linux..."
    flutter build linux --release
    check_error "build Linux"

    # Create AppImage
    wget -c "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
    chmod +x linuxdeploy-x86_64.AppImage
    ./linuxdeploy-x86_64.AppImage --appdir build/linux/x64/release/bundle -e build/linux/x64/release/bundle/thesis_project -i assets/icon/app_icon.png --output appimage
    check_error "create AppImage"
    cp OpenDSA-Reading*.AppImage $OUTPUT_DIR/
fi

echo -e "${GREEN}Build completata con successo!${NC}"
echo "Gli installer si trovano in: $OUTPUT_DIR"