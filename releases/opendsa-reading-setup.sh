#!/bin/bash

# OpenDSA: Reading - Script di configurazione
# Questo script verifica e installa le dipendenze necessarie per OpenDSA: Reading
# senza modificare l'AppImage esistente.

set -e

# Colori per una migliore leggibilità
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME="OpenDSA: Reading"
VOSK_MODEL_DIR="$HOME/.local/share/opendsa-reading/vosk-model"
VOSK_MODEL_URL="https://alphacephei.com/vosk/models/vosk-model-small-it-0.22.zip"
VOSK_MODEL_FILE="vosk-model-small-it-0.22.zip"

# Funzione per stampare messaggi informativi
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Funzione per stampare messaggi di successo
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Funzione per stampare avvisi
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Funzione per stampare errori
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Funzione per verificare se una dipendenza è installata
check_dependency() {
    if command -v "$1" &> /dev/null; then
        success "$1 è installato"
        return 0
    else
        warning "$1 non è installato"
        return 1
    fi
}

# Funzione per verificare se una libreria è installata
check_library() {
    if ldconfig -p | grep -q "$1"; then
        success "La libreria $1 è installata"
        return 0
    else
        warning "La libreria $1 non è installata"
        return 1
    fi
}

# Funzione per installare le dipendenze su diverse distribuzioni
install_dependencies() {
    info "Installazione delle dipendenze necessarie..."

    # Identifica la distribuzione
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        info "Rilevata distribuzione basata su Debian"
        sudo apt-get update
        sudo apt-get install -y libvosk-dev libfftw3-dev libpulse-dev unzip wget curl alsa-utils
    elif [ -f /etc/fedora-release ]; then
        # Fedora
        info "Rilevata distribuzione Fedora"
        sudo dnf install -y vosk-devel fftw-devel pulseaudio-libs-devel unzip wget curl alsa-utils
    elif [ -f /etc/arch-release ]; then
        # Arch Linux
        info "Rilevata distribuzione Arch Linux"
        sudo pacman -Sy vosk fftw pulseaudio unzip wget curl alsa-utils
    else
        error "Distribuzione non supportata per l'installazione automatica delle dipendenze"
        error "Per favore installa manualmente: libvosk, libfftw3, libpulse, unzip, wget, curl"
        return 1
    fi

    success "Dipendenze installate correttamente"
    return 0
}

# Funzione per scaricare il modello VOSK se necessario
download_vosk_model() {
    info "Verifica del modello VOSK italiano..."

    if [ -d "$VOSK_MODEL_DIR" ] && [ -f "$VOSK_MODEL_DIR/am/final.mdl" ]; then
        success "Modello VOSK italiano già presente in $VOSK_MODEL_DIR"
        return 0
    fi

    info "Modello VOSK italiano non trovato, scaricamento in corso..."

    # Crea la directory per il modello
    mkdir -p "$VOSK_MODEL_DIR"

    # Scarica il modello
    cd /tmp
    if [ ! -f "$VOSK_MODEL_FILE" ]; then
        info "Scaricamento del modello da $VOSK_MODEL_URL"
        wget -q --show-progress "$VOSK_MODEL_URL" -O "$VOSK_MODEL_FILE"
    fi

    # Estrai il modello
    info "Estrazione del modello..."
    unzip -o -q "$VOSK_MODEL_FILE" -d /tmp/
    cp -r /tmp/vosk-model-small-it-0.22/* "$VOSK_MODEL_DIR/"

    # Pulizia
    rm -f "$VOSK_MODEL_FILE"
    rm -rf "/tmp/vosk-model-small-it-0.22"

    success "Modello VOSK italiano scaricato e configurato correttamente in $VOSK_MODEL_DIR"
    return 0
}

# Funzione per verificare l'accesso al microfono
check_microphone() {
    info "Verifica dell'accesso al microfono..."

    if ! command -v arecord &> /dev/null; then
        warning "arecord non è installato, impossibile verificare l'accesso al microfono"
        return 1
    fi

    # Verifica che l'utente abbia accesso al microfono
    arecord -l &> /dev/null
    if [ $? -ne 0 ]; then
        warning "Potrebbero esserci problemi di accesso al microfono"

        # Verifica se l'utente fa parte del gruppo audio
        if ! groups | grep -q "\<audio\>"; then
            warning "L'utente corrente non fa parte del gruppo 'audio'"
            read -p "Vuoi aggiungere l'utente al gruppo 'audio'? (s/n) " yn
            case $yn in
                [Ss]* ) sudo usermod -a -G audio $USER; success "Utente aggiunto al gruppo 'audio'. Effettua il logout e il login per applicare le modifiche.";;
                * ) warning "L'utente non è stato aggiunto al gruppo 'audio'. Potrebbero esserci problemi di accesso al microfono.";;
            esac
        fi

        return 1
    fi

    success "Accesso al microfono verificato"
    return 0
}

# Funzione per creare lo script di avvio
create_launch_script() {
    info "Creazione dello script di avvio..."

    LAUNCH_SCRIPT="$HOME/.local/bin/opendsa-reading"
    mkdir -p "$HOME/.local/bin"

    cat > "$LAUNCH_SCRIPT" << EOL
#!/bin/bash
# Script di avvio per OpenDSA: Reading

# Imposta la variabile di ambiente per il modello VOSK
export VOSK_MODEL_PATH="$VOSK_MODEL_DIR"

# Esegui l'AppImage con l'ambiente corretto
exec "\$@"
EOL

    chmod +x "$LAUNCH_SCRIPT"
    success "Script di avvio creato in $LAUNCH_SCRIPT"

    # Verifica se ~/.local/bin è nel PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        warning "La directory ~/.local/bin non è nel PATH"
        warning "Aggiungi la seguente riga al tuo file ~/.bashrc o ~/.profile:"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi

    return 0
}

# Funzione per creare il file desktop
create_desktop_file() {
    info "Creazione del file desktop..."

    DESKTOP_DIR="$HOME/.local/share/applications"
    DESKTOP_FILE="$DESKTOP_DIR/opendsa-reading.desktop"
    mkdir -p "$DESKTOP_DIR"

    read -p "Inserisci il percorso completo dell'AppImage di OpenDSA: Reading: " APPIMAGE_PATH

    if [ ! -f "$APPIMAGE_PATH" ]; then
        error "File AppImage non trovato in $APPIMAGE_PATH"
        return 1
    fi

    cat > "$DESKTOP_FILE" << EOL
[Desktop Entry]
Name=OpenDSA: Reading
Comment=Applicazione per assistere persone con dislessia nella lettura
Exec=$HOME/.local/bin/opendsa-reading "$APPIMAGE_PATH"
Icon=education
Terminal=false
Type=Application
Categories=Education;
EOL

    success "File desktop creato in $DESKTOP_FILE"
    return 0
}

# Funzione per stampare le istruzioni di utilizzo
print_usage() {
    echo
    echo -e "${GREEN}Configurazione completata per OpenDSA: Reading!${NC}"
    echo
    echo -e "${YELLOW}Come utilizzare l'applicazione:${NC}"
    echo
    echo "1. Avvia l'applicazione dal menu delle applicazioni"
    echo "   oppure"
    echo "2. Esegui da terminale:"
    echo "   $ opendsa-reading /percorso/a/OpenDSA-Reading.AppImage"
    echo
    echo -e "${YELLOW}Nota:${NC} Se hai appena aggiunto l'utente al gruppo 'audio', dovrai effettuare il logout e il login per applicare le modifiche."
    echo
}

# Banner
echo -e "${GREEN}╭──────────────────────────────────────────────╮${NC}"
echo -e "${GREEN}│       Setup per OpenDSA: Reading             │${NC}"
echo -e "${GREEN}╰──────────────────────────────────────────────╯${NC}"
echo ""

# Verifica le dipendenze di base
info "Verifica delle dipendenze..."
MISSING_DEPS=0

# Verifica i programmi necessari
for dep in wget unzip arecord; do
    if ! check_dependency $dep; then
        MISSING_DEPS=1
    fi
done

# Verifica le librerie necessarie
for lib in libvosk libfftw3 libpulse; do
    if ! check_library $lib; then
        MISSING_DEPS=1
    fi
done

# Installa le dipendenze mancanti se necessario
if [ $MISSING_DEPS -eq 1 ]; then
    warning "Alcune dipendenze sono mancanti"
    read -p "Vuoi installare le dipendenze mancanti? (s/n) " yn
    case $yn in
        [Ss]* ) install_dependencies;;
        * ) warning "Le dipendenze mancanti non saranno installate. L'applicazione potrebbe non funzionare correttamente.";;
    esac
fi

# Scarica il modello VOSK se necessario
download_vosk_model

# Verifica l'accesso al microfono
check_microphone

# Crea lo script di avvio
create_launch_script

# Crea il file desktop
create_desktop_file

# Stampa le istruzioni di utilizzo
print_usage

exit 0