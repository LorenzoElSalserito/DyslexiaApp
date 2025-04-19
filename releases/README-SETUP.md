# Setup per OpenDSA: Reading

Questo script di configurazione prepara il tuo sistema per eseguire l'AppImage di OpenDSA: Reading.

## Cosa fa lo script

Lo script `opendsa-reading-setup.sh` esegue le seguenti operazioni:

1. **Verifica e installa le dipendenze necessarie** per VOSK (riconoscimento vocale)
    - libvosk
    - libfftw3
    - libpulse
    - unzip, wget, curl, alsa-utils

2. **Scarica e configura il modello VOSK italiano**
    - Il modello viene scaricato da https://alphacephei.com/vosk/models/
    - Viene estratto in `~/.local/share/opendsa-reading/vosk-model`

3. **Verifica l'accesso al microfono**
    - Controlla se l'utente ha i permessi necessari
    - Offre di aggiungere l'utente al gruppo 'audio' se necessario

4. **Crea uno script wrapper personalizzato**
    - Lo script imposta le variabili d'ambiente necessarie prima di eseguire l'AppImage
    - Viene salvato in `~/.local/bin/opendsa-reading`

5. **Crea un file desktop**
    - Aggiunge l'applicazione al menu delle applicazioni
    - Configura l'esecuzione attraverso lo script wrapper

## Come utilizzare

### Installazione

1. Scarica lo script `opendsa-reading-setup.sh`
2. Rendilo eseguibile:
   ```bash
   chmod +x opendsa-reading-setup.sh
   ```
3. Eseguilo:
   ```bash
   ./opendsa-reading-setup.sh
   ```
4. Segui le istruzioni interattive
    - Lo script chiederà il percorso dell'AppImage
    - Dovrai confermare l'installazione delle dipendenze

### Utilizzo

Dopo aver eseguito lo script di setup, puoi avviare OpenDSA: Reading in due modi:

1. **Dal menu delle applicazioni** - Cerca "OpenDSA: Reading"

2. **Da riga di comando** - Usa il comando:
   ```bash
   opendsa-reading /percorso/a/OpenDSA-Reading.AppImage
   ```

## Vantaggi di questo approccio

- **Separazione delle responsabilità** - Lo script gestisce l'ambiente, l'AppImage gestisce l'app
- **Facilità d'uso** - Configurazione unica, poi l'app funziona normalmente
- **Riutilizzabilità** - Funziona con qualsiasi versione di OpenDSA: Reading (AppImage)

## Risoluzione dei problemi

### Riconoscimento vocale non funzionante

Se il riconoscimento vocale non funziona:

1. Verifica che il modello sia stato scaricato correttamente:
   ```bash
   ls -la ~/.local/share/opendsa-reading/vosk-model/am/final.mdl
   ```

2. Verifica che lo script di avvio sia configurato correttamente:
   ```bash
   cat ~/.local/bin/opendsa-reading
   ```

3. Verifica che la variabile VOSK_MODEL_PATH sia impostata durante l'esecuzione:
   ```bash
   VOSK_MODEL_PATH=~/.local/share/opendsa-reading/vosk-model ~/.local/bin/opendsa-reading /percorso/a/OpenDSA-Reading.AppImage
   ```

### Problemi con il microfono

Se l'app non riesce ad accedere al microfono:

1. Verifica che l'utente faccia parte del gruppo audio:
   ```bash
   groups | grep audio
   ```

2. Se necessario, aggiungi l'utente al gruppo:
   ```bash
   sudo usermod -a -G audio $USER
   ```
   Nota: Richiede il logout e login per avere effetto

3. Verifica che il microfono sia rilevato:
   ```bash
   arecord -l
   ```

## Note per gli sviluppatori

Il modello di lingua VOSK utilizzato è `vosk-model-small-it-0.22.zip`. Se desideri utilizzare un modello diverso, modifica le variabili `VOSK_MODEL_URL` e `VOSK_MODEL_FILE` nello script.

Lo script è progettato per essere eseguito una volta sola, configurando l'ambiente per tutte le future esecuzioni dell'AppImage.