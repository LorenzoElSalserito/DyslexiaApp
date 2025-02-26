// lib/services/permission_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Importa permission_handler solo su piattaforme non Linux
import 'package:permission_handler/permission_handler.dart'
if (dart.library.io) 'package:permission_handler/permission_handler.dart'
if (dart.library.html) 'package:permission_handler/permission_handler.dart';

/// Servizio centralizzato per la gestione dei permessi dell'applicazione.
/// Gestisce i permessi in modo diverso per ogni piattaforma supportata:
/// - Android/iOS: Usa permission_handler
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

  PermissionService._internal() {
    _logPermissionEvent('PermissionService inizializzato');
  }

  /// Determina se la piattaforma richiede gestione esplicita dei permessi
  bool get _requiresPermissionHandling {
    return Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// Verifica se siamo su Linux
  bool get _isLinux => Platform.isLinux;

  /// Ottiene la versione di Android in modo sicuro
  int? _getAndroidVersion() {
    if (!Platform.isAndroid) return null;

    try {
      // Platform.operatingSystemVersion può contenere altre informazioni oltre alla versione
      // Es. "EML-L09 10" invece di solo "10"
      final versionString = Platform.operatingSystemVersion;

      // Prima prova a estrarre gli ultimi numeri dalla stringa
      final regexMatch = RegExp(r'(\d+)(?:\s*$|\s*\.|$)').firstMatch(versionString);
      if (regexMatch != null && regexMatch.group(1) != null) {
        return int.parse(regexMatch.group(1)!);
      }

      // Se il regex fallisce, estrai tutti i numeri e prendi il più grande
      // (logica: la versione di Android è probabilmente il numero più grande nella stringa)
      final allNumbers = RegExp(r'\d+').allMatches(versionString).map((m) => int.parse(m.group(0)!)).toList();
      if (allNumbers.isNotEmpty) {
        return allNumbers.reduce((a, b) => a > b ? a : b);
      }

      // Fallback: Android 10 è abbastanza comune e compatibile con la maggior parte delle funzionalità
      return 10;
    } catch (e) {
      _logPermissionEvent('Errore nel parsing della versione Android: $e');
      // Fallback: usa una versione predefinita che funziona con la maggior parte delle funzionalità
      return 10;
    }
  }

  /// Richiede tutti i permessi necessari per l'applicazione
  Future<bool> requestAllPermissions(BuildContext context) async {
    _logPermissionEvent('Inizio richiesta permessi');

    try {
      if (_isLinux) {
        return await _handleLinuxPermissions();
      } else if (!_requiresPermissionHandling) {
        _logPermissionEvent('Piattaforma non gestita, assumo permessi OK');
        return true;
      }

      // Lista dei permessi da richiedere
      var permissions = <Permission>[
        Permission.microphone,
      ];

      // Aggiungi i permessi di storage appropriati in base alla versione di Android
      if (Platform.isAndroid) {
        // Ottieni la versione di Android in modo sicuro
        int? androidVersion = _getAndroidVersion();
        _logPermissionEvent('Versione Android rilevata: $androidVersion');

        if (androidVersion != null && androidVersion >= 13) {
          permissions.add(Permission.audio);
          permissions.add(Permission.photos);

          if (androidVersion >= 14) {
            permissions.add(Permission.manageExternalStorage);
          }
        } else {
          permissions.add(Permission.storage);
        }
      } else if (Platform.isIOS) {
        permissions.add(Permission.storage);
        permissions.add(Permission.photos);
      }

      _logPermissionEvent('Verifica permessi su ${Platform.operatingSystem}');

      // Richiedi ogni permesso necessario
      for (final permission in permissions) {
        await _handlePermissionRequest(context, permission);
      }

      // Verifica finale
      final allGranted = await checkAllPermissions();
      _logPermissionEvent('Verifica finale permessi: ${allGranted ? 'OK' : 'NON OK'}');
      return allGranted;

    } catch (e) {
      _logPermissionEvent('Errore nella richiesta permessi: $e');
      return false;
    }
  }

  /// Gestisce la richiesta di un singolo permesso
  Future<void> _handlePermissionRequest(BuildContext context, Permission permission) async {
    final status = await permission.status;
    _logPermissionEvent('Stato corrente $permission: $status');

    if (status.isDenied) {
      _logPermissionEvent('Richiesta permesso $permission');
      final result = await permission.request();
      _logPermissionEvent('Risultato richiesta: $result');

      if (result.isPermanentlyDenied && context.mounted) {
        _logPermissionEvent('Permesso negato permanentemente per $permission');
        await _showPermissionDialog(context, permission);
      }
    }
  }

  /// Gestisce i permessi su Linux usando controlli nativi
  Future<bool> _handleLinuxPermissions() async {
    try {
      // Verifica accesso al microfono
      final micDevice = File('/dev/snd/pcmC0D0c');
      final micAccess = await micDevice.exists() &&
          await micDevice.stat().then((stat) =>
          (stat.mode & 0x4) != 0);

      // Verifica accesso allo storage
      final homeDir = Directory(Platform.environment['HOME'] ?? '');
      final storageAccess = await homeDir.exists() &&
          await homeDir.stat().then((stat) =>
          (stat.mode & 0x2) != 0);

      // Crea directory dell'app se non esiste
      try {
        final appDir = Directory('${homeDir.path}/Documenti/OpenDSA');
        if (!await appDir.exists()) {
          await appDir.create(recursive: true);
        }

        // Test di scrittura
        final testFile = File('${appDir.path}/test_permissions');
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        _logPermissionEvent('Errore nella verifica delle directory app: $e');
        return false;
      }

      _logPermissionEvent('Linux - Microfono: $micAccess, Storage: $storageAccess');
      return micAccess && storageAccess;

    } catch (e) {
      _logPermissionEvent('Errore nei permessi Linux: $e');
      return false;
    }
  }

  /// Verifica tutti i permessi necessari
  Future<bool> checkAllPermissions() async {
    _logPermissionEvent('Verifica stato permessi');

    if (_isLinux) {
      return _handleLinuxPermissions();
    }

    if (!_requiresPermissionHandling) {
      _logPermissionEvent('Piattaforma non gestita, permessi OK');
      return true;
    }

    try {
      final micStatus = await Permission.microphone.status;

      List<PermissionStatus> storageStatuses = [];

      // Verifica permessi storage in base alla versione Android
      if (Platform.isAndroid) {
        // Ottieni la versione di Android in modo sicuro
        int? androidVersion = _getAndroidVersion();
        _logPermissionEvent('Versione Android rilevata: $androidVersion');

        if (androidVersion != null && androidVersion >= 13) {
          storageStatuses.add(await Permission.audio.status);
          storageStatuses.add(await Permission.photos.status);

          if (androidVersion >= 14) {
            storageStatuses.add(await Permission.manageExternalStorage.status);
          }
        } else {
          storageStatuses.add(await Permission.storage.status);
        }
      } else if (Platform.isIOS) {
        storageStatuses.add(await Permission.storage.status);
        storageStatuses.add(await Permission.photos.status);
      }

      _logPermissionEvent('Stato microfono: $micStatus');
      _logPermissionEvent('Stato storage: $storageStatuses');

      // Controlla che almeno il microfono e uno dei permessi di storage siano concessi
      bool storageGranted = storageStatuses.any((status) => status.isGranted);

      return micStatus.isGranted && storageGranted;
    } catch (e) {
      _logPermissionEvent('Errore nella verifica permessi: $e');
      return false;
    }
  }

  /// Mostra un dialogo quando un permesso viene negato permanentemente
  Future<void> _showPermissionDialog(BuildContext context, Permission permission) async {
    if (_isLinux) return;  // Non necessario su Linux

    _logPermissionEvent('Mostro dialogo per $permission');

    final permissionDetails = _getPermissionDetails(permission);

    if (context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(
              'Permesso ${permissionDetails.name} Necessario',
              style: const TextStyle(fontFamily: 'OpenDyslexic'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permissionDetails.explanation,
                  style: const TextStyle(fontFamily: 'OpenDyslexic'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Per abilitare il permesso, vai nelle impostazioni.',
                  style: TextStyle(
                    fontFamily: 'OpenDyslexic',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  _logPermissionEvent('Apertura impostazioni');
                  if (!_isLinux) {
                    await openAppSettings();
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text(
                  'Apri Impostazioni',
                  style: TextStyle(fontFamily: 'OpenDyslexic'),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  /// Ottiene i dettagli per un tipo di permesso
  _PermissionDetails _getPermissionDetails(Permission permission) {
    switch (permission) {
      case Permission.microphone:
        return _PermissionDetails(
            name: 'Microfono',
            explanation: 'Il microfono è necessario per il riconoscimento vocale '
                'durante gli esercizi di lettura.'
        );
      case Permission.storage:
        return _PermissionDetails(
            name: 'Storage',
            explanation: 'L\'accesso allo storage è necessario per salvare i '
                'file di configurazione e le registrazioni audio.'
        );
      case Permission.audio:
        return _PermissionDetails(
            name: 'File Audio',
            explanation: 'L\'accesso ai file audio è necessario per salvare e '
                'gestire le registrazioni degli esercizi.'
        );
      case Permission.photos:
        return _PermissionDetails(
            name: 'Foto e Media',
            explanation: 'L\'accesso ai media è necessario per salvare i '
                'file di configurazione e le registrazioni audio.'
        );
      case Permission.manageExternalStorage:
        return _PermissionDetails(
            name: 'Gestione Storage',
            explanation: 'La gestione completa dello storage è necessaria per '
                'salvare e gestire i file dell\'applicazione.'
        );
      default:
        return _PermissionDetails(
            name: 'Richiesto',
            explanation: 'Questo permesso è necessario per il corretto '
                'funzionamento dell\'app.'
        );
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
}

/// Classe interna per i dettagli dei permessi
class _PermissionDetails {
  final String name;
  final String explanation;

  const _PermissionDetails({
    required this.name,
    required this.explanation,
  });
}