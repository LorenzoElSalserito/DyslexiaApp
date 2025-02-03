import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../config/app_config.dart';

/// Servizio per la gestione della cache del modello di riconoscimento vocale.
/// Implementa meccanismi di caching, verifica e pulizia dei modelli VOSK.
class ModelCacheService {
  static const String _cacheFileName = 'model_cache_info.json';
  static ModelCacheService? _instance;

  /// Implementazione del pattern Singleton per garantire un'unica istanza del servizio
  static ModelCacheService get instance {
    _instance ??= ModelCacheService._();
    return _instance!;
  }

  ModelCacheService._();

  /// Ottiene il percorso della directory di cache per i modelli
  Future<String> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/model_cache';
  }

  /// Ottiene il file che contiene le informazioni di cache
  Future<File> get _cacheFile async {
    final dir = await _cacheDir;
    return File('$dir/$_cacheFileName');
  }

  /// Inizializza il servizio creando le directory necessarie
  Future<void> initialize() async {
    final dir = await _cacheDir;
    final directory = Directory(dir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  /// Verifica se il modello è presente in cache e valido
  Future<bool> isModelCached() async {
    try {
      final cacheInfo = await _loadCacheInfo();
      if (cacheInfo == null) return false;

      // Verifica se il modello esiste
      final modelPath = cacheInfo['modelPath'] as String?;
      if (modelPath == null) return false;

      final modelDir = Directory(modelPath);
      if (!await modelDir.exists()) return false;

      // Verifica la versione del modello
      final cachedVersion = cacheInfo['version'] as String?;
      if (cachedVersion != AppConfig.voskModelVersion) return false;

      // Verifica l'hash del modello
      final cachedHash = cacheInfo['hash'] as String?;
      if (cachedHash == null) return false;

      final currentHash = await _calculateModelHash(modelPath);
      return cachedHash == currentHash;
    } catch (e) {
      print('Errore nella verifica della cache: $e');
      return false;
    }
  }

  /// Carica le informazioni di cache dal file
  Future<Map<String, dynamic>?> _loadCacheInfo() async {
    try {
      final file = await _cacheFile;
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      return json.decode(content) as Map<String, dynamic>;
    } catch (e) {
      print('Errore nel caricamento delle info della cache: $e');
      return null;
    }
  }

  /// Aggiorna le informazioni di cache per un nuovo modello
  Future<void> updateCacheInfo(String modelPath) async {
    try {
      final hash = await _calculateModelHash(modelPath);
      final cacheInfo = {
        'modelPath': modelPath,
        'version': AppConfig.voskModelVersion,
        'hash': hash,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final file = await _cacheFile;
      await file.writeAsString(json.encode(cacheInfo));
    } catch (e) {
      print('Errore nell\'aggiornamento della cache: $e');
    }
  }

  /// Calcola l'hash MD5 del modello per verificarne l'integrità
  Future<String> _calculateModelHash(String modelPath) async {
    final modelDir = Directory(modelPath);
    final files = await modelDir.list(recursive: true).toList();
    files.sort((a, b) => a.path.compareTo(b.path)); // Ordine consistente

    final allBytes = <int>[];

    for (var file in files) {
      if (file is File) {
        final content = await file.readAsBytes();
        allBytes.addAll(content);
      }
    }

    final hash = md5.convert(allBytes);
    return hash.toString();
  }

  /// Pulisce la cache eliminando tutti i files
  Future<void> clearCache() async {
    try {
      final dir = await _cacheDir;
      final directory = Directory(dir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      print('Errore nella pulizia della cache: $e');
    }
  }

  /// Calcola la dimensione totale della cache in bytes
  Future<int> getCacheSize() async {
    try {
      final dir = await _cacheDir;
      final directory = Directory(dir);
      if (!await directory.exists()) return 0;

      int size = 0;
      await for (var file in directory.list(recursive: true)) {
        if (file is File) {
          size += await file.length();
        }
      }
      return size;
    } catch (e) {
      print('Errore nel calcolo della dimensione della cache: $e');
      return 0;
    }
  }

  /// Ottiene la data dell'ultimo aggiornamento della cache
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final cacheInfo = await _loadCacheInfo();
      if (cacheInfo == null) return null;

      final timestamp = cacheInfo['timestamp'] as String?;
      if (timestamp == null) return null;

      return DateTime.parse(timestamp);
    } catch (e) {
      print('Errore nel recupero del timestamp: $e');
      return null;
    }
  }
}