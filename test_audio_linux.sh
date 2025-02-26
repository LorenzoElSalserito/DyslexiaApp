#!/bin/bash
# Script di diagnostica per la registrazione audio su Linux

# Colori per output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Diagnostica registrazione audio per OpenDSA: Reading ===${NC}"
echo

# 1. Verifica presenza programmi di registrazione
echo -e "${BLUE}Verifico strumenti di registrazione disponibili...${NC}"
FMEDIA_PATH=$(which fmedia)
ARECORD_PATH=$(which arecord)
SOX_PATH=$(which sox)

# Crea directory di test
TEST_DIR="$HOME/OpenDSA_test_recordings"
mkdir -p "$TEST_DIR"

if [ -n "$FMEDIA_PATH" ]; then
    echo -e "${GREEN}✓ fmedia trovato in: $FMEDIA_PATH${NC}"
    
    echo -e "\nTest registrazione con fmedia (3 secondi)..."
    FMEDIA_OUTPUT="$TEST_DIR/fmedia_test.wav"
    
    $FMEDIA_PATH --record --out "$FMEDIA_OUTPUT" --format=int16 --rate=16000 --channels=1 --volume=125 --notui --until=3
    
    # Verifica file risultante
    if [ -f "$FMEDIA_OUTPUT" ]; then
        SIZE=$(stat -c%s "$FMEDIA_OUTPUT")
        echo -e "${GREEN}✓ File registrato: $FMEDIA_OUTPUT (dimensione: $SIZE byte)${NC}"
    else
        echo -e "${RED}✗ File non creato: $FMEDIA_OUTPUT${NC}"
    fi
else
    echo -e "${RED}✗ fmedia non trovato${NC}"
fi

if [ -n "$ARECORD_PATH" ]; then
    echo -e "\n${GREEN}✓ arecord trovato in: $ARECORD_PATH${NC}"
    
    echo -e "\nTest registrazione con arecord (3 secondi)..."
    ARECORD_OUTPUT="$TEST_DIR/arecord_test.wav"
    
    $ARECORD_PATH -f S16_LE -r 16000 -c 1 -d 3 "$ARECORD_OUTPUT" 2>/dev/null
    
    # Verifica file risultante
    if [ -f "$ARECORD_OUTPUT" ]; then
        SIZE=$(stat -c%s "$ARECORD_OUTPUT")
        echo -e "${GREEN}✓ File registrato: $ARECORD_OUTPUT (dimensione: $SIZE byte)${NC}"
    else
        echo -e "${RED}✗ File non creato: $ARECORD_OUTPUT${NC}"
    fi
else
    echo -e "${RED}✗ arecord non trovato${NC}"
fi

# Verifica dispositivi audio
echo -e "\n${BLUE}Verifica dispositivi audio disponibili...${NC}"

if [ -n "$ARECORD_PATH" ]; then
    echo -e "\n${BLUE}Dispositivi di registrazione (arecord -l):${NC}"
    $ARECORD_PATH -l
fi

echo -e "\n${BLUE}Dispositivi ALSA:${NC}"
cat /proc/asound/cards

echo -e "\n${BLUE}Impostazioni mixer con amixer:${NC}"
amixer -c 0 2>/dev/null || echo -e "${RED}amixer non disponibile o errore${NC}"

echo -e "\n${BLUE}Dispositivi PulseAudio:${NC}"
pactl list sources 2>/dev/null || echo -e "${RED}PulseAudio non disponibile o errore${NC}"

echo -e "\n${GREEN}Test completato. File registrati in: $TEST_DIR${NC}"
echo -e "${GREEN}Riproduci i file con: aplay $TEST_DIR/*.wav${NC}"
