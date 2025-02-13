#!/bin/bash
set -e

# Definizione dei colori per l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "OpenDSA: Reading - Build Script"
echo "=============================="

# Controllo prerequisiti
echo "Controllo prerequisiti..."

if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Flutter non trovato. Assicurati che Flutter sia installato e nel PATH.${NC}"
    exit 1
fi

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if ! command -v wget &> /dev/null; then
        echo -e "${RED}wget non trovato. Installalo con: sudo apt-get install wget${NC}"
        exit 1
    fi
fi

# Pulizia della build precedente
echo "Pulizia build precedente..."
rm -rf build/
flutter clean

# Installazione delle dipendenze
echo "Installazione dipendenze..."
flutter pub get

# Preparazione directory di output
echo "Preparazione directory di output..."
OUTPUT_DIR="build/releases"
mkdir -p "$OUTPUT_DIR"

# Build per Android
echo -e "${YELLOW}Building Android...${NC}"
echo "Building APK..."
flutter build apk --release || {
    echo -e "${RED}Errore durante la build Android APK${NC}"
    exit 1
}
cp build/app/outputs/flutter-apk/app-release.apk "$OUTPUT_DIR/OpenDSA-Reading.apk"

echo "Building App Bundle..."
flutter build appbundle --release || {
    echo -e "${RED}Errore durante la build Android App Bundle${NC}"
    exit 1
}
cp build/app/outputs/bundle/release/app-release.aab "$OUTPUT_DIR/OpenDSA-Reading.aab"
echo -e "${GREEN}Build Android completata${NC}"

# Build per iOS/iPadOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Building iOS/iPadOS...${NC}"

    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}xcodebuild non trovato. Installa Xcode e gli strumenti da riga di comando.${NC}"
    else
        flutter build ios --release --no-codesign || {
            echo -e "${RED}Errore durante la build iOS${NC}"
            exit 1
        }
        mkdir -p "$OUTPUT_DIR/iOS"
        cp -r build/ios/iphoneos/Runner.app "$OUTPUT_DIR/iOS/"
        echo -e "${GREEN}Build iOS completata${NC}"
    fi
else
    echo -e "${YELLOW}Skipping iOS build - richiede macOS${NC}"
fi

# Build per Windows
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo -e "${YELLOW}Building Windows...${NC}"

    flutter build windows --release || {
        echo -e "${RED}Errore durante la build Windows${NC}"
        exit 1
    }

    # Copia l'exe
    mkdir -p "$OUTPUT_DIR/windows"
    cp -r build/windows/runner/Release/* "$OUTPUT_DIR/windows/"

    # Genera MSIX
    flutter pub run msix:create || {
        echo -e "${RED}Errore durante la creazione MSIX${NC}"
        exit 1
    }

    # Copia MSIX
    if [ -f build/windows/runner/Release/*.msix ]; then
        cp build/windows/runner/Release/*.msix "$OUTPUT_DIR/"
    fi

    echo -e "${GREEN}Build Windows completata${NC}"
else
    echo -e "${YELLOW}Skipping Windows build - richiede Windows${NC}"
fi

# Build per macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Building macOS...${NC}"

    flutter build macos --release || {
        echo -e "${RED}Errore durante la build macOS${NC}"
        exit 1
    }

    DMG_DIR="build/macos/Build/Products/Release/"
    hdiutil create -volname "OpenDSA: Reading" \
                  -srcfolder "$DMG_DIR" \
                  -ov -format UDZO \
                  "$OUTPUT_DIR/OpenDSA-Reading.dmg" || {
        echo -e "${RED}Errore durante la creazione DMG${NC}"
        exit 1
    }

    echo -e "${GREEN}Build macOS completata${NC}"
else
    echo -e "${YELLOW}Skipping macOS build - richiede macOS${NC}"
fi

# Build per Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${YELLOW}Building Linux...${NC}"

    flutter build linux --release || {
        echo -e "${RED}Errore durante la build Linux${NC}"
        exit 1
    }

    # Creazione file .desktop
    DESKTOP_DIR="build/linux/x64/release/bundle/usr/share/applications"
    mkdir -p "$DESKTOP_DIR"
    cat > "$DESKTOP_DIR/thesis_project.desktop" << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=OpenDSA: Reading
Comment=OpenDSA: Reading - Dyslexia Helper App
Icon=app_icon
Exec=thesis_project
Terminal=false
Categories=Education;
Keywords=reading;dyslexia;learning;education;
StartupWMClass=thesis_project
EOL

    # Download linuxdeploy
    LINUXDEPLOY="linuxdeploy-x86_64.AppImage"
    if [ ! -f "$LINUXDEPLOY" ]; then
        wget -c "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" -O "$LINUXDEPLOY" || {
            echo -e "${RED}Errore durante il download di linuxdeploy${NC}"
            exit 1
        }
        chmod +x "$LINUXDEPLOY"
    fi

    # Creazione AppImage
    APPIMAGE_TMP="build/linux-appimage"
    mkdir -p "$APPIMAGE_TMP"

    ./$LINUXDEPLOY \
        --appdir="$APPIMAGE_TMP" \
        -e build/linux/x64/release/bundle/thesis_project \
        -i lib/assets/icon/app_icon.png \
        -d "$DESKTOP_DIR/thesis_project.desktop" \
        --output appimage || {
            echo -e "${RED}Errore durante la creazione AppImage${NC}"
            exit 1
        }

    # Trova e sposta l'AppImage generato
    GENERATED_APPIMAGE=$(ls -t OpenDSA*AppImage | head -1)
    if [ -f "$GENERATED_APPIMAGE" ]; then
        mv "$GENERATED_APPIMAGE" "$OUTPUT_DIR/"
        echo -e "${GREEN}AppImage creata con successo${NC}"
    else
        echo -e "${RED}Errore: AppImage non generata${NC}"
        exit 1
    fi

    # Copia la versione non-AppImage
    mkdir -p "$OUTPUT_DIR/linux"
    cp -r build/linux/x64/release/bundle/* "$OUTPUT_DIR/linux/"

    echo -e "${GREEN}Build Linux completata${NC}"
else
    echo -e "${YELLOW}Skipping Linux build - richiede Linux${NC}"
fi

echo -e "\n${GREEN}Build completata con successo!${NC}"
echo "Gli installer si trovano in: $OUTPUT_DIR"

# Lista i file generati
echo -e "\nFile generati:"
ls -la "$OUTPUT_DIR"