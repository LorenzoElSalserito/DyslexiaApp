import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Classe che gestisce i permessi in modo cross-platform
class PermissionsHandler {
  /// Ottiene la versione di Android in modo sicuro
  static int? _getAndroidVersion() {
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
      debugPrint('Errore nel parsing della versione Android: $e');
      // Fallback: usa una versione predefinita che funziona con la maggior parte delle funzionalità
      return 10;
    }
  }

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

    // Per Android 13+ (API 33+) usiamo i nuovi permessi media
    if (Platform.isAndroid) {
      final androidVersion = _getAndroidVersion();
      debugPrint('Android version detected: $androidVersion');

      if (androidVersion != null && androidVersion >= 13) {
        final mediaAudio = await Permission.audio.request();
        final mediaImages = await Permission.photos.request();

        // Per Android 14 (API 34+) possiamo richiedere anche il permesso di gestione storage esterno
        if (androidVersion >= 14) {
          await Permission.manageExternalStorage.request();
        }

        return mediaAudio.isGranted && mediaImages.isGranted;
      }
    }

    // Per Android < 13 e iOS, usare i permessi dello storage tradizionali
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

    // Per Android 13+ (API 33+) usiamo i nuovi permessi media
    if (Platform.isAndroid) {
      final androidVersion = _getAndroidVersion();

      if (androidVersion != null && androidVersion >= 13) {
        final mediaAudio = await Permission.audio.isGranted;
        final mediaImages = await Permission.photos.isGranted;

        // Per Android 14 (API 34+) controlliamo anche il permesso di gestione storage esterno
        if (androidVersion >= 14) {
          final externalStorage = await Permission.manageExternalStorage.isGranted;
          return mediaAudio && mediaImages && externalStorage;
        }

        return mediaAudio && mediaImages;
      }
    }

    return await Permission.storage.isGranted;
  }

  /// Richiedi tutti i permessi in una volta
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PermissionsHandler: Desktop => permessi gestiti dal sistema');
      return {};
    }

    List<Permission> permissions = [Permission.microphone];

    // Aggiungi i permessi appropriati in base alla versione di Android
    if (Platform.isAndroid) {
      final androidVersion = _getAndroidVersion();

      if (androidVersion != null && androidVersion >= 13) {
        permissions.addAll([Permission.audio, Permission.photos]);

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

    return await permissions.request();
  }
}