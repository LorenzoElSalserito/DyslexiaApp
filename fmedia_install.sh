#!/bin/bash

# Questo è un semplice script che risolve il problema di installazione di fmedia

# 1. Posizionarsi nella directory dove hai scaricato il file tar.xz di fmedia
cd ~/Documenti/Programmi\ Linux/  # Adatta questo percorso a dove hai il file

# 2. Confermare che il file esiste
ls -la fmedia-1.23.1-linux-amd64.tar.xz

# 3. Rimuovere qualsiasi installazione precedente
sudo rm -f /usr/local/bin/fmedia
sudo rm -rf /usr/local/fmedia-1

# 4. Estrarre correttamente l'archivio
sudo tar -Jxf fmedia-1.23.1-linux-amd64.tar.xz -C /usr/local/

# 5. Verificare che la directory sia stata estratta
ls -la /usr/local/fmedia-1

# 6. Creare il link simbolico
sudo ln -sf /usr/local/fmedia-1/fmedia /usr/local/bin/fmedia

# 7. Verificare che fmedia sia accessibile
which fmedia
fmedia --version

# 8. Verificare i permessi di esecuzione
ls -la /usr/local/fmedia-1/fmedia
# Se i permessi non sono corretti, imposta i permessi di esecuzione
sudo chmod +x /usr/local/fmedia-1/fmedia

# Aggiungere la directory al PATH (solo in caso which fmedia non funzioni)
echo 'export PATH=$PATH:/usr/local/fmedia-1' >> ~/.bashrc
source ~/.bashrc

# Nota: potrebbe essere necessario riavviare il terminale o la sessione