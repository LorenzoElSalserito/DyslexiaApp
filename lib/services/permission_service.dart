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
    return Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS;
  }

  /// Verifica se siamo su Linux
  bool get _isLinux => Platform.isLinux;

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
      final permissions = <Permission>[
        Permission.microphone,
        Permission.storage,
      ];

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
      final storageStatus = await Permission.storage.status;

      _logPermissionEvent('Stato microfono: $micStatus');
      _logPermissionEvent('Stato storage: $storageStatus');

      return micStatus.isGranted && storageStatus.isGranted;
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
                'file di configurazione.'
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