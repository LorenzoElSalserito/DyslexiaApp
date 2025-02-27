#!/bin/bash

# Impostazione strict mode
set -euo pipefail

# Colori per l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurazione app
APP_NAME="OpenDSA-Reading"
APP_VERSION="1.0.0"
OUTPUT_DIR="build/releases"

# Logo
echo -e "${GREEN}OpenDSA: Reading - Build Script${NC}"
echo "=============================="

# Funzione per verificare i prerequisiti
check_prerequisites() {
    echo -e "${YELLOW}Controllo prerequisiti...${NC}"

    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}Flutter non trovato. Assicurati che Flutter sia installato e nel PATH.${NC}"
        exit 1
    fi

    local FLUTTER_VERSION
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    echo "Flutter version: $FLUTTER_VERSION"

    # Abilita piattaforme desktop
    case "$OSTYPE" in
        darwin*)
            flutter config --enable-macos-desktop
            ;;
        linux*)
            flutter config --enable-linux-desktop
            ;;
        msys*|win32)
            flutter config --enable-windows-desktop
            ;;
    esac
}

# Funzione per pulire e preparare l'ambiente
prepare_environment() {
    echo -e "${YELLOW}Preparazione ambiente...${NC}"
    flutter clean
    flutter pub get

    # Crea directory di output
    mkdir -p build
    mkdir -p "$OUTPUT_DIR"
}

# Funzione per verificare e correggere le icone
verify_and_fix_icons() {
    echo -e "${YELLOW}Verifica e correzione icone...${NC}"

    # Verifica esistenza della directory assets/icon
    if [ ! -d "assets/icon" ]; then
        echo -e "${BLUE}Creazione directory assets/icon...${NC}"
        mkdir -p assets/icon
    fi

    # Verifica esistenza del file icon/app_icon.png
    if [ ! -f "assets/icon/app_icon.png" ]; then
        echo -e "${YELLOW}Icona non trovata in assets/icon/app_icon.png${NC}"

        # Controlla se esiste in lib/assets/icon
        if [ -f "lib/assets/icon/app_icon.png" ]; then
            echo -e "${BLUE}Copiando icona da lib/assets/icon/app_icon.png a assets/icon/app_icon.png${NC}"
            cp lib/assets/icon/app_icon.png assets/icon/app_icon.png
        else
            echo -e "${RED}Attenzione: Icona app_icon.png non trovata! Crea o copia un'icona in assets/icon/app_icon.png${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}Icona trovata in assets/icon/app_icon.png${NC}"
    fi

    # Verifica che l'icona sia elencata in pubspec.yaml
    if ! grep -q "- assets/icon/app_icon.png" pubspec.yaml; then
        echo -e "${YELLOW}Aggiornamento pubspec.yaml per includere l'icona${NC}"
        # Questa è una soluzione semplificata - in un caso reale potrebbe essere necessario
        # un approccio più sofisticato per modificare il pubspec.yaml
        sed -i '/assets:/a \ \ \ \ - assets/icon/app_icon.png' pubspec.yaml ||
            echo -e "${RED}Impossibile aggiornare pubspec.yaml. Verificare manualmente che l'icona sia inclusa.${NC}"
    fi

    # Genera le icone utilizzando flutter_launcher_icons
    echo -e "${BLUE}Generazione icone con flutter_launcher_icons...${NC}"
    flutter pub run flutter_launcher_icons

    # Verifica che le icone siano state generate per Android
    if [ -f "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" ]; then
        echo -e "${GREEN}Icone Android generate con successo${NC}"
    else
        echo -e "${RED}Attenzione: Icone Android non generate correttamente${NC}"
    fi
}

# Build per Android
build_android() {
    echo -e "${YELLOW}Building Android...${NC}"

    echo "Building APK..."
    if flutter build apk --release; then
        cp "build/app/outputs/flutter-apk/app-release.apk" "$OUTPUT_DIR/$APP_NAME-$APP_VERSION.apk"
    else
        echo -e "${RED}Errore nella build APK${NC}"
        return 1
    fi

    echo "Building App Bundle..."
    if flutter build appbundle --release; then
        cp "build/app/outputs/bundle/release/app-release.aab" "$OUTPUT_DIR/$APP_NAME-$APP_VERSION.aab"
    else
        echo -e "${RED}Errore nella build App Bundle${NC}"
        return 1
    fi

    echo -e "${GREEN}Build Android completata${NC}"
}

# Build per iOS
build_ios() {

  # Verifica versione Xcode
  if [[ "$OSTYPE" == "darwin"* ]]; then
    XCODE_VERSION=$(xcodebuild -version | grep "Xcode" | cut -d' ' -f2)
    echo "Xcode version: $XCODE_VERSION"
    if [[ -z "$XCODE_VERSION" ]]; then
      echo -e "${RED}Xcode non trovato. Necessario per macOS/iOS build.${NC}"
    fi
  fi

    # Verifica se siamo su macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${YELLOW}Skipping iOS build - richiede macOS${NC}"
        return 0
    fi

    echo -e "${YELLOW}Building iOS...${NC}"

    # Verifica prerequisiti iOS
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}xcodebuild non trovato. Installa Xcode.${NC}"
        return 1
    fi

    if ! command -v pod &> /dev/null; then
        echo -e "${RED}CocoaPods non trovato. Installalo con: sudo gem install cocoapods${NC}"
        return 1
    fi

    # Setup CocoaPods
    (cd ios && pod install) || {
        echo -e "${RED}Errore nell'installazione dei pods${NC}"
        return 1
    }

    # Build iOS
    if flutter build ios --release --no-codesign; then
        mkdir -p "$OUTPUT_DIR/ios"
        cp -r "build/ios/iphoneos/Runner.app" "$OUTPUT_DIR/ios/"
        echo -e "${GREEN}Build iOS completata${NC}"
    else
        echo -e "${RED}Errore nella build iOS${NC}"
        return 1
    fi
}

# Build per macOS
build_macos() {

  # Verifica versione Xcode
  if [[ "$OSTYPE" == "darwin"* ]]; then
    XCODE_VERSION=$(xcodebuild -version | grep "Xcode" | cut -d' ' -f2)
    echo "Xcode version: $XCODE_VERSION"
    if [[ -z "$XCODE_VERSION" ]]; then
      echo -e "${RED}Xcode non trovato. Necessario per macOS/iOS build.${NC}"
    fi
  fi

    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${YELLOW}Skipping macOS build - richiede macOS${NC}"
        return 0
    fi

    echo -e "${YELLOW}Building macOS...${NC}"

    if flutter build macos --release; then
        # Crea DMG
        mkdir -p "build/macos/dmg"
        cp -r "build/macos/Build/Products/Release/$APP_NAME.app" "build/macos/dmg/"

        hdiutil create -volname "$APP_NAME" \
                -srcfolder "build/macos/dmg" \
                -ov -format UDZO \
                "$OUTPUT_DIR/$APP_NAME-$APP_VERSION.dmg"

        echo -e "${GREEN}Build macOS completata${NC}"
    else
        echo -e "${RED}Errore nella build macOS${NC}"
        return 1
    fi
}

# Build per Linux
build_linux() {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        echo -e "${YELLOW}Skipping Linux build - richiede Linux${NC}"
        return 0
    fi

    echo -e "${YELLOW}Building Linux...${NC}"

    # Build Linux
    if flutter build linux --release; then
        # Prepara AppImage
        local APPDIR="build/appdir"
        mkdir -p "$APPDIR/usr/bin"
        mkdir -p "$APPDIR/usr/share/applications"
        mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

        # Copia file necessari
        cp -r "build/linux/x64/release/bundle/"* "$APPDIR/usr/bin/"
        cp "assets/icon/app_icon.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png"

        # Crea desktop entry
        cat > "$APPDIR/$APP_NAME.desktop" << EOL
[Desktop Entry]
Name=OpenDSA: Reading
Exec=thesis_project
Icon=$APP_NAME
Type=Application
Categories=Education;
EOL

        # Copia il .desktop nella directory standard
        cp "$APPDIR/$APP_NAME.desktop" "$APPDIR/usr/share/applications/"

        # Copia l'icona nella root della AppDir come richiesto da alcuni strumenti
        cp "assets/icon/app_icon.png" "$APPDIR/$APP_NAME.png"

        # Verifica se appimagetool è già presente
        if [ ! -f "appimagetool-x86_64.AppImage" ]; then
            # Scarica e usa appimagetool
            echo -e "${BLUE}Scaricamento appimagetool...${NC}"
            wget -c "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
            chmod +x appimagetool-x86_64.AppImage
        fi

        echo -e "${BLUE}Creazione AppImage...${NC}"
        ARCH=x86_64 ./appimagetool-x86_64.AppImage "$APPDIR" "$OUTPUT_DIR/$APP_NAME-$APP_VERSION-x86_64.AppImage"

        echo -e "${GREEN}Build Linux completata${NC}"
    else
        echo -e "${RED}Errore nella build Linux${NC}"
        return 1
    fi
}

# Build per Windows
build_windows() {
    if [[ "$OSTYPE" != "msys" && "$OSTYPE" != "win32" ]]; then
        echo -e "${YELLOW}Skipping Windows build - richiede Windows${NC}"
        return 0
    fi

    echo -e "${YELLOW}Building Windows...${NC}"

    if flutter build windows --release; then
        mkdir -p "$OUTPUT_DIR/windows"
        cp -r "build/windows/runner/Release/"* "$OUTPUT_DIR/windows/"

        # Crea MSIX
        if flutter pub run msix:create; then
            find "build/windows/runner/Release" -name "*.msix" -exec cp {} "$OUTPUT_DIR/" \;
        else
            echo -e "${YELLOW}Attenzione: Creazione MSIX fallita${NC}"
        fi

        echo -e "${GREEN}Build Windows completata${NC}"
    else
        echo -e "${RED}Errore nella build Windows${NC}"
        return 1
    fi
}

check_installation() {
  if ! command -v "$1" &> /dev/null; then
    echo -e "${RED}$1 non trovato. Installare per continuare.${NC}"
    return 1
  fi
  echo "$1 trovato: $(command -v "$1")"
  return 0
}

# Funzione principale
main() {
    check_prerequisites
    prepare_environment
    verify_and_fix_icons

    build_android
    build_ios
    build_macos
    build_linux
    build_windows

    check_installation

    echo -e "\n${GREEN}Build completata con successo!${NC}"
    echo "Gli installer si trovano in: $OUTPUT_DIR"

    echo -e "\nFile generati:"
    ls -la "$OUTPUT_DIR"
}

# Esegui lo script
main
echo -e "\n${GREEN}Build completata${NC}"
echo -e "${YELLOW}OpenDSA: Reading - Lorenzo De Marco${NC} ©Lorenzo DM"
echo -e "${YELLOW}OpenDSA: Reading - Divertiti ad usarla! ©Lorenzo DM"