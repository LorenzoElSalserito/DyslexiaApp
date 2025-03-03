#!/bin/bash

# GUIDA COMPLETA PER RISOLVERE IL PROBLEMA DELL'ICONA ANDROID

# 1. VERIFICA DEI PERCORSI
# Prima di tutto, assicuriamoci che l'icona esista nella posizione corretta:
echo "Verifica se esiste assets/icon/app_icon.png:"
if [ -f "assets/icon/app_icon.png" ]; then
    echo "✓ L'icona esiste nel percorso specificato"
else
    echo "✗ L'icona NON esiste nel percorso specificato!"
    echo "Creiamo la directory e spostiamo l'icona se necessario:"
    mkdir -p assets/icon
    
    # Prova a trovare l'icona in percorsi alternativi
    if [ -f "lib/assets/icon/app_icon.png" ]; then
        cp lib/assets/icon/app_icon.png assets/icon/
        echo "  Icona copiata da lib/assets/icon/ a assets/icon/"
    else
        echo "  ATTENZIONE: Icona non trovata in nessun percorso noto!"
        echo "  Devi creare o posizionare manualmente un'icona in assets/icon/app_icon.png"
    fi
fi

# 2. PULIZIA DELLA CACHE FLUTTER
echo ""
echo "Pulizia della cache Flutter:"
echo "flutter clean"
flutter clean
echo "flutter pub get"
flutter pub get

# 3. RIGENERAZIONE DELLE ICONE
echo ""
echo "Rigenerazione delle icone con flutter_launcher_icons:"
echo "flutter pub run flutter_launcher_icons"
flutter pub run flutter_launcher_icons

# 4. PULIZIA DELLA BUILD ANDROID
echo ""
echo "Pulizia specifica per Android:"
echo "Rimuovendo manualmente la directory build/app/outputs/flutter-apk se esiste"
if [ -d "build/app/outputs/flutter-apk" ]; then
    rm -rf build/app/outputs/flutter-apk
    echo "✓ Directory build/app/outputs/flutter-apk rimossa"
fi

# 5. VERIFICA DELL'IMMAGINE
echo ""
echo "Verifica qualità dell'immagine:"
if [ -f "assets/icon/app_icon.png" ]; then
    file_size=$(stat -c%s "assets/icon/app_icon.png" 2>/dev/null || stat -f%z "assets/icon/app_icon.png")
    echo "Dimensione file: $file_size byte"
    
    if [ $file_size -lt 1000 ]; then
        echo "⚠️ ATTENZIONE: Il file dell'icona è molto piccolo, potrebbe essere di bassa qualità"
    elif [ $file_size -gt 1000000 ]; then
        echo "⚠️ ATTENZIONE: Il file dell'icona è molto grande, potrebbe causare problemi"
    else
        echo "✓ Dimensione file ok"
    fi
else
    echo "Non posso verificare l'immagine perché non esiste"
fi

# 6. RICREA L'APP
echo ""
echo "Ricreazione dell'APK Android:"
echo "flutter build apk"
flutter build apk

echo ""
echo "Procedura completata. Installa l'APK generato sul dispositivo per verificare se l'icona è stata aggiornata."
echo "Path dell'APK: build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "Se il problema persiste, prova i seguenti approcci alternativi:"
echo "1. Assicurati che l'immagine app_icon.png sia in formato PNG di alta qualità (1024x1024px consigliato)"
echo "2. Prova a modificare il file android/app/src/main/AndroidManifest.xml e assicurati che punti all'icona corretta"
echo "3. Considera di utilizzare il plugin 'flutter_native_splash' per gestire anche le icone"
