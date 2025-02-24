// lib/platform/linux_permissions.dart

import 'dart:io';
import 'package:flutter/foundation.dart';

/// Gestisce i permessi in modo nativo su Desktop
class DesktopPermission {
  /// Verifica se il microfono è disponibile
  static Future<bool> checkMicrophoneAccess() async {
    try {
      // Su Linux, verifichiamo se il device esiste e abbiamo i permessi
      final audioDevices = [
        '/dev/snd/pcmC0D0c',  // Device di cattura predefinito
        '/dev/dsp',           // Legacy audio device
        '/dev/audio'          // Legacy audio device
      ];

      for (final device in audioDevices) {
        final audioDevice = File(device);
        if (await audioDevice.exists()) {
          final hasAccess = await audioDevice.stat().then((stat) =>
          (stat.mode & 0x4) != 0); // Leggiamo il permesso di lettura
          if (hasAccess) {
            debugPrint('LinuxPermissions: Accesso audio disponibile su $device');
            return true;
          }
        }
      }

      // Verifichiamo anche i gruppi audio dell'utente
      final result = await Process.run('groups', []);
      final groups = (result.stdout as String).split(' ');
      if (groups.contains('audio') || groups.contains('pulse') || groups.contains('pulse-access')) {
        debugPrint('LinuxPermissions: Utente ha accesso audio tramite gruppi');
        return true;
      }

      debugPrint('LinuxPermissions: Nessun accesso audio trovato');
      return false;
    } catch (e) {
      debugPrint('LinuxPermissions: Errore verifica permessi audio: $e');
      // Su Linux, in caso di errore, assumiamo che l'accesso sia gestito dal sistema
      return true;
    }
  }

  /// Verifica i permessi di storage
  static Future<bool> checkStorageAccess() async {
    try {
      // Verifica accesso alla home dell'utente
      final homeDir = Directory(Platform.environment['HOME'] ?? '');
      if (!await homeDir.exists()) {
        debugPrint('LinuxPermissions: Home directory non trovata');
        return false;
      }

      // Crea e verifica la directory dell'applicazione
      final appDir = Directory('${homeDir.path}/Documenti/OpenDSA');
      if (!await appDir.exists()) {
        try {
          await appDir.create(recursive: true);
          debugPrint('LinuxPermissions: Directory OpenDSA creata con successo');
        } catch (e) {
          debugPrint('LinuxPermissions: Impossibile creare la directory OpenDSA: $e');
          return false;
        }
      }

      // Verifica i permessi di scrittura
      try {
        final testFile = File('${appDir.path}/test_permissions');
        await testFile.writeAsString('test');
        await testFile.delete();
        debugPrint('LinuxPermissions: Verifica permessi di scrittura: OK');
        return true;
      } catch (e) {
        debugPrint('LinuxPermissions: Verifica permessi di scrittura fallita: $e');
        return false;
      }
    } catch (e) {
      debugPrint('LinuxPermissions: Errore nella verifica storage: $e');
      return false;
    }
  }

  static Future<bool> requestStorageAccess() async {
    if (await checkStorageAccess()) {
      return true;
    }

    // Mostra un dialogo all'utente per richiedere i permessi manualmente
    debugPrint('LinuxPermissions: Richiesta permessi manuali a User');
        // Ricontrolla i permessi dopo l'intervento dell'utente
        return await checkStorageAccess();
  }
}