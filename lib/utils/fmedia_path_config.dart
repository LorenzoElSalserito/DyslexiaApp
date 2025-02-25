// lib/utils/fmedia_path_config.dart

import 'dart:io';
import 'package:flutter/foundation.dart';

/// Classe che aiuta a trovare il percorso dell'eseguibile fmedia su Linux.
class FmediaPathConfig {
  // Percorsi comuni dove fmedia potrebbe essere installato
  static const List<String> _commonPaths = [
    '/usr/bin/fmedia',
    '/usr/local/bin/fmedia',
    '/opt/fmedia/fmedia',
    '/usr/local/fmedia-1/fmedia',
    '/usr/local/fmedia/fmedia',
    '/snap/bin/fmedia',
  ];

  /// Nome della variabile d'ambiente per specificare il percorso di fmedia
  static const String _envVarName = 'FMEDIA_PATH';

  /// Percorso di fmedia memorizzato in cache
  static String? _cachedPath;

  /// Trova il percorso di fmedia consultando diverse fonti.
  static Future<String> findFmediaPath() async {
    // Se abbiamo già trovato fmedia, restituisci il percorso in cache
    if (_cachedPath != null) {
      return _cachedPath!;
    }

    // Controlla la variabile d'ambiente
    final envPath = Platform.environment[_envVarName];
    if (envPath != null && envPath.isNotEmpty) {
      final file = File(envPath);
      if (await file.exists()) {
        debugPrint('FmediaPathConfig: Trovato fmedia dalla variabile d\'ambiente: $envPath');
        _cachedPath = envPath;
        return envPath;
      }
    }

    // Cerca nei percorsi comuni
    for (final path in _commonPaths) {
      final file = File(path);
      if (await file.exists()) {
        debugPrint('FmediaPathConfig: Trovato fmedia in: $path');
        _cachedPath = path;
        return path;
      }
    }

    // Cerca usando il comando 'which'
    try {
      final result = await Process.run('which', ['fmedia']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty) {
          debugPrint('FmediaPathConfig: Trovato fmedia con which: $path');
          _cachedPath = path;
          return path;
        }
      }
    } catch (e) {
      debugPrint('FmediaPathConfig: Errore nell\'esecuzione di which: $e');
    }

    // Non è stato trovato fmedia
    debugPrint('FmediaPathConfig: fmedia non trovato su questo sistema');
    return '';
  }

  /// Verifica se fmedia è disponibile nel sistema
  static Future<bool> isFmediaAvailable() async {
    final path = await findFmediaPath();
    return path.isNotEmpty;
  }
}