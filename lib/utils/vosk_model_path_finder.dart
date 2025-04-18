// lib/utils/vosk_model_path_finder.dart

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

/// Classe utilitaria per trovare il percorso dei modelli VOSK in vari ambienti
/// inclusi AppImage, bundle app e dispositivi mobili.
class VoskModelPathFinder {
  /// Elenco di possibili percorsi del modello VOSK in diversi ambienti
  static const List<String> _possibleAppImagePaths = [
    '/usr/bin/data/flutter_assets/vosk',
    '/usr/share/thesis_project/vosk',
    '/data/flutter_assets/vosk',
    'vosk'
  ];

  /// Stringa da utilizzare nel debug
  static const String _kDebugTag = 'VoskModelPathFinder';

  /// Trova il percorso del modello VOSK adatto all'ambiente corrente
  static Future<String?> findModelPath() async {
    debugPrint('$_kDebugTag: Ricerca percorso del modello VOSK...');

    // Per AppImage
    if (Platform.isLinux) {
      final appImagePath = await _findAppImageModelPath();
      if (appImagePath != null) {
        debugPrint('$_kDebugTag: Percorso AppImage trovato: $appImagePath');
        return appImagePath;
      }
    }

    // Per eseguibili desktop standard
    final executablePath = Platform.resolvedExecutable;
    debugPrint('$_kDebugTag: Eseguibile risolto: $executablePath');

    final executableDir = path.dirname(executablePath);
    final dataPath = path.join(executableDir, 'data', 'flutter_assets', 'vosk');
    if (await Directory(dataPath).exists()) {
      debugPrint('$_kDebugTag: Percorso modello trovato in data/flutter_assets: $dataPath');
      return dataPath;
    }

    // Verifica percorsi bundle
    if (Platform.isMacOS || Platform.isIOS) {
      final bundlePaths = [
        path.join(executableDir, '..', 'Resources', 'flutter_assets', 'vosk'),
        path.join(executableDir, 'flutter_assets', 'vosk'),
      ];

      for (final bundlePath in bundlePaths) {
        if (await Directory(bundlePath).exists()) {
          debugPrint('$_kDebugTag: Percorso modello trovato in bundle: $bundlePath');
          return bundlePath;
        }
      }
    }

    // Ricerca nei percorsi standard
    for (final relativePath in ['vosk', 'assets/vosk']) {
      if (await Directory(relativePath).exists()) {
        final absPath = path.absolute(relativePath);
        debugPrint('$_kDebugTag: Percorso modello trovato in: $absPath');
        return absPath;
      }
    }

    debugPrint('$_kDebugTag: Nessun percorso modello trovato');
    return null;
  }

  /// Cerca specificamente i percorsi dei modelli nell'ambiente AppImage
  static Future<String?> _findAppImageModelPath() async {
    // Rileva se siamo in un ambiente AppImage
    final execPath = Platform.resolvedExecutable;
    final isAppImage = execPath.contains('.AppImage') ||
        execPath.contains('AppRun') ||
        File('/proc/self/exe').existsSync();

    if (!isAppImage) {
      debugPrint('$_kDebugTag: Non sembra essere un ambiente AppImage');
      return null;
    }

    // Tenta di trovare il percorso dell'eseguibile reale
    String appImageRoot = '';
    try {
      if (File('/proc/self/exe').existsSync()) {
        final linkTarget = await File('/proc/self/exe').resolveSymbolicLinks();
        appImageRoot = path.dirname(linkTarget);
        debugPrint('$_kDebugTag: AppImage root tramite /proc/self/exe: $appImageRoot');
      } else {
        appImageRoot = path.dirname(execPath);
        debugPrint('$_kDebugTag: AppImage root tramite Platform.resolvedExecutable: $appImageRoot');
      }
    } catch (e) {
      debugPrint('$_kDebugTag: Errore nel risolvere symlink: $e');
      appImageRoot = path.dirname(execPath);
    }

    // Cerca in tutti i possibili percorsi dell'AppImage
    for (final relativePath in _possibleAppImagePaths) {
      final fullPath = path.join(appImageRoot, relativePath);
      debugPrint('$_kDebugTag: Verifica percorso AppImage: $fullPath');

      if (await Directory(fullPath).exists()) {
        // Verifica rapida che ci sia almeno un file richiesto
        final testFile = path.join(fullPath, 'am', 'final.mdl');
        if (await File(testFile).exists()) {
          debugPrint('$_kDebugTag: Trovato modello valido in: $fullPath');
          return fullPath;
        } else {
          debugPrint('$_kDebugTag: Directory trovata ma manca final.mdl: $fullPath');
        }
      }
    }

    // Ultima risorsa: cerca in tutto il filesystem dell'AppImage
    try {
      debugPrint('$_kDebugTag: Ricerca approfondita in: $appImageRoot');

      final voskDirs = await _findDirectoriesContaining(
          Directory(appImageRoot),
          'vosk',
          ['am/final.mdl']
      );

      if (voskDirs.isNotEmpty) {
        debugPrint('$_kDebugTag: Trovata directory dopo ricerca approfondita: ${voskDirs.first}');
        return voskDirs.first;
      }
    } catch (e) {
      debugPrint('$_kDebugTag: Errore nella ricerca approfondita: $e');
    }

    return null;
  }

  /// Cerca ricorsivamente directory che contengono una determinata directory e file specifici
  static Future<List<String>> _findDirectoriesContaining(
      Directory startDir,
      String dirName,
      List<String> requiredFiles
      ) async {
    final List<String> result = [];

    try {
      await for (final entity in startDir.list(recursive: true, followLinks: false)) {
        if (entity is Directory && path.basename(entity.path) == dirName) {
          bool isValid = true;

          // Verifica che i file richiesti esistano
          for (final requiredFile in requiredFiles) {
            final file = File(path.join(entity.path, requiredFile));
            if (!await file.exists()) {
              isValid = false;
              break;
            }
          }

          if (isValid) {
            result.add(entity.path);
            // Interrompi dopo aver trovato la prima corrispondenza valida
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('$_kDebugTag: Errore nella ricerca ricorsiva: $e');
    }

    return result;
  }

  /// Verifica se un percorso VOSK è valido controllando la presenza dei file richiesti
  static Future<bool> isValidVoskPath(String voskPath) async {
    const requiredFiles = [
      'am/final.mdl',
      'conf/mfcc.conf',
      'graph/Gr.fst',
      'ivector/final.ie'
    ];

    for (final file in requiredFiles) {
      final fullPath = path.join(voskPath, file);
      if (!await File(fullPath).exists()) {
        debugPrint('$_kDebugTag: File mancante: $fullPath');
        return false;
      }
    }

    return true;
  }
}