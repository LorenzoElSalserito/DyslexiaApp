#!/bin/bash

# OpenDSA: Reading - Script di configurazione migliorato
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
    if ldconfig -p 2>/dev/null | grep -q "$1"; then
        success "La libreria $1 è installata"
        return 0
    else
        warning "La libreria $1 non è installata"
        return 1
    fi
}

# Funzione per aggiungere un repository PPA (per Ubuntu/Debian)
add_ppa_repository() {
    info "Aggiunta del repository PPA per VOSK..."

    # Verifica se add-apt-repository è disponibile
    if ! command -v add-apt-repository &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y software-properties-common
    fi

    # Aggiungi il PPA per VOSK
    sudo add-apt-repository -y ppa:vosk/vosk
    sudo apt-get update

    success "Repository PPA aggiunto correttamente"
    return 0
}

# Funzione per compilare VOSK da sorgente
compile_vosk_from_source() {
    info "Compilazione di VOSK da sorgente..."

    # Installa le dipendenze per la compilazione
    sudo apt-get update
    sudo apt-get install -y build-essential git cmake libfftw3-dev

    # Crea una directory temporanea per la compilazione
    mkdir -p /tmp/vosk-build
    cd /tmp/vosk-build

    # Clona il repository di VOSK
    git clone --depth 1 https://github.com/alphacep/vosk-api
    cd vosk-api/c

    # Compila VOSK
    mkdir -p build
    cd build
    cmake ..
    make

    # Installa VOSK
    sudo make install
    sudo ldconfig

    success "VOSK compilato e installato da sorgente"
    return 0
}

# Funzione per installare le dipendenze VOSK usando pip (come alternativa)
install_vosk_with_pip() {
    info "Installazione di VOSK usando pip..."

    # Verifica se pip è installato
    if ! command -v pip3 &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y python3-pip
    fi

    # Installa VOSK usando pip
    pip3 install --user vosk

    success "VOSK installato tramite pip"
    return 0
}

# Funzione per installare le dipendenze su diverse distribuzioni
install_dependencies() {
    info "Installazione delle dipendenze necessarie..."

    # Identifica la distribuzione
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        info "Rilevata distribuzione basata su Debian/Ubuntu"
        sudo apt-get update

        # Prova prima con i repository standard
        info "Tentativo di installazione di libvosk dai repository standard..."
        if sudo apt-get install -y libvosk-dev 2>/dev/null; then
            success "libvosk-dev installato dai repository standard"
        else
            warning "libvosk-dev non disponibile nei repository standard"

            # Prova con il PPA ufficiale
            info "Tentativo con il repository PPA..."
            if add_ppa_repository && sudo apt-get install -y libvosk-dev; then
                success "libvosk-dev installato dal PPA"
            else
                warning "Impossibile installare libvosk-dev dal PPA"

                # Ultima opzione: compilazione da sorgente
                info "Tentativo di compilazione da sorgente..."
                if ! compile_vosk_from_source; then
                    warning "Compilazione da sorgente fallita"

                    # Opzione finale: installazione tramite pip
                    info "Tentativo di installazione tramite pip..."
                    if ! install_vosk_with_pip; then
                        error "Tutte le opzioni di installazione per VOSK sono fallite"
                        error "Prova a installare manualmente libvosk o python3-vosk"
                        exit 1
                    fi
                fi
            fi
        fi

        # Installa le altre dipendenze
        sudo apt-get install -y libfftw3-dev libpulse-dev unzip wget curl alsa-utils

    elif [ -f /etc/fedora-release ]; then
        # Fedora
        info "Rilevata distribuzione Fedora"
        if sudo dnf install -y vosk-devel 2>/dev/null; then
            success "vosk-devel installato dai repository standard"
        else
            warning "vosk-devel non disponibile nei repository standard"

            # Prova con la versione Python
            info "Tentativo di installazione tramite pip..."
            if ! install_vosk_with_pip; then
                error "Tutte le opzioni di installazione per VOSK sono fallite"
                error "Prova a installare manualmente libvosk o python3-vosk"
                exit 1
            fi
        fi

        # Installa le altre dipendenze
        sudo dnf install -y fftw-devel pulseaudio-libs-devel unzip wget curl alsa-utils

    elif [ -f /etc/arch-release ]; then
        # Arch Linux
        info "Rilevata distribuzione Arch Linux"

        # Verifica se vosk è disponibile
        if sudo pacman -Sy --noconfirm vosk 2>/dev/null; then
            success "vosk installato dai repository standard"
        else
            warning "vosk non disponibile nei repository standard"

            # Prova con AUR (yay)
            if command -v yay &> /dev/null; then
                info "Tentativo di installazione tramite AUR (yay)..."
                if yay -S --noconfirm vosk; then
                    success "vosk installato da AUR"
                else
                    warning "Installazione tramite AUR fallita"

                    # Prova con pip
                    if ! install_vosk_with_pip; then
                        error "Tutte le opzioni di installazione per VOSK sono fallite"
                        error "Prova a installare manualmente libvosk o python3-vosk"
                        exit 1
                    fi
                fi
            else
                # Se yay non è disponibile, usa pip
                if ! install_vosk_with_pip; then
                    error "Tutte le opzioni di installazione per VOSK sono fallite"
                    error "Prova a installare manualmente libvosk o python3-vosk"
                    exit 1
                fi
            fi
        fi

        # Installa le altre dipendenze
        sudo pacman -Sy --noconfirm fftw pulseaudio unzip wget curl alsa-utils

    else
        # Distribuzione non supportata
        warning "Distribuzione non supportata per l'installazione automatica delle dipendenze"
        warning "Tentativo di installazione tramite pip..."

        # Prova con pip come ultima risorsa
        if ! install_vosk_with_pip; then
            error "Installazione tramite pip fallita"
            error "Per favore installa manualmente: libvosk, libfftw3, libpulse, unzip, wget, curl"
            exit 1
        fi

        info "Installazione delle dipendenze di base..."
        # Prova a installare le dipendenze essenziali
        for cmd in apt-get dnf pacman; do
            if command -v $cmd &> /dev/null; then
                case $cmd in
                    apt-get)
                        sudo apt-get update
                        sudo apt-get install -y libfftw3-dev libpulse-dev unzip wget curl alsa-utils
                        ;;
                    dnf)
                        sudo dnf install -y fftw-devel pulseaudio-libs-devel unzip wget curl alsa-utils
                        ;;
                    pacman)
                        sudo pacman -Sy --noconfirm fftw pulseaudio unzip wget curl alsa-utils
                        ;;
                esac
                break
            fi
        done
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
        wget -q --show-progress "$VOSK_MODEL_URL" -O "$VOSK_MODEL_FILE" || {
            error "Errore nel download del modello"
            # Prova con curl come alternativa
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
# Script di avvio per OpenDSA: Reading

# Imposta la variabile di ambiente per il modello VOSK
export VOSK_MODEL_PATH="$VOSK_MODEL_DIR"

# Se il modello di VOSK è stato installato tramite pip, imposta PYTHONPATH
if [ -d "$HOME/.local/lib/python3.*/site-packages/vosk" ]; then
    PYTHON_VERSION=\$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)
    export PYTHONPATH="\$HOME/.local/lib/python\$PYTHON_VERSION/site-packages:\$PYTHONPATH"
fi

# Imposta LD_LIBRARY_PATH per librerie compilate manualmente
if [ -d "/usr/local/lib" ]; then
    export LD_LIBRARY_PATH="/usr/local/lib:\$LD_LIBRARY_PATH"
fi

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

        # Aggiungi al bashrc automaticamente
        read -p "Vuoi aggiungere ~/.local/bin al PATH automaticamente? (s/n) " yn
        case $yn in
            [Ss]* )
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
                source "$HOME/.bashrc"
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
        select APPIMAGE_PATH in $FOUND_APPIMAGES "Specificare manualmente"; do
            if [ "$REPLY" = "$(echo "$FOUND_APPIMAGES" | wc -l | tr -d ' ')" ]; then
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
    # Verifica se Python è stato usato
    if pip3 list 2>/dev/null | grep -q vosk; then
        echo -e "${YELLOW}Importante:${NC} VOSK è stato installato tramite Python. Se riscontri problemi, prova a eseguire:"
        echo "$ python3 -c 'import vosk; print(\"VOSK è correttamente installato\")'"
        echo
    fi
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
for dep in wget unzip; do
    if ! check_dependency $dep; then
        MISSING_DEPS=1
    fi
done

# Verifica le librerie necessarie (in modo silenzioso per evitare errori su distribuzioni senza ldconfig)
for lib in libfftw3 libpulse; do
    if ! check_library $lib; then
        MISSING_DEPS=1
    fi
done

# Per libvosk facciamo una verifica più approfondita
if ! check_library libvosk && ! pip3 list 2>/dev/null | grep -q vosk; then
    warning "VOSK non trovato né come libreria C né come modulo Python"
    MISSING_DEPS=1
else
    success "VOSK trovato (libreria o modulo Python)"
fi

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