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

  /// Verifica se la piattaforma corrente richiede la gestione dei permessi.
  /// In questo caso, solo Android o iOS.
  bool get _requiresPermissionHandling {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Richiede tutti i permessi necessari per l'applicazione (solo Android/iOS).
  Future<bool> requestAllPermissions(BuildContext context) async {
    _logPermissionEvent('Inizio richiesta permessi');

    // Su desktop (Linux, macOS, Windows) e altre piattaforme, i permessi sono
    // gestiti dal sistema operativo o non necessari. Quindi si esce subito.
    if (!_requiresPermissionHandling) {
      _logPermissionEvent('Piattaforma non mobile, skip richiesta permessi');
      return true;
    }

    try {
      // Permessi da richiedere su Android/iOS (adatta se ti servono altri).
      final permissions = <Permission>[
        Permission.microphone,
        Permission.storage,
      ];

      _logPermissionEvent('Verifica permessi su piattaforma mobile');

      // Controlla uno per uno lo stato dei permessi e, se negati, richiedili.
      for (final permission in permissions) {
        final status = await permission.status;
        _logPermissionEvent('Stato corrente $permission: $status');

        if (status.isDenied) {
          _logPermissionEvent('Richiesta permesso $permission');
          final result = await permission.request();
          _logPermissionEvent('Risultato richiesta: $result');

          // Se l’utente ha negato in modo permanente, mostriamo un dialog
          // con l’opzione di aprire le impostazioni.
          if (result.isPermanentlyDenied && context.mounted) {
            _logPermissionEvent('Permesso negato permanentemente per $permission');
            await _showPermissionDialog(context, permission);
          }
        }
      }

      // Dopo la richiesta, controlliamo se tutti i permessi sono ora concessi.
      final allGranted = await checkAllPermissions();
      _logPermissionEvent('Verifica finale permessi: ${allGranted ? 'OK' : 'NON OK'}');

      return allGranted;
    } catch (e) {
      _logPermissionEvent('Errore nella richiesta permessi: $e');
      return false;
    }
  }

  /// Verifica lo stato di tutti i permessi necessari (solo Android/iOS).
  Future<bool> checkAllPermissions() async {
    _logPermissionEvent('Verifica stato permessi');

    // Su desktop e altre piattaforme, assumiamo che non ci sia nulla da gestire.
    if (!_requiresPermissionHandling) {
      _logPermissionEvent('Piattaforma non mobile, permessi gestiti dal sistema');
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

  /// Mostra un dialogo informativo se un permesso è stato negato permanentemente.
  Future<void> _showPermissionDialog(BuildContext context, Permission permission) async {
    // Su piattaforme non mobile, non facciamo nulla.
    if (!_requiresPermissionHandling) return;

    _logPermissionEvent('Mostro dialogo per $permission');

    String permissionName;
    String explanation;

    switch (permission) {
      case Permission.microphone:
        permissionName = 'Microfono';
        explanation = 'Il microfono è necessario per il riconoscimento vocale '
            'durante gli esercizi di lettura.';
        break;
      case Permission.storage:
        permissionName = 'Storage';
        explanation = 'L\'accesso allo storage è necessario per salvare i '
            'file di configurazione.';
        break;
      default:
        permissionName = 'Richiesto';
        explanation = 'Questo permesso è necessario per il corretto '
            'funzionamento dell\'app.';
    }

    // Se la pagina è ancora montata, mostriamo il dialogo.
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
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
                onPressed: () async {
                  _logPermissionEvent('Apertura impostazioni');
                  await openAppSettings();
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

  /// Registra un evento nel log dei permessi (con timestamp).
  void _logPermissionEvent(String event) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $event';
    debugPrint('PermissionService: $logEntry');
    _permissionLogs.add(logEntry);

    // Mantieni la dimensione dei log entro 100 entry.
    if (_permissionLogs.length > 100) {
      _permissionLogs.removeAt(0);
    }
  }

  /// Restituisce una copia immutabile del log dei permessi.
  List<String> getPermissionLogs() => List.unmodifiable(_permissionLogs);

  /// Pulisce i log degli eventi.
  void clearPermissionLogs() {
    _permissionLogs.clear();
    _logPermissionEvent('Log puliti');
  }
}
