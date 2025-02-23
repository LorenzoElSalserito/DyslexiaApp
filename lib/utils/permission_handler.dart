// lib/utils/permission_handler.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Classe che gestisce i permessi in modo cross-platform
class PermissionsHandler {
  /// Richiede il permesso per il microfono in modo sicuro su tutte le piattaforme
  static Future<bool> requestMicrophonePermission() async {
    // Su Linux restituiamo sempre true poiché i permessi sono gestiti dal sistema
    if (Platform.isLinux) {
      debugPrint('PermissionsHandler: Su Linux i permessi sono gestiti dal sistema');
      return true;
    }

    // Su altre piattaforme usiamo permission_handler normalmente
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Verifica se il permesso del microfono è stato concesso
  static Future<bool> checkMicrophonePermission() async {
    // Su Linux restituiamo sempre true
    if (Platform.isLinux) {
      debugPrint('PermissionsHandler: Su Linux i permessi sono gestiti dal sistema');
      return true;
    }

    return await Permission.microphone.isGranted;
  }

  /// Richiede il permesso di storage quando necessario
  static Future<bool> requestStoragePermission() async {
    // Su Linux restituiamo sempre true
    if (Platform.isLinux) {
      debugPrint('PermissionsHandler: Su Linux i permessi sono gestiti dal sistema');
      return true;
    }

    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Verifica se il permesso di storage è stato concesso
  static Future<bool> checkStoragePermission() async {
    // Su Linux restituiamo sempre true
    if (Platform.isLinux) {
      debugPrint('PermissionsHandler: Su Linux i permessi sono gestiti dal sistema');
      return true;
    }

    return await Permission.storage.isGranted;
  }
}