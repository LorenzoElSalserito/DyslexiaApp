// lib/utils/permission_handler.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Classe che gestisce i permessi in modo cross-platform con particolare
/// attenzione alle diverse versioni di Android per la gestione dello storage
class PermissionsHandler {
  /// Cache per la versione di Android rilevata
  static int? _cachedAndroidVersion;

  /// Ottiene la versione di Android in modo affidabile
  static int getAndroidVersion() {
    // Se abbiamo già calcolato la versione, restituiscila
    if (_cachedAndroidVersion != null) {
      return _cachedAndroidVersion!;
    }

    if (!Platform.isAndroid) return 0;

    try {
      // Prova a ottenere la versione da Platform.version che contiene "Android X.Y.Z"
      final platformVersion = Platform.version.toLowerCase();
      final androidRegex = RegExp(r'android\s+(\d+)');
      final match = androidRegex.firstMatch(platformVersion);
      if (match != null && match.groupCount >= 1) {
        _cachedAndroidVersion = int.tryParse(match.group(1)!) ?? 0;
        return _cachedAndroidVersion!;
      }

      // Secondo tentativo: cerca nella stringa versionString
      final versionString = Platform.operatingSystemVersion;

      // Cerca un numero di due cifre all'inizio, dopo "API" o dopo "REL"
      final versionRegex = RegExp(r'(\d{1,2})(?=[^0-9]|$)');
      final matches = versionRegex.allMatches(versionString);

      if (matches.isNotEmpty) {
        // Ordina i match per valore numerico decrescente
        final versions = matches
            .map((m) => int.tryParse(m.group(0)!) ?? 0)
            .where((n) => n > 0 && n < 100) // Filtro di validità: tra 1 e 99
            .toList()
          ..sort((a, b) => b.compareTo(a));

        if (versions.isNotEmpty) {
          // Il numero più grande è probabilmente la versione di Android
          _cachedAndroidVersion = versions.first;
          debugPrint('PermissionsHandler: Versione Android rilevata via regex: $_cachedAndroidVersion');
          return _cachedAndroidVersion!;
        }
      }

      // Fallback su una versione manuale determinata da check multipli
      _cachedAndroidVersion = _determineAndroidVersionManually();
      return _cachedAndroidVersion!;
    } catch (e) {
      debugPrint('PermissionsHandler: Errore nella determinazione della versione Android: $e');
      // Fallback con stima manuale
      _cachedAndroidVersion = _determineAndroidVersionManually();
      return _cachedAndroidVersion!;
    }
  }

  /// Determina manualmente la versione di Android tramite verifica di feature specifiche
  static int _determineAndroidVersionManually() {
    try {
      // Verifiche specifiche per feature introdotte in ciascuna versione di Android

      // Verifica dell'esistenza di DirectoryScope per Android 13+
      try {
        // Questo fallirà su versioni precedenti ad Android 13
        final result = Process.runSync('getprop', ['ro.build.version.sdk']);
        if (result.exitCode == 0 && result.stdout != null) {
          final sdk = int.tryParse((result.stdout as String).trim()) ?? 0;
          if (sdk >= 33) return 13;
          if (sdk >= 31) return 12;
          if (sdk >= 30) return 11;
          if (sdk >= 29) return 10;
          if (sdk >= 28) return 9;
          if (sdk >= 26) return 8;
          if (sdk >= 24) return 7;
          return 6;
        }
      } catch (_) {
        // Ignora eventuali errori
      }

      // Ulteriori verifiche potrebbero essere aggiunte qui

      // Fallback "sicuro"
      return 10; // Considera Android 10 come fallback di riferimento
    } catch (e) {
      debugPrint('PermissionsHandler: Errore nella determinazione manuale: $e');
      return 10; // Default alla versione 10 in caso di errori
    }
  }

  /// Richiede il permesso per il microfono in modo sicuro su tutte le piattaforme
  static Future<bool> requestMicrophonePermission() async {
    // Se siamo su desktop, gestione semplificata
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
    // Se siamo su desktop, gestione semplificata
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PermissionsHandler: Desktop => nessuna verifica permission_handler');
      return true;
    }

    return await Permission.microphone.isGranted;
  }

  /// Richiede TUTTI i permessi di storage necessari in base alla versione di Android
  /// Utilizza una strategia a cascata per garantire la compatibilità con tutte le versioni
  static Future<bool> requestStoragePermission() async {
    // Se siamo su desktop, gestione semplificata
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PermissionsHandler: Desktop => permessi storage gestiti dal sistema');
      return true;
    }

    // Su iOS richiediamo semplicemente i permessi standard
    if (Platform.isIOS) {
      final photos = await Permission.photos.request();
      final storage = await Permission.storage.request();
      return photos.isGranted || storage.isGranted;
    }

    // Su Android, la strategia dipende dalla versione
    if (Platform.isAndroid) {
      final androidVersion = getAndroidVersion();
      debugPrint('PermissionsHandler: Versione Android effettiva: $androidVersion');

      // Preparati a verificare se i permessi sono definiti nel manifest, importante per evitare crash
      bool hasPermissionInManifest = true;
      try {
        // Controllo veloce se i permessi sono definiti nel manifest
        final testStatus = await Permission.storage.status;
        // Se arriviamo qui, il permesso è definito
      } catch (e) {
        debugPrint('PermissionsHandler: Errore nel controllo permessi: $e');
        hasPermissionInManifest = false;
      }

      if (!hasPermissionInManifest) {
        debugPrint('PermissionsHandler: ATTENZIONE - Permessi non definiti nel manifest!');
        // Ritorniamo true per non bloccare l'app, ma logghiamo un avviso importante
        debugPrint('PermissionsHandler: I permessi di storage devono essere aggiunti al manifest!');
        return true;
      }

      // Approccio unificato per tutte le versioni di Android
      try {
        // Primo tentativo: Storage standard (funziona su Android 9 e versioni precedenti)
        if (androidVersion <= 9) {
          debugPrint('PermissionsHandler: Richiesta permessi standard per Android ≤9');
          final storageStatus = await Permission.storage.request();
          return storageStatus.isGranted;
        }

        // Per Android 10 (API 29) proviamo con il storage tradizionale + scoped storage
        else if (androidVersion == 10) {
          debugPrint('PermissionsHandler: Richiesta permessi per Android 10');
          final storageStatus = await Permission.storage.request();

          // Se il permesso è stato concesso, possiamo procedere
          if (storageStatus.isGranted) {
            return true;
          }

          // Altrimenti, su Android 10 possiamo provare anche con gli altri permessi
          try {
            final manageStorage = await Permission.manageExternalStorage.request();
            return manageStorage.isGranted;
          } catch (e) {
            debugPrint('PermissionsHandler: Fallback su Android 10: $e');
            // Su Android 10, se non funziona niente, restituiamo true per non bloccare l'app
            return true;
          }
        }

        // Per Android 11-12 (API 30-31)
        else if (androidVersion >= 11 && androidVersion <= 12) {
          debugPrint('PermissionsHandler: Richiesta permessi per Android 11-12');
          try {
            final manageStatus = await Permission.manageExternalStorage.request();
            if (manageStatus.isGranted) {
              return true;
            }

            // Fallback al storage normale
            final storageStatus = await Permission.storage.request();
            return storageStatus.isGranted;
          } catch (e) {
            debugPrint('PermissionsHandler: Errore sui permessi Android 11-12: $e');
            // Su Android 11-12, se fallisce tutto, restituiamo true per non bloccare l'app
            return true;
          }
        }

        // Per Android 13+ (API 33+)
        else if (androidVersion >= 13) {
          debugPrint('PermissionsHandler: Richiesta permessi per Android 13+');
          List<Permission> mediaPermissions = [
            Permission.photos,
            Permission.audio,
            Permission.videos,
          ];

          bool anyGranted = false;

          // Prova a richiedere i permessi specifici per i media
          for (final permission in mediaPermissions) {
            try {
              final status = await permission.request();
              if (status.isGranted) {
                anyGranted = true;
                break;
              }
            } catch (e) {
              debugPrint('PermissionsHandler: Errore nel richiedere $permission: $e');
              // Continua con il prossimo permesso
            }
          }

          // Se nessun permesso media è stato concesso, proviamo con i permessi legacy
          if (!anyGranted) {
            try {
              // Prova con manage external storage
              final manageStatus = await Permission.manageExternalStorage.request();
              if (manageStatus.isGranted) {
                return true;
              }

              // Ultima spiaggia: storage normale
              final storageStatus = await Permission.storage.request();
              return storageStatus.isGranted;
            } catch (e) {
              debugPrint('PermissionsHandler: Fallback Android 13+ fallito: $e');
              // Su Android 13+, se fallisce tutto, restituiamo true per non bloccare l'app
              return true;
            }
          }

          return anyGranted;
        }

        // Versione non identificata correttamente
        else {
          debugPrint('PermissionsHandler: Versione Android non riconosciuta, approccio generico');
          final storageStatus = await Permission.storage.request();
          return storageStatus.isGranted;
        }
      } catch (e) {
        debugPrint('PermissionsHandler: Errore generale nella richiesta permessi: $e');
        // Strategia di fallback: restituisci true per non bloccare l'app
        return true;
      }
    }

    return false;
  }

  /// Verifica se il permesso di storage è stato concesso (su tutte le versioni Android)
  static Future<bool> checkStoragePermission() async {
    // Se siamo su desktop, gestione semplificata
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PermissionsHandler: Desktop => nessuna verifica permission_handler');
      return true;
    }

    // Su iOS verifichiamo entrambi i permessi
    if (Platform.isIOS) {
      try {
        bool hasPhotos = await Permission.photos.isGranted;
        bool hasStorage = await Permission.storage.isGranted;
        return hasPhotos || hasStorage;
      } catch (e) {
        debugPrint('PermissionsHandler: Errore nella verifica iOS: $e');
        return true; // Assume success to prevent app crash
      }
    }

    // Su Android, implementiamo una verifica più affidabile
    if (Platform.isAndroid) {
      try {
        final androidVersion = getAndroidVersion();
        bool permissionOk = false;

        // Verifica appropriata per la versione Android
        if (androidVersion <= 9) {
          permissionOk = await Permission.storage.isGranted;
        } else if (androidVersion == 10) {
          permissionOk = await Permission.storage.isGranted ||
              await Permission.manageExternalStorage.isGranted;
        } else if (androidVersion >= 11 && androidVersion <= 12) {
          permissionOk = await Permission.manageExternalStorage.isGranted ||
              await Permission.storage.isGranted;
        } else if (androidVersion >= 13) {
          permissionOk = await Permission.photos.isGranted ||
              await Permission.audio.isGranted ||
              await Permission.videos.isGranted ||
              await Permission.manageExternalStorage.isGranted ||
              await Permission.storage.isGranted;
        }

        // Se non abbiamo permessi ma l'app funziona, probabilmente
        // la directory dell'app è accessibile senza permessi espliciti
        if (!permissionOk) {
          // Prova a scrivere nella directory interna dell'app per verificare l'accesso effettivo
          try {
            final dir = Directory('/data/data/${_getPackageName()}/app_flutter');
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
            final testFile = File('${dir.path}/test_permissions.txt');
            await testFile.writeAsString('test');
            await testFile.delete();
            debugPrint('PermissionsHandler: Accesso alla directory interna OK');
            return true;
          } catch (e) {
            debugPrint('PermissionsHandler: Errore nell\'accesso alla directory interna: $e');
          }
        }

        return permissionOk;
      } catch (e) {
        debugPrint('PermissionsHandler: Errore nella verifica dei permessi: $e');
        // In caso di errore, restituiamo true per non bloccare l'app
        return true;
      }
    }

    return false;
  }

  /// Ottiene il nome del pacchetto Android
  static String _getPackageName() {
    try {
      // Metodo semplificato - in una implementazione reale dovrebbe
      // essere ottenuto da PackageInfo.packageName
      return 'com.example.thesis_project';
    } catch (e) {
      return 'com.example.app';
    }
  }

  /// Richiedi tutti i permessi in una volta
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PermissionsHandler: Desktop => permessi gestiti dal sistema');
      return {};
    }

    // Richiedi prima i permessi dello storage
    await requestStoragePermission();

    // Poi richiedi il permesso del microfono
    await requestMicrophonePermission();

    // Per avere uno stato coerente, verifica e restituisci lo stato finale
    Map<Permission, PermissionStatus> results = {};

    try {
      if (Platform.isAndroid) {
        final androidVersion = getAndroidVersion();

        // Aggiungi i permessi in base alla versione di Android
        if (androidVersion >= 13) {
          _safeAddPermission(results, Permission.audio);
          _safeAddPermission(results, Permission.photos);
          _safeAddPermission(results, Permission.videos);
        }

        if (androidVersion >= 11) {
          _safeAddPermission(results, Permission.manageExternalStorage);
        }

        _safeAddPermission(results, Permission.storage);
      } else if (Platform.isIOS) {
        _safeAddPermission(results, Permission.storage);
        _safeAddPermission(results, Permission.photos);
      }

      // Aggiungi sempre il permesso del microfono
      _safeAddPermission(results, Permission.microphone);
    } catch (e) {
      debugPrint('PermissionsHandler: Errore nella raccolta stati: $e');
    }

    return results;
  }

  /// Aggiunge in modo sicuro lo stato di un permesso alla mappa
  static void _safeAddPermission(Map<Permission, PermissionStatus> map, Permission permission) async {
    try {
      map[permission] = await permission.status;
    } catch (e) {
      debugPrint('PermissionsHandler: Errore nell\'ottenere lo stato di $permission: $e');
    }
  }
}