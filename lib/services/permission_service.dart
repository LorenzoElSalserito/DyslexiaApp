// lib/services/permission_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Importa permission_handler e il nostro gestore migliorato
import 'package:permission_handler/permission_handler.dart'
if (dart.library.io) 'package:permission_handler/permission_handler.dart'
if (dart.library.html) 'package:permission_handler/permission_handler.dart';
import '../utils/permission_handler.dart';

/// Servizio centralizzato per la gestione dei permessi dell'applicazione.
/// Gestisce i permessi in modo diverso per ogni piattaforma supportata:
/// - Android: Usa una strategia adattiva in base alla versione
/// - iOS: Usa permission_handler standard
/// - Linux: Usa controlli nativi del filesystem
/// - Web: Usa le API del browser
/// - Windows/macOS: Usa permission_handler
class PermissionService {
  // Singleton pattern
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;

  // Stato interno e logging
  final List<String> _permissionLogs = [];
  bool _isInitialized = false;

  // Stato dei permessi
  bool _storagePermissionGranted = false;
  bool _microphonePermissionGranted = false;

  // Timeout per operazioni di permessi (in secondi)
  static const int _permissionTimeout = 5;

  PermissionService._internal() {
    _logPermissionEvent('PermissionService inizializzato');
  }

  /// Determina se la piattaforma richiede gestione esplicita dei permessi
  bool get _requiresPermissionHandling {
    return Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Verifica se siamo su Linux
  bool get _isLinux => Platform.isLinux;

  /// Verifica se siamo su Android
  bool get _isAndroid => Platform.isAndroid;

  /// Verifica se siamo su iOS
  bool get _isIOS => Platform.isIOS;

  /// Richiede tutti i permessi necessari per l'applicazione
  Future<bool> requestAllPermissions(BuildContext context) async {
    _logPermissionEvent('Inizio richiesta permessi');

    try {
      // Implementazione resiliente che non causa crash in caso di problemi
      if (_isLinux) {
        return await _handleLinuxPermissions();
      } else if (!_requiresPermissionHandling) {
        _logPermissionEvent('Piattaforma non gestita, assumo permessi OK');
        return true;
      }

      // Verifica lo stato attuale dei permessi per non richiedere quelli già concessi
      await checkAllPermissions();

      // Se i permessi sono già concessi, ritorna subito senza mostrare dialog
      if (_storagePermissionGranted && _microphonePermissionGranted) {
        _logPermissionEvent('Tutti i permessi già concessi');
        return true;
      }

      // Richiedi in modo resiliente i permessi di storage (più critico)
      if (!_storagePermissionGranted) {
        _storagePermissionGranted = await _requestStoragePermissionWithTimeout();
        _logPermissionEvent('Permesso storage: ${_storagePermissionGranted ? 'CONCESSO' : 'NEGATO'}');
      }

      // Poi richiedi il microfono
      if (!_microphonePermissionGranted) {
        _microphonePermissionGranted = await _requestMicrophonePermissionWithTimeout();
        _logPermissionEvent('Permesso microfono: ${_microphonePermissionGranted ? 'CONCESSO' : 'NEGATO'}');
      }

      // Mostra il dialogo solo se i permessi sono negati e il contesto è ancora valido
      if (!_storagePermissionGranted || !_microphonePermissionGranted) {
        if (context.mounted) {
          await _showPermissionFailureDialog(
              context,
              !_storagePermissionGranted,
              !_microphonePermissionGranted
          );
        }
      }

      // Verifica finale dei permessi
      final allGranted = await checkAllPermissions();
      _logPermissionEvent('Verifica finale permessi: ${allGranted ? 'OK' : 'NON OK'}');
      return allGranted;

    } catch (e) {
      _logPermissionEvent('Errore nella richiesta permessi: $e');
      // In caso di errore, torniamo true per non bloccare l'app
      return true;
    }
  }

  /// Richiede il permesso di storage con un timeout di sicurezza
  Future<bool> _requestStoragePermissionWithTimeout() async {
    try {
      return await PermissionsHandler.requestStoragePermission()
          .timeout(Duration(seconds: _permissionTimeout), onTimeout: () {
        _logPermissionEvent('Timeout nella richiesta permessi storage');
        return true; // Assumiamo permessi OK in caso di timeout
      });
    } catch (e) {
      _logPermissionEvent('Errore critico nella richiesta permessi storage: $e');
      return true; // Assumiamo permessi OK in caso di errore per non bloccare l'app
    }
  }

  /// Richiede il permesso del microfono con un timeout di sicurezza
  Future<bool> _requestMicrophonePermissionWithTimeout() async {
    try {
      return await PermissionsHandler.requestMicrophonePermission()
          .timeout(Duration(seconds: _permissionTimeout), onTimeout: () {
        _logPermissionEvent('Timeout nella richiesta permessi microfono');
        return true; // Assumiamo permessi OK in caso di timeout
      });
    } catch (e) {
      _logPermissionEvent('Errore critico nella richiesta permessi microfono: $e');
      return true; // Assumiamo permessi OK in caso di errore per non bloccare l'app
    }
  }

  /// Mostra un dialogo quando i permessi sono stati negati
  Future<void> _showPermissionFailureDialog(
      BuildContext context,
      bool storageNeeded,
      bool microphoneNeeded
      ) async {
    if (!context.mounted) return;

    final messages = <String>[];
    if (storageNeeded) messages.add('• Storage: necessario per salvare i dati dell\'app');
    if (microphoneNeeded) messages.add('• Microfono: necessario per le registrazioni vocali');

    if (messages.isEmpty) return;

    // Mappa dei permessi necessari in base alla piattaforma
    final Map<String, String> permissionsHelpText = {
      'android': _isAndroid ? _createAndroidPermissionsHelpText() : '',
      'ios': _isIOS ? 'Vai su Impostazioni > Privacy > Microfono / Foto.' : '',
      'linux': _isLinux ? 'Controlla i permessi di accesso ai dispositivi audio e alle cartelle.' : '',
    };

    // Filtra i testi di aiuto per mostrare solo quello della piattaforma corrente
    final platformSpecificHelp = permissionsHelpText.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.value)
        .join('\n\n');

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Permessi Mancanti',
            style: TextStyle(fontFamily: 'OpenDyslexic'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Per il corretto funzionamento dell\'app OpenDSA: Reading, sono necessari i seguenti permessi:',
                  style: TextStyle(fontFamily: 'OpenDyslexic'),
                ),
                const SizedBox(height: 16),
                ...messages.map((msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                      msg,
                      style: const TextStyle(
                          fontFamily: 'OpenDyslexic',
                          fontWeight: FontWeight.bold
                      )
                  ),
                )),
                const SizedBox(height: 16),
                Text(
                  platformSpecificHelp,
                  style: const TextStyle(
                    fontFamily: 'OpenDyslexic',
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Per modificare i permessi, vai nelle impostazioni dell\'app.',
                  style: TextStyle(
                    fontFamily: 'OpenDyslexic',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Annulla',
                style: TextStyle(fontFamily: 'OpenDyslexic'),
              ),
            ),
            TextButton(
              onPressed: () async {
                _logPermissionEvent('Apertura impostazioni app');
                try {
                  await openAppSettings();
                } catch (e) {
                  _logPermissionEvent('Errore nell\'apertura delle impostazioni: $e');
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text(
                'Apri Impostazioni',
                style: TextStyle(
                    fontFamily: 'OpenDyslexic',
                    fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Crea il testo di aiuto specifico per Android in base alla versione
  String _createAndroidPermissionsHelpText() {
    if (!_isAndroid) return '';

    final androidVersion = PermissionsHandler.getAndroidVersion();

    if (androidVersion >= 13) {
      return 'Android 13+: Vai su Impostazioni > App > OpenDSA: Reading > Autorizzazioni e concedi l\'accesso a "Foto e video" e "Microfono".';
    } else if (androidVersion >= 11) {
      return 'Android 11-12: Vai su Impostazioni > App > OpenDSA: Reading > Autorizzazioni e concedi l\'accesso allo "Storage" e al "Microfono". Potresti dover concedere anche "Gestione di tutti i file".';
    } else if (androidVersion == 10) {
      return 'Android 10: Vai su Impostazioni > App > OpenDSA: Reading > Autorizzazioni e concedi l\'accesso allo "Storage" e al "Microfono".';
    } else {
      return 'Android: Vai su Impostazioni > App > OpenDSA: Reading > Autorizzazioni e concedi l\'accesso allo "Storage" e al "Microfono".';
    }
  }

  /// Gestisce i permessi su Linux usando controlli nativi
  Future<bool> _handleLinuxPermissions() async {
    try {
      // Verifica accesso al microfono
      final micDevice = File('/dev/snd/pcmC0D0c');
      bool micAccess = false;

      if (await micDevice.exists()) {
        try {
          micAccess = await micDevice.stat().then((stat) => (stat.mode & 0x4) != 0);
        } catch (e) {
          _logPermissionEvent('Errore nel verificare i permessi del microfono: $e');
        }
      }

      // Prova anche con i dispositivi alternativi
      if (!micAccess) {
        for (final devicePath in ['/dev/dsp', '/dev/audio']) {
          final altDevice = File(devicePath);
          if (await altDevice.exists()) {
            try {
              micAccess = await altDevice.stat().then((stat) => (stat.mode & 0x4) != 0);
              if (micAccess) break;
            } catch (e) {
              // Continua a verificare altri dispositivi
            }
          }
        }
      }

      // Se ancora non abbiamo accesso, prova a controllare i gruppi dell'utente
      if (!micAccess) {
        try {
          final result = await Process.run('groups', []);
          if (result.exitCode == 0) {
            final groups = (result.stdout as String).split(' ');
            micAccess = groups.any((group) =>
                ['audio', 'pulse', 'pulse-access'].contains(group.trim()));
          }
        } catch (e) {
          _logPermissionEvent('Errore nel verificare i gruppi utente: $e');
        }
      }

      _logPermissionEvent('Linux - Accesso microfono: $micAccess');
      _microphonePermissionGranted = micAccess;

      // Verifica accesso allo storage
      final homeDir = Directory(Platform.environment['HOME'] ?? '');
      bool storageAccess = false;

      if (await homeDir.exists()) {
        try {
          storageAccess = await homeDir.stat().then((stat) => (stat.mode & 0x2) != 0);
        } catch (e) {
          _logPermissionEvent('Errore nel verificare i permessi home: $e');
        }
      }

      // Crea directory dell'app se non esiste
      try {
        // Prova diverse posizioni possibili per la directory dell'app
        final possibleDirs = [
          '${homeDir.path}/Documenti/OpenDSA',
          '${homeDir.path}/Documents/OpenDSA',
          '${homeDir.path}/.local/share/OpenDSA',
          '/tmp/OpenDSA'
        ];

        bool directoryCreated = false;

        for (final dirPath in possibleDirs) {
          try {
            final appDir = Directory(dirPath);
            if (!await appDir.exists()) {
              await appDir.create(recursive: true);
            }

            // Test di scrittura
            final testFile = File('${appDir.path}/test_permissions');
            await testFile.writeAsString('test');
            await testFile.delete();

            storageAccess = true;
            directoryCreated = true;
            _logPermissionEvent('Linux - Directory creata con successo: $dirPath');
            break;
          } catch (e) {
            _logPermissionEvent('Errore con directory $dirPath: $e');
            continue;
          }
        }

        if (!directoryCreated) {
          _logPermissionEvent('Linux - Impossibile creare/accedere a nessuna directory di app');
        }
      } catch (e) {
        _logPermissionEvent('Errore nella verifica delle directory app: $e');
      }

      _logPermissionEvent('Linux - Accesso storage: $storageAccess');
      _storagePermissionGranted = storageAccess;

      return micAccess && storageAccess;
    } catch (e) {
      _logPermissionEvent('Errore nei permessi Linux: $e');
      // In caso di errore, restituiamo true per non bloccare l'app
      return true;
    }
  }

  /// Verifica tutti i permessi necessari
  Future<bool> checkAllPermissions() async {
    _logPermissionEvent('Verifica stato permessi');

    if (_isLinux) {
      final result = await _handleLinuxPermissions();
      return result;
    }

    if (!_requiresPermissionHandling) {
      _logPermissionEvent('Piattaforma non gestita, permessi OK');
      return true;
    }

    try {
      // Verifica lo stato dei permessi usando PermissionsHandler con un timeout di sicurezza
      final hasMicrophone = await PermissionsHandler.checkMicrophonePermission()
          .timeout(Duration(seconds: _permissionTimeout), onTimeout: () {
        _logPermissionEvent('Timeout nella verifica permesso microfono, assumiamo OK');
        return true;
      });

      final hasStorage = await PermissionsHandler.checkStoragePermission()
          .timeout(Duration(seconds: _permissionTimeout), onTimeout: () {
        _logPermissionEvent('Timeout nella verifica permesso storage, assumiamo OK');
        return true;
      });

      _logPermissionEvent('Stato microfono: ${hasMicrophone ? 'CONCESSO' : 'NEGATO'}');
      _logPermissionEvent('Stato storage: ${hasStorage ? 'CONCESSO' : 'NEGATO'}');

      // Aggiorna lo stato dei permessi
      _microphonePermissionGranted = hasMicrophone;
      _storagePermissionGranted = hasStorage;

      // Entrambi i permessi sono necessari
      return hasMicrophone && hasStorage;
    } catch (e) {
      _logPermissionEvent('Errore nella verifica permessi: $e');
      // In caso di errore, restituiamo true per non bloccare l'app
      return true;
    }
  }

  /// Registra un evento nel log dei permessi
  void _logPermissionEvent(String event) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $event';
    debugPrint('PermissionService: $logEntry');
    _permissionLogs.add(logEntry);

    // Mantieni massimo 100 log
    if (_permissionLogs.length > 100) {
      _permissionLogs.removeAt(0);
    }
  }

  /// Restituisce i log dei permessi
  List<String> getPermissionLogs() => List.unmodifiable(_permissionLogs);

  /// Pulisce i log
  void clearPermissionLogs() {
    _permissionLogs.clear();
    _logPermissionEvent('Log puliti');
  }

  /// Verifica se i permessi di storage sono stati concessi
  bool get hasStoragePermission => _storagePermissionGranted;

  /// Verifica se i permessi del microfono sono stati concessi
  bool get hasMicrophonePermission => _microphonePermissionGranted;
}