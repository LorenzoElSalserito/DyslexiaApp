import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Classe che gestisce i permessi in modo cross-platform
class PermissionsHandler {
  /// Richiede il permesso per il microfono in modo sicuro su tutte le piattaforme
  static Future<bool> requestMicrophonePermission() async {
    // Se siamo su desktop (Linux, Windows, macOS), gestisci tu i permessi
    // oppure restituisci true se non vuoi bloccare l'uso.
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PermissionsHandler: Desktop => permessi microfono gestiti dal sistema');
      return true;
    }

    // Su Android/iOS usiamo permission_handler normalmente
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Verifica se il permesso del microfono è stato concesso
  static Future<bool> checkMicrophonePermission() async {
    // Se siamo su desktop (Linux, Windows, macOS), gestisci tu i permessi
    // oppure restituisci true.
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PermissionsHandler: Desktop => nessuna verifica permission_handler');
      return true;
    }

    return await Permission.microphone.isGranted;
  }

  /// Richiede il permesso di storage quando necessario
  static Future<bool> requestStoragePermission() async {
    // Se siamo su desktop, gestisci tu i permessi o restituisci true.
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PermissionsHandler: Desktop => permessi storage gestiti dal sistema');
      return true;
    }

    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Verifica se il permesso di storage è stato concesso
  static Future<bool> checkStoragePermission() async {
    // Se siamo su desktop, gestisci tu i permessi o restituisci true.
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PermissionsHandler: Desktop => nessuna verifica permission_handler');
      return true;
    }

    return await Permission.storage.isGranted;
  }
}
