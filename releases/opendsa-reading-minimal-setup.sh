#!/bin/bash

# OpenDSA: Reading - Script di configurazione minimo
# Questo script configura l'ambiente per OpenDSA: Reading senza dipendere da pacchetti esterni

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
VOSK_PY_DIR="$HOME/.local/share/opendsa-reading/vosk-py"

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

# Funzione per installare le dipendenze di base
install_basic_deps() {
    info "Installazione delle dipendenze di base..."

    # Identifica la distribuzione
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        info "Rilevata distribuzione basata su Debian/Ubuntu"
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip python3-venv unzip wget curl alsa-utils pulseaudio
    elif [ -f /etc/fedora-release ]; then
        # Fedora
        info "Rilevata distribuzione Fedora"
        sudo dnf install -y python3 python3-pip python3-virtualenv unzip wget curl alsa-utils pulseaudio
    elif [ -f /etc/arch-release ]; then
        # Arch Linux
        info "Rilevata distribuzione Arch Linux"
        sudo pacman -Sy --noconfirm python python-pip python-virtualenv unzip wget curl alsa-utils pulseaudio
    else
        warning "Distribuzione non supportata per l'installazione automatica"
        warning "Tentativo di installazione delle dipendenze di base..."

        # Prova a installare Python3 e pip in modo generico
        for cmd in apt-get dnf pacman; do
            if command -v $cmd &> /dev/null; then
                case $cmd in
                    apt-get)
                        sudo apt-get update
                        sudo apt-get install -y python3 python3-pip python3-venv unzip wget curl alsa-utils pulseaudio
                        ;;
                    dnf)
                        sudo dnf install -y python3 python3-pip python3-virtualenv unzip wget curl alsa-utils pulseaudio
                        ;;
                    pacman)
                        sudo pacman -Sy --noconfirm python python-pip python-virtualenv unzip wget curl alsa-utils pulseaudio
                        ;;
                esac
                break
            fi
        done
    fi

    # Verifica che Python sia installato
    if ! command -v python3 &> /dev/null; then
        error "Python3 non è installato e non è stato possibile installarlo"
        error "Installa Python3 manualmente e riprova"
        exit 1
    fi

    # Verifica che pip sia installato
    if ! command -v pip3 &> /dev/null; then
        error "pip3 non è installato e non è stato possibile installarlo"
        error "Installa pip3 manualmente e riprova"
        exit 1
    fi

    success "Dipendenze di base installate correttamente"
    return 0
}

# Funzione per creare e configurare un ambiente virtuale Python per VOSK
setup_vosk_environment() {
    info "Configurazione dell'ambiente Python per VOSK..."

    # Crea la directory per l'ambiente virtuale
    mkdir -p "$VOSK_PY_DIR"

    # Crea un ambiente virtuale Python
    python3 -m venv "$VOSK_PY_DIR/venv"

    # Attiva l'ambiente virtuale
    source "$VOSK_PY_DIR/venv/bin/activate"

    # Aggiorna pip
    pip install --upgrade pip

    # Installa VOSK
    pip install vosk

    # Deattiva l'ambiente virtuale
    deactivate

    success "Ambiente Python per VOSK configurato correttamente"
    return 0
}

# Funzione per scaricare il modello VOSK
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
        wget -q --show-progress "$VOSK_MODEL_URL" -O "$VOSK_MODEL_FILE" || {
            error "Errore nel download del modello"
            info "Tentativo con curl..."
            curl -L -o "$VOSK_MODEL_FILE" "$VOSK_MODEL_URL" || {
                error "Download fallito anche con curl"
                return 1
            }
        }
    fi

    # Estrai il modello
    info "Estrazione del modello..."
    unzip -o -q "$VOSK_MODEL_FILE" -d /tmp/ || {
        error "Errore nell'estrazione del modello"
        return 1
    }

    # Se la directory estratta ha un nome diverso, gestiscila
    MODEL_EXTRACTED_DIR=$(find /tmp -maxdepth 1 -type d -name "vosk-model*" | head -n 1)
    if [ -z "$MODEL_EXTRACTED_DIR" ]; then
        error "Directory del modello estratto non trovata"
        return 1
    fi

    cp -r "$MODEL_EXTRACTED_DIR"/* "$VOSK_MODEL_DIR/" || {
        error "Errore nella copia dei file del modello"
        return 1
    }

    # Pulizia
    rm -f "$VOSK_MODEL_FILE"
    rm -rf "$MODEL_EXTRACTED_DIR"

    success "Modello VOSK italiano scaricato e configurato correttamente in $VOSK_MODEL_DIR"
    return 0
}

# Funzione per verificare l'accesso al microfono
check_microphone() {
    info "Verifica dell'accesso al microfono..."

    if ! command -v arecord &> /dev/null; then
        warning "arecord non è installato, installazione in corso..."

        # Identifica la distribuzione e installa arecord
        if [ -f /etc/debian_version ]; then
            sudo apt-get update
            sudo apt-get install -y alsa-utils
        elif [ -f /etc/fedora-release ]; then
            sudo dnf install -y alsa-utils
        elif [ -f /etc/arch-release ]; then
            sudo pacman -Sy --noconfirm alsa-utils
        else
            warning "Distribuzione non supportata, impossibile installare alsa-utils automaticamente"
            warning "Prova a installare manualmente arecord o alsa-utils"
            return 1
        fi

        # Verifica se l'installazione ha avuto successo
        if ! command -v arecord &> /dev/null; then
            warning "Impossibile installare arecord"
            return 1
        fi
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
                [Ss]* ) sudo usermod -a -G audio "$USER"; success "Utente aggiunto al gruppo 'audio'. Effettua il logout e il login per applicare le modifiche.";;
                * ) warning "L'utente non è stato aggiunto al gruppo 'audio'. Potrebbero esserci problemi di accesso al microfono.";;
            esac
        fi

        # Verifica e configura pulseaudio
        if command -v pulseaudio &> /dev/null; then
            info "Verifica dello stato di PulseAudio..."
            if ! pulseaudio --check; then
                info "Avvio di PulseAudio..."
                pulseaudio --start --log-target=syslog
            fi
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
# Script di avvio per OpenDSA: Reading con VOSK Python

# Attiva l'ambiente virtuale Python
source "$VOSK_PY_DIR/venv/bin/activate"

# Imposta la variabile di ambiente per il modello VOSK
export VOSK_MODEL_PATH="$VOSK_MODEL_DIR"

# Esegui l'AppImage
"\$@"

# Disattiva l'ambiente virtuale
deactivate
EOL

    chmod +x "$LAUNCH_SCRIPT"
    success "Script di avvio creato in $LAUNCH_SCRIPT"

    # Verifica se ~/.local/bin è nel PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        warning "La directory ~/.local/bin non è nel PATH"
        warning "Aggiungi la seguente riga al tuo file ~/.bashrc o ~/.profile:"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\""

        # Aggiungi al bashrc automaticamente
        read -p "Vuoi aggiungere ~/.local/bin al PATH automaticamente? (s/n) " yn
        case $yn in
            [Ss]* )
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
                export PATH="$HOME/.local/bin:$PATH"
                success "~/.local/bin aggiunto al PATH nel file ~/.bashrc"
                ;;
            * )
                warning "Il PATH non è stato modificato. Aggiungilo manualmente per usare il comando 'opendsa-reading'"
                ;;
        esac
    fi

    return 0
}

# Funzione per creare il file desktop
create_desktop_file() {
    info "Creazione del file desktop..."

    DESKTOP_DIR="$HOME/.local/share/applications"
    DESKTOP_FILE="$DESKTOP_DIR/opendsa-reading.desktop"
    mkdir -p "$DESKTOP_DIR"

    # Cerca potenziali AppImage di OpenDSA: Reading
    FOUND_APPIMAGES=$(find "$HOME" -name "OpenDSA*.AppImage" -o -name "*Reading*.AppImage" 2>/dev/null | head -n 5)

    if [ -n "$FOUND_APPIMAGES" ]; then
        info "Trovate possibili AppImage:"
        PS3="Seleziona un'AppImage: "
        select APPIMAGE_PATH in $FOUND_APPIMAGES "Specificare manualmente"; do
            if [ "$REPLY" = "$(echo "$FOUND_APPIMAGES" | wc -w | tr -d ' ')" ]; then
                read -p "Inserisci il percorso completo dell'AppImage di OpenDSA: Reading: " APPIMAGE_PATH
            fi
            break
        done
    else
        read -p "Inserisci il percorso completo dell'AppImage di OpenDSA: Reading: " APPIMAGE_PATH
    fi

    if [ ! -f "$APPIMAGE_PATH" ]; then
        error "File AppImage non trovato in $APPIMAGE_PATH"
        return 1
    fi

    # Rendi eseguibile l'AppImage se non lo è già
    if [ ! -x "$APPIMAGE_PATH" ]; then
        chmod +x "$APPIMAGE_PATH"
        success "Permessi di esecuzione impostati per l'AppImage"
    fi

    # Estrai l'icona dall'AppImage se possibile
    ICON_PATH="$HOME/.local/share/icons/opendsa-reading.png"
    mkdir -p "$(dirname "$ICON_PATH")"

    if [ -x "$APPIMAGE_PATH" ]; then
        info "Tentativo di estrazione dell'icona dall'AppImage..."
        "$APPIMAGE_PATH" --appimage-extract *.png &>/dev/null || true
        if [ -d "squashfs-root" ]; then
            EXTRACTED_ICON=$(find "squashfs-root" -name "*.png" | head -n 1)
            if [ -n "$EXTRACTED_ICON" ]; then
                cp "$EXTRACTED_ICON" "$ICON_PATH"
                success "Icona estratta dall'AppImage"
            fi
            rm -rf "squashfs-root"
        fi
    fi

    # Se non siamo riusciti a estrarre l'icona, usiamo un'icona di sistema
    if [ ! -f "$ICON_PATH" ]; then
        ICON="education"
    else
        ICON="$ICON_PATH"
    fi

    cat > "$DESKTOP_FILE" << EOL
[Desktop Entry]
Name=OpenDSA: Reading
Comment=Applicazione per assistere persone con dislessia nella lettura
Exec=$HOME/.local/bin/opendsa-reading "$APPIMAGE_PATH"
Icon=$ICON
Terminal=false
Type=Application
Categories=Education;Accessibility;
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
    echo -e "${YELLOW}Importante:${NC} Questo script ha configurato un ambiente Python per VOSK invece di usare la libreria nativa."
    echo "Questo dovrebbe garantire una maggiore compatibilità, ma potrebbe essere leggermente più lento."
    echo
}

# Banner
echo -e "${GREEN}╭──────────────────────────────────────────────╮${NC}"
echo -e "${GREEN}│       Setup Minimal per OpenDSA: Reading     │${NC}"
echo -e "${GREEN}╰──────────────────────────────────────────────╯${NC}"
echo ""

# Installa le dipendenze di base
install_basic_deps

# Configura l'ambiente Python per VOSK
setup_vosk_environment

# Scarica il modello VOSK
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