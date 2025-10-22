#!/bin/bash

# OpenDSA: Reading - Script di configurazione definitivo
# Questo script verifica e installa le dipendenze necessarie per OpenDSA: Reading
# e risolve specificamente il problema di inizializzazione di VOSK.

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
VOSK_PYTHON_VERSION="0.3.45"  # Versione specifica di VOSK Python che funziona

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

# Funzione per installare VOSK tramite pip con una versione specifica e testare l'installazione
install_vosk_with_pip() {
    info "Installazione di VOSK tramite pip (versione specifica $VOSK_PYTHON_VERSION)..."

    # Verifica se pip è installato
    if ! command -v pip3 &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y python3-pip python3-dev
    fi

    # Assicurati che wheel sia installato
    pip3 install --user wheel

    # Disinstalla versioni precedenti di vosk per evitare conflitti
    pip3 uninstall -y vosk 2>/dev/null || true

    # Elimina anche cache e file di egg-info per una pulizia totale
    rm -rf ~/.cache/pip/wheels/*vosk* 2>/dev/null || true
    rm -rf ~/.local/lib/python*/site-packages/vosk*.egg-info 2>/dev/null || true
    rm -rf ~/.local/lib/python*/site-packages/vosk/ 2>/dev/null || true

    # Installa VOSK usando pip con versione specifica e opzioni aggiuntive
    pip3 install --user --no-cache-dir --force-reinstall vosk==$VOSK_PYTHON_VERSION

    # Verifica l'installazione
    if python3 -c "import vosk; print('VOSK importato con successo')" &> /dev/null; then
        success "VOSK installato e testato correttamente con Python"
        return 0
    else
        error "VOSK installato ma non può essere importato. Tentativo con approccio alternativo..."

        # Prova con un approccio alternativo: installa anche sounddevice e pulseaudio
        pip3 install --user sounddevice

        # Installa dipendenze audio aggiuntive
        if [ -f /etc/debian_version ]; then
            sudo apt-get install -y python3-pyaudio pulseaudio-utils libpulse-dev
        elif [ -f /etc/fedora-release ]; then
            sudo dnf install -y python3-pyaudio pulseaudio-utils pulseaudio-libs-devel
        elif [ -f /etc/arch-release ]; then
            sudo pacman -Sy --noconfirm python-pyaudio pulseaudio-utils
        fi

        # Riprova l'importazione
        if python3 -c "import vosk; print('VOSK importato con successo')" &> /dev/null; then
            success "VOSK installato e testato correttamente al secondo tentativo"
            return 0
        else
            error "VOSK non può essere importato anche dopo l'installazione delle dipendenze"
            return 1
        fi
    fi
}

# Funzione per installare le dipendenze più importanti
install_core_deps() {
    info "Installazione delle dipendenze essenziali..."

    # Identifica la distribuzione
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y python3-dev python3-pip libfftw3-dev libpulse-dev unzip wget curl alsa-utils python3-pyaudio pulseaudio-utils
    elif [ -f /etc/fedora-release ]; then
        # Fedora
        sudo dnf install -y python3-devel python3-pip fftw-devel pulseaudio-libs-devel unzip wget curl alsa-utils python3-pyaudio pulseaudio-utils
    elif [ -f /etc/arch-release ]; then
        # Arch Linux
        sudo pacman -Sy --noconfirm python python-pip fftw pulseaudio unzip wget curl alsa-utils python-pyaudio pulseaudio-utils
    else
        # Distribuzione generica: prova a usare apt, dnf o pacman
        for cmd in apt-get dnf pacman; do
            if command -v $cmd &> /dev/null; then
                case $cmd in
                    apt-get)
                        sudo apt-get update
                        sudo apt-get install -y python3-dev python3-pip libfftw3-dev libpulse-dev unzip wget curl alsa-utils python3-pyaudio pulseaudio-utils
                        ;;
                    dnf)
                        sudo dnf install -y python3-devel python3-pip fftw-devel pulseaudio-libs-devel unzip wget curl alsa-utils python3-pyaudio pulseaudio-utils
                        ;;
                    pacman)
                        sudo pacman -Sy --noconfirm python python-pip fftw pulseaudio unzip wget curl alsa-utils python-pyaudio pulseaudio-utils
                        ;;
                esac
                break
            fi
        done
    fi
}

# Funzione per installare le dipendenze su diverse distribuzioni
install_dependencies() {
    info "Installazione delle dipendenze necessarie..."

    # Prima installa le dipendenze chiave
    install_core_deps

    # Poi installa VOSK tramite pip (approccio più affidabile)
    if ! install_vosk_with_pip; then
        warning "Installazione di VOSK tramite pip non riuscita"

        # Prova un'ultima strategia: installa sounddevice e altre dipendenze audio
        info "Installazione di dipendenze audio aggiuntive..."
        pip3 install --user sounddevice numpy cffi

        # Riprova l'installazione di VOSK
        if ! install_vosk_with_pip; then
            error "Non è stato possibile installare VOSK"
            error "Prova a installare manualmente: pip3 install --user vosk==$VOSK_PYTHON_VERSION"
            exit 1
        fi
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
            error "Errore nel download del modello con wget"
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

# Funzione per verificare l'accesso al microfono e impostare i permessi corretti
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
    fi

    # Verifica e crea i device ALSA se necessario
    if [ ! -d "/dev/snd" ]; then
        warning "Directory /dev/snd non trovata"
        if [[ $EUID -eq 0 ]]; then
            mkdir -p /dev/snd
            success "Directory /dev/snd creata"
        else
            warning "È necessario eseguire come root per creare /dev/snd"
            sudo mkdir -p /dev/snd
            success "Directory /dev/snd creata"
        fi
    fi

    # Verifica e imposta i permessi per tutti gli utenti su /dev/snd
    if [ -d "/dev/snd" ]; then
        info "Impostazione permessi per /dev/snd"
        sudo chmod -R 777 /dev/snd
        success "Permessi impostati per /dev/snd"
    fi

    # Verifica che l'utente abbia accesso al microfono
    arecord -l &> /dev/null
    if [ $? -ne 0 ]; then
        warning "Accesso al microfono non disponibile o problematico"

        # Verifica se l'utente fa parte del gruppo audio
        if ! groups | grep -q "\<audio\>"; then
            warning "L'utente corrente non fa parte del gruppo 'audio'"
            read -p "Vuoi aggiungere l'utente al gruppo 'audio'? (s/n) " yn
            case $yn in
                [Ss]* )
                    sudo usermod -a -G audio "$USER"
                    # Aggiunge anche altri gruppi utili
                    sudo usermod -a -G pulse "$USER"
                    sudo usermod -a -G pulse-access "$USER"
                    success "Utente aggiunto ai gruppi 'audio', 'pulse' e 'pulse-access'. Effettua il logout e il login per applicare le modifiche."
                    ;;
                * )
                    warning "L'utente non è stato aggiunto al gruppo 'audio'. Potrebbero esserci problemi di accesso al microfono."
                    ;;
            esac
        fi

        # Verifica e configura pulseaudio
        if command -v pulseaudio &> /dev/null; then
            info "Verifica dello stato di PulseAudio..."
            if ! pulseaudio --check; then
                info "Avvio di PulseAudio..."
                pulseaudio --start --log-target=syslog

                # Verifica che pulseaudio sia in esecuzione
                sleep 2
                if ! pulseaudio --check; then
                    warning "Impossibile avviare PulseAudio. Tentativo con l'utente attuale..."
                    pulseaudio --start --log-target=syslog || true
                fi
            fi

            # Forza un reset di PulseAudio
            info "Reset di PulseAudio..."
            pulseaudio -k || true
            sleep 1
            pulseaudio --start || true

            # Verifica accesso ai device e crea symlink se necessario
            if [ -d "/dev/snd" ]; then
                for device in /dev/snd/*; do
                    chmod a+rw "$device" || true
                done
            fi
        fi
        else
        success "Accesso al microfono verificato"
        fi
    return 0
}

# Testa l'inizializzazione di VOSK con un breve script Python
test_vosk_initialization() {
    info "Test dell'inizializzazione di VOSK..."

    # Crea un file di test temporaneo
    VOSK_TEST_SCRIPT="/tmp/vosk_test.py"

    cat > "$VOSK_TEST_SCRIPT" << EOL
#!/usr/bin/env python3
try:
    import sys
    import json
    import os
    import vosk

    # Ottieni le proprietà e i metodi del modulo
    vosk_attrs = dir(vosk)
    print(f"Attributi disponibili nel modulo vosk: {vosk_attrs}")

    # Non utilizziamo __version__ che potrebbe non essere presente
    print(f"VOSK importato con successo")

    # Imposta il percorso del modello
    model_path = "$VOSK_MODEL_DIR"
    print(f"Percorso modello: {model_path}")

    # Elenca file nel percorso del modello
    print("File nella directory del modello:")
    for root, dirs, files in os.walk(model_path):
        for file in files:
            print(f"  {os.path.join(root, file)}")

    # Prova a caricare il modello con debug
    print("Tentativo di caricamento del modello...")
    model = vosk.Model(model_path)
    print("Modello VOSK caricato con successo")

    # Crea un riconoscitore per testare
    print("Tentativo di creazione del riconoscitore...")
    rec = vosk.KaldiRecognizer(model, 16000)
    print("Riconoscitore VOSK creato con successo")

    print("Test di inizializzazione VOSK completato con successo")
    sys.exit(0)
except Exception as e:
    print(f"Errore nell'inizializzazione di VOSK: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOL

    chmod +x "$VOSK_TEST_SCRIPT"

    # Esegui il test con dettagli
    echo "=================================================="
    echo "Esecuzione del test VOSK Python:"
    echo "=================================================="
    if python3 "$VOSK_TEST_SCRIPT"; then
        success "Inizializzazione di VOSK testata con successo"
        return 0
    else
        error "Problema nell'inizializzazione di VOSK (vedi dettagli sopra)"
        return 1
    fi
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

# Imposta variabili per i permessi audio
export PULSE_SERVER=unix:/tmp/pulse-socket
export ALSA_CARD=0

# Impostazioni per Python e VOSK
PYTHON_VERSION=\$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)
export PYTHONPATH="\$HOME/.local/lib/python\$PYTHON_VERSION/site-packages:\$PYTHONPATH"

# Assicura che il socket di pulseaudio sia accessibile
mkdir -p /tmp/pulse-socket

# Logging per debugging
LOG_FILE="\$HOME/.local/share/opendsa-reading/launch.log"
mkdir -p "\$(dirname "\$LOG_FILE")"

# Esegui l'AppImage con l'ambiente corretto
echo "Avvio di OpenDSA: Reading da \$1 alle \$(date)" >> "\$LOG_FILE"
echo "VOSK_MODEL_PATH=\$VOSK_MODEL_PATH" >> "\$LOG_FILE"
echo "PYTHONPATH=\$PYTHONPATH" >> "\$LOG_FILE"

# Permessi per i device audio prima di avviare
for device in /dev/snd/* /dev/dsp* /dev/audio* ; do
    if [ -e "\$device" ]; then
        sudo chmod a+rw "\$device" 2>/dev/null || true
    fi
done

# Esegui l'AppImage
"\$@"
EOL

    chmod +x "$LAUNCH_SCRIPT"
    success "Script di avvio creato in $LAUNCH_SCRIPT"

    # Verifica se ~/.local/bin è nel PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        warning "La directory ~/.local/bin non è nel PATH"

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
        select APPIMAGE_PATH in $FOUND_APPIMAGES "Specificare manualmente"; do
            if [ "$REPLY" = "$(echo "$FOUND_APPIMAGES" | wc -w)" ]; then
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
Exec=pkexec $HOME/.local/bin/opendsa-reading "$APPIMAGE_PATH"
Icon=$ICON
Terminal=false
Type=Application
Categories=Education;Accessibility;
EOL

    success "File desktop creato in $DESKTOP_FILE"

    # Crea il file pkexec policy per eseguire lo script con privilegi
    info "Creazione della policy pkexec..."
    PKEXEC_POLICY="/usr/share/polkit-1/actions/org.opendsa.reading.policy"

    sudo bash -c "cat > $PKEXEC_POLICY" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1.0/policyconfig.dtd">
<policyconfig>
  <action id="org.opendsa.reading">
    <description>Run OpenDSA: Reading with elevated privileges</description>
    <message>Authentication is required to access audio devices</message>
    <defaults>
      <allow_any>yes</allow_any>
      <allow_inactive>yes</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">$HOME/.local/bin/opendsa-reading</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>
</policyconfig>
EOL

    success "Policy pkexec creata in $PKEXEC_POLICY"
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
    echo -e "${YELLOW}Note:${NC}"
    echo "- Se hai appena aggiunto l'utente al gruppo 'audio', dovrai effettuare il logout e il login per applicare le modifiche."
    echo "- L'applicazione verrà eseguita con privilegi elevati per accedere correttamente ai dispositivi audio."
    echo "- Se riscontri problemi, controlla il file di log in ~/.local/share/opendsa-reading/launch.log"
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
for dep in wget unzip; do
    if ! check_dependency $dep; then
        MISSING_DEPS=1
    fi
done

# Verifica le librerie necessarie
for lib in libfftw3 libpulse; do
    if ! check_library $lib; then
        MISSING_DEPS=1
    fi
done

# Verifica Python e pip
if ! check_dependency python3 || ! python3 -c "import pip" &>/dev/null; then
    warning "Python3 o pip non trovati"
    MISSING_DEPS=1
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

# Crea il gruppo audio se non esiste
if ! getent group audio >/dev/null; then
    info "Creazione del gruppo audio..."
    sudo groupadd audio
    success "Gruppo audio creato"
fi

# Crea lo script di avvio
#create_launch_script

# Scarica il modello VOSK se necessario
download_vosk_model

# Verifica l'accesso al microfono
check_microphone

# Testa l'inizializzazione di VOSK
# Assicura la presenza del modulo Python 'vosk' prima del test
#if ! python3 -c "import vosk" &>/dev/null; then
#    info "Modulo Python 'vosk' mancante: installazione in corso..."
#    install_vosk_with_pip || { error "Installazione di VOSK fallita"; exit 1; }
#else
#    success "Modulo Python 'vosk' già presente"
#fi
#test_vosk_initialization

# Crea il file desktop
#create_desktop_file

# Stampa le istruzioni di utilizzo
print_usage

exit 0