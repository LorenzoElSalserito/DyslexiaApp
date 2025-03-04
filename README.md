# OpenDSA: Reading

**OpenDSA: Reading** è un'applicazione multi-piattaforma progettata per assistere le persone con dislessia nel miglioramento delle loro competenze di lettura attraverso esercizi interattivi e feedback vocale.

<p align="center">
  <img src="assets/icon/app_icon.png" alt="OpenDSA: Reading Logo" width="150"/>
</p>

## Caratteristiche Principali

- **Esercizi di lettura progressivi**: Parole, frasi, paragrafi e pagine di difficoltà crescente
- **Riconoscimento vocale**: Analisi delle registrazioni con confronto del testo target
- **Sistema di gamification**: Cristalli e trofei da guadagnare completando gli esercizi
- **Sfide giornaliere e settimanali**: Per mantenere alta la motivazione
- **Profili multipli**: Supporto per diversi utenti sulla stessa installazione
- **Statistiche di apprendimento**: Monitoraggio dei progressi nel tempo
- **Accessibilità**: Font OpenDyslexic e interfaccia progettata per le esigenze delle persone con dislessia
- **Supporto multi-piattaforma**: Android, iOS, Windows, macOS e Linux

## Tecnologie Utilizzate

- **Flutter**: Framework per lo sviluppo multi-piattaforma
- **VOSK**: Motore di riconoscimento vocale offline
- **Provider**: Per la gestione dello stato
- **SharedPreferences**: Per la persistenza dei dati
- **Record**: Libreria per la registrazione audio

## Requisiti di Sistema

### Requisiti Minimi
- **Android**: Android 5.0 (API level 21) o superiore
- **iOS/iPadOS**: iOS 11.0 o superiore
- **Windows**: Windows 10 (64-bit) o superiore
- **macOS**: macOS 10.14 (Mojave) o superiore
- **Linux**: Ubuntu 18.04 o distribuzioni equivalenti
- **Spazio di archiviazione**: 100 MB
- **RAM**: 512 MB

### Requisiti Raccomandati
- **Microfono**: Necessario per gli esercizi di riconoscimento vocale
- **Spazio di archiviazione**: 200 MB
- **RAM**: 1 GB

## Installazione

### Android
1. Scarica il file APK dalla sezione [Releases](https://github.com/username/OpenDSA-Reading/releases)
2. Apri il file APK sul tuo dispositivo per installare l'applicazione
3. Concedi le autorizzazioni per il microfono quando richiesto

### iOS
L'app è disponibile tramite TestFlight. Contatta gli sviluppatori per un link di invito. (Ancora in Testing)

### Windows
1. Scarica il file MSIX o la cartella ZIP dalla sezione [Releases](https://github.com/username/OpenDSA-Reading/releases)
2. Esegui il file MSIX o lancia l'eseguibile dalla cartella estratta

### macOS
1. Scarica il file DMG dalla sezione [Releases](https://github.com/username/OpenDSA-Reading/releases)
2. Monta il DMG e trascina l'applicazione nella cartella Applicazioni
3. Al primo avvio, potrebbe essere necessario approvare l'app in Preferenze di Sistema > Sicurezza e Privacy

### Linux
1. Scarica il file AppImage dalla sezione [Releases](https://github.com/username/OpenDSA-Reading/releases)
2. Rendi il file eseguibile con `chmod +x OpenDSA-Reading-1.0.0-x86_64.AppImage`
3. Esegui l'AppImage con un doppio clic o da terminale

## Compilazione da Sorgente

### Prerequisiti
- Flutter SDK 3.5.3 o superiore
- Dart SDK 3.5.0 o superiore
- Android SDK (per build Android)
- Xcode (per build iOS/macOS, solo su macOS)
- Visual Studio (per build Windows)
- Pacchetti di sviluppo per Linux (per build Linux)

### Passi per la Compilazione

1. Clona il repository:
   ```bash
   git clone https://github.com/username/OpenDSA-Reading.git
   cd OpenDSA-Reading
   ```

2. Installa le dipendenze:
   ```bash
   flutter pub get
   ```

3. Verifica i requisiti:
   ```bash
   flutter doctor
   ```

4. Esegui il progetto in modalità debug:
   ```bash
   flutter run
   ```

5. Compila il progetto per la tua piattaforma target:
   ```bash
   flutter build apk  # Per Android
   flutter build ios  # Per iOS
   flutter build windows  # Per Windows
   flutter build macos  # Per macOS
   flutter build linux  # Per Linux
   ```

6. In alternativa, utilizza lo script di build automatizzato (su Linux/macOS):
   ```bash
   chmod +x build.sh
   ./build.sh
   ```

Lo script `build.sh` eseguirà automaticamente la build per tutte le piattaforme disponibili sul sistema in uso. Gli output di build verranno salvati nella directory `build/releases/`.

## Struttura del Progetto

```
lib/
├── config/              # Configurazioni dell'app
├── models/              # Modelli dati
├── screens/             # Schermate UI
├── services/            # Servizi di business logic
├── utils/               # Utilità e helper
└── widgets/             # Widget riutilizzabili
```

### Componenti Principali

- **AudioService**: Gestisce la registrazione audio
- **ExerciseManager**: Coordina gli esercizi e valuta i risultati
- **GameService**: Gestisce la progressione, rewards e analytics
- **PlayerManager**: Gestisce i profili utente e il salvataggio
- **StoreService**: Gestisce i trofei acquistabili
- **VoskService**: Interfaccia con il motore di riconoscimento vocale

## Flusso di Esecuzione degli Esercizi

1. L'utente avvia una serie di esercizi (5 per sessione)
2. Per ogni esercizio:
    1. L'utente legge ad alta voce il testo visualizzato
    2. L'app registra l'audio in un file WAV
    3. Il file audio viene inviato al motore VOSK per il riconoscimento
    4. Il testo riconosciuto viene confrontato con il testo target
    5. L'app calcola la similarità e assegna un punteggio
3. Al termine della sessione, viene mostrato un riepilogo con i risultati e i cristalli guadagnati

## Contributi

Le contribuzioni sono benvenute! Per partecipare:

1. Fai un fork del repository
2. Crea un branch per la tua feature (`git checkout -b feature/NuovaFeature`)
3. Commit dei tuoi cambiamenti (`git commit -am 'Aggiungi NuovaFeature'`)
4. Push al branch (`git push origin feature/NuovaFeature`)
5. Crea una Pull Request

## Problemi Noti

- Su alcune distribuzioni Linux potrebbero essere necessarie librerie aggiuntive per il riconoscimento vocale
- Su iOS, l'accesso al microfono potrebbe richiedere autorizzazioni aggiuntive
- Il primo avvio dell'app potrebbe richiedere più tempo a causa dell'inizializzazione del motore VOSK

## Licenza

Copyright © 2025 Lorenzo DM

Questo progetto è rilasciato sotto licenza GNU General Public License v3.0 (GPL-3.0) - vedi il file [LICENSE](LICENSE) per i dettagli.
