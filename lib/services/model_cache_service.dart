// model_cache_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../config/app_config.dart';

class ModelCacheService {
  static const String _cacheFileName = 'model_cache_info.json';
  static ModelCacheService? _instance;

  // Singleton pattern
  static ModelCacheService get instance {
    _instance ??= ModelCacheService._();
    return _instance!;
  }

  ModelCacheService._();

  Future<String> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/model_cache';
  }

  Future<File> get _cacheFile async {
    final dir = await _cacheDir;
    return File('$dir/$_cacheFileName');
  }

  Future<void> initialize() async {
    final dir = await _cacheDir;
    final directory = Directory(dir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

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

  Future<String> _calculateModelHash(String modelPath) async {
    final modelDir = Directory(modelPath);
    final files = await modelDir.list(recursive: true).toList();
    files.sort((a, b) => a.path.compareTo(b.path)); // Ordine consistente

    final digest = AccumulatorSink<Digest>();
    final hasher = md5.startChunkedConversion(digest);

    for (var file in files) {
      if (file is File) {
        final content = await file.readAsBytes();
        hasher.add(content);
      }
    }

    hasher.close();
    return digest.events.single.toString();
  }

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