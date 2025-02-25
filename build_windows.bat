@echo off
setlocal enabledelayedexpansion

:: Configurazione delle variabili
set APP_NAME=OpenDSA-Reading
set APP_VERSION=1.0.0
set OUTPUT_DIR=build\releases

:: Colori per l'output
set RED=[91m
set GREEN=[92m
set YELLOW=[93m
set NC=[0m

echo %GREEN%OpenDSA: Reading - Windows Build Script%NC%
echo =====================================

:: Verifica prerequisiti
echo %YELLOW%Controllo prerequisiti...%NC%
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo %RED%Flutter non trovato. Assicurati che Flutter sia installato e nel PATH.%NC%
    exit /b 1
)

:: Mostra versione Flutter
flutter --version | findstr "Flutter"

:: Abilita il supporto per Windows
echo %YELLOW%Abilitazione supporto Windows...%NC%
flutter config --enable-windows-desktop

:: Pulizia ambiente
echo %YELLOW%Pulizia ambiente di build...%NC%
flutter clean
flutter pub get

:: Crea directory di output
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: Build Windows
echo %YELLOW%Building Windows...%NC%

:: Build della versione release
echo Building release version...
flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo %RED%Errore nella build Windows%NC%
    exit /b 1
)

:: Copia i file di release
echo Copiando i file di release...
if not exist "%OUTPUT_DIR%\windows" mkdir "%OUTPUT_DIR%\windows"
xcopy /E /I /Y "build\windows\runner\Release\*" "%OUTPUT_DIR%\windows\"

:: Creazione MSIX (pacchetto per Windows Store)
echo %YELLOW%Creazione pacchetto MSIX...%NC%
flutter pub run msix:create
if %ERRORLEVEL% neq 0 (
    echo %YELLOW%Attenzione: Creazione MSIX fallita%NC%
) else (
    for %%F in ("build\windows\runner\Release\*.msix") do (
        copy "%%F" "%OUTPUT_DIR%\"
    )
)

:: Creazione ZIP della versione portable
echo %YELLOW%Creazione versione portable...%NC%
powershell Compress-Archive -Path "%OUTPUT_DIR%\windows\*" -DestinationPath "%OUTPUT_DIR%\%APP_NAME%-%APP_VERSION%-portable.zip" -Force

echo %GREEN%Build Windows completata con successo!%NC%
echo Gli installer si trovano in: %OUTPUT_DIR%

:: Lista dei file generati
echo.
echo File generati:
dir /B "%OUTPUT_DIR%"

echo.
echo %GREEN%Build completata%NC%
echo %YELLOW%OpenDSA: Reading - Lorenzo De Marco%NC%

endlocal