#!/bin/bash

# Script per testare fmedia manualmente

echo "Test di fmedia per la registrazione audio"
echo "========================================"

# Crea una directory temporanea per il test
TEST_DIR=$(mktemp -d)
TEST_FILE="$TEST_DIR/test_recording.wav"

echo "Directory di test: $TEST_DIR"
echo "File di test: $TEST_FILE"

# Formato corretto per fmedia
echo -e "\nTest 1: Comando di base con '--format wav'"
/usr/local/fmedia-1/fmedia --record --out "$TEST_FILE" --format wav --rate 16000 --channels 1 &
FMEDIA_PID=$!
echo "fmedia avviato con PID: $FMEDIA_PID"
echo "Registrazione in corso per 3 secondi..."
sleep 3
kill $FMEDIA_PID
echo "Registrazione fermata"
sleep 1
echo "Verifica file:"
ls -la "$TEST_FILE"

# Formato alternativo con = invece di spazi
echo -e "\nTest 2: Comando con uguale '='"
/usr/local/fmedia-1/fmedia --record --out="$TEST_FILE" --format=wav --rate=16000 --channels=1 &
FMEDIA_PID=$!
echo "fmedia avviato con PID: $FMEDIA_PID"
echo "Registrazione in corso per 3 secondi..."
sleep 3
kill $FMEDIA_PID
echo "Registrazione fermata"
sleep 1
echo "Verifica file:"
ls -la "$TEST_FILE"

# Formato con parametri semplificati
echo -e "\nTest 3: Comando minimo"
/usr/local/fmedia-1/fmedia --record --out="$TEST_FILE" &
FMEDIA_PID=$!
echo "fmedia avviato con PID: $FMEDIA_PID"
echo "Registrazione in corso per 3 secondi..."
sleep 3
kill $FMEDIA_PID
echo "Registrazione fermata"
sleep 1
echo "Verifica file:"
ls -la "$TEST_FILE"

# Visualizzazione help
echo -e "\nVisualizzazione dell'help di fmedia per verificare i parametri corretti:"
/usr/local/fmedia-1/fmedia --help | grep -A 20 record

echo -e "\nTest completati. Pulizia..."
rm -rf "$TEST_DIR"
echo "Directory di test rimossa."
