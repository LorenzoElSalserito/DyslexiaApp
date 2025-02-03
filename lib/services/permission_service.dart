// lib/services/permission_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servizio centralizzato per la gestione dei permessi dell'applicazione.
/// Gestisce i permessi in modo diverso per piattaforme mobile e desktop.
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;

  final List<String> _permissionLogs = [];

  PermissionService._internal() {
    _logPermissionEvent('PermissionService inizializzato');
  }

  /// Verifica se la piattaforma corrente richiede la gestione dei permessi
  bool get _requiresPermissionHandling {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Richiede tutti i permessi necessari per l'applicazione
  Future<bool> requestAllPermissions(BuildContext context) async {
    _logPermissionEvent('Inizio richiesta permessi');

    // Su desktop, i permessi sono gestiti dal sistema operativo
    if (!_requiresPermissionHandling) {
      _logPermissionEvent('Piattaforma desktop rilevata, permessi gestiti dal sistema');
      return true;
    }

    try {
      final permissions = [Permission.microphone, Permission.storage];

      _logPermissionEvent('Verifica permessi su piattaforma mobile');

      for (var permission in permissions) {
        final status = await permission.status;
        _logPermissionEvent('Stato corrente ${permission.toString()}: ${status.toString()}');

        if (status.isDenied) {
          _logPermissionEvent('Richiesta ${permission.toString()}');
          final result = await permission.request();
          _logPermissionEvent('Risultato richiesta: ${result.toString()}');

          if (result.isPermanentlyDenied && context.mounted) {
            _logPermissionEvent('Permesso negato permanentemente');
            await _showPermissionDialog(context, permission);
          }
        }
      }

      final allGranted = await checkAllPermissions();
      _logPermissionEvent('Verifica finale permessi: ${allGranted ? 'OK' : 'NON OK'}');

      return allGranted;
    } catch (e) {
      _logPermissionEvent('Errore nella richiesta permessi: $e');
      return false;
    }
  }

  /// Verifica lo stato di tutti i permessi necessari
  Future<bool> checkAllPermissions() async {
    _logPermissionEvent('Verifica stato permessi');

    // Su desktop, assumiamo che i permessi siano gestiti dal sistema
    if (!_requiresPermissionHandling) {
      _logPermissionEvent('Piattaforma desktop, permessi gestiti dal sistema');
      return true;
    }

    try {
      final micStatus = await Permission.microphone.status;
      final storageStatus = await Permission.storage.status;

      _logPermissionEvent('Stato microfono: ${micStatus.toString()}');
      _logPermissionEvent('Stato storage: ${storageStatus.toString()}');

      return micStatus.isGranted && storageStatus.isGranted;
    } catch (e) {
      _logPermissionEvent('Errore nella verifica permessi: $e');
      return false;
    }
  }

  /// Mostra un dialogo informativo per i permessi negati
  Future<void> _showPermissionDialog(BuildContext context, Permission permission) async {
    if (!_requiresPermissionHandling) return;

    _logPermissionEvent('Mostro dialogo per ${permission.toString()}');

    String permissionName = '';
    String explanation = '';

    switch (permission) {
      case Permission.microphone:
        permissionName = 'Microfono';
        explanation = 'Il microfono è necessario per il riconoscimento vocale durante gli esercizi di lettura.';
      case Permission.storage:
        permissionName = 'Storage';
        explanation = 'L\'accesso allo storage è necessario per salvare i file di configurazione.';
      default:
        permissionName = 'Richiesto';
        explanation = 'Questo permesso è necessario per il funzionamento dell\'app.';
    }

    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Permesso $permissionName Necessario',
              style: const TextStyle(fontFamily: 'OpenDyslexic'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  explanation,
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
                child: const Text(
                  'Apri Impostazioni',
                  style: TextStyle(fontFamily: 'OpenDyslexic'),
                ),
                onPressed: () async {
                  _logPermissionEvent('Apertura impostazioni');
                  await openAppSettings();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        },
      );
    }
  }

  /// Registra un evento nel log dei permessi
  void _logPermissionEvent(String event) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $event';
    print('PermissionService: $logEntry');
    _permissionLogs.add(logEntry);

    if (_permissionLogs.length > 100) {
      _permissionLogs.removeAt(0);
    }
  }

  /// Ottiene i log degli eventi dei permessi
  List<String> getPermissionLogs() => List.unmodifiable(_permissionLogs);

  /// Pulisce i log degli eventi
  void clearPermissionLogs() {
    _permissionLogs.clear();
    _logPermissionEvent('Log puliti');
  }
}