// lib/services/file_storage_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

/// Servizio per la gestione del salvataggio e caricamento dei dati su file.
/// Implementa il pattern Singleton per garantire una singola istanza del servizio.
class FileStorageService {
  // Costanti per la gestione dei file
  static const String _savesDirectoryName = 'saves';
  static const String _profileExtension = '.profile';
  static const String _tempExtension = '.tmp';
  static const String _backupExtension = '.bak';

  // Directory base per il salvataggio
  Directory? _baseDirectory;

  // Implementazione Singleton
  static FileStorageService? _instance;

  factory FileStorageService() {
    _instance ??= FileStorageService._internal();
    return _instance!;
  }

  FileStorageService._internal() {
    debugPrint('FileStorageService inizializzato');
  }

  /// Ottiene la directory base per il salvataggio
  Future<Directory> get _baseDir async {
    if (_baseDirectory != null) {
      return _baseDirectory!;
    }

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final appDir = Directory(path.join(appDocDir.path, 'OpenDSA'));
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
        debugPrint('Directory base creata: ${appDir.path}');
      }
      final saveDir = Directory(path.join(appDir.path, _savesDirectoryName));
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
        debugPrint('Directory salvataggi creata: ${saveDir.path}');
      }
      _baseDirectory = saveDir;
      return _baseDirectory!;
    } catch (e) {
      debugPrint('Errore nell\'inizializzazione della directory di base: $e');
      rethrow;
    }
  }

  String _getProfileFileName(String profileId) {
    if (profileId.isEmpty) {
      throw ArgumentError('ProfileId non può essere vuoto');
    }
    return 'profile_$profileId$_profileExtension';
  }

  Future<File> _getProfileFile(String profileId) async {
    if (profileId.isEmpty) {
      throw ArgumentError('ProfileId non può essere vuoto');
    }
    final baseDir = await _baseDir;
    final fileName = _getProfileFileName(profileId);
    return File(path.join(baseDir.path, fileName));
  }

  Future<void> writeProfile(String profileId, Map<String, dynamic> data) async {
    if (profileId.isEmpty) {
      throw ArgumentError('ProfileId non può essere vuoto');
    }
    if (data.isEmpty) {
      throw ArgumentError('I dati del profilo non possono essere vuoti');
    }

    debugPrint('Scrittura profilo $profileId');

    final profileFile = await _getProfileFile(profileId);
    final tempFile = File('${profileFile.path}$_tempExtension');
    final backupFile = File('${profileFile.path}$_backupExtension');

    try {
      final dir = profileFile.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final jsonString = json.encode(data);
      await tempFile.writeAsString(jsonString, flush: true);
      debugPrint('File temporaneo scritto: ${tempFile.path}');

      if (await profileFile.exists()) {
        await profileFile.copy(backupFile.path);
        debugPrint('Backup creato: ${backupFile.path}');
      }

      if (await tempFile.exists()) {
        await tempFile.rename(profileFile.path);
        debugPrint('File temporaneo rinominato in definitivo: ${profileFile.path}');
      }

      if (await backupFile.exists()) {
        try {
          await backupFile.delete();
          debugPrint('Backup eliminato dopo scrittura corretta');
        } catch (deleteError) {
          debugPrint('Errore nell\'eliminazione del backup: $deleteError');
        }
      }

      debugPrint('Scrittura profilo completata con successo');
    } catch (e) {
      debugPrint('Errore nella scrittura del profilo $profileId: $e');
      try {
        if (await backupFile.exists()) {
          await backupFile.copy(profileFile.path);
          await backupFile.delete();
          debugPrint('Ripristino da backup effettuato');
        }
      } catch (backupError) {
        debugPrint('Errore nel ripristino del backup per $profileId: $backupError');
      }
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
          debugPrint('File temporaneo eliminato dopo errore');
        }
      } catch (cleanupError) {
        debugPrint('Errore nella pulizia dei file temporanei per $profileId: $cleanupError');
      }
      // Non rethrow per evitare interruzioni continue
    }
  }

  Future<Map<String, dynamic>> readProfile(String profileId) async {
    if (profileId.isEmpty) {
      throw ArgumentError('ProfileId non può essere vuoto');
    }

    debugPrint('Lettura profilo $profileId');

    try {
      final profileFile = await _getProfileFile(profileId);
      final backupFile = File('${profileFile.path}$_backupExtension');

      if (!await profileFile.exists()) {
        if (await backupFile.exists()) {
          final backupData = await backupFile.readAsString();
          debugPrint('Profilo recuperato dal backup');
          return json.decode(backupData) as Map<String, dynamic>;
        }
        debugPrint('Nessun file trovato per il profilo $profileId');
        return {};
      }

      final jsonString = await profileFile.readAsString();
      final data = json.decode(jsonString) as Map<String, dynamic>;
      debugPrint('Profilo letto correttamente: $data');
      return data;
    } catch (e) {
      debugPrint('Errore nella lettura del profilo $profileId: $e');
      return {};
    }
  }

  Future<bool> profileExists(String profileId) async {
    if (profileId.isEmpty) return false;
    try {
      final profileFile = await _getProfileFile(profileId);
      final exists = await profileFile.exists();
      debugPrint('Verifica esistenza profilo $profileId: $exists');
      return exists;
    } catch (e) {
      debugPrint('Errore nel controllo esistenza profilo $profileId: $e');
      return false;
    }
  }

  Future<void> deleteProfile(String profileId) async {
    if (profileId.isEmpty) {
      throw ArgumentError('ProfileId non può essere vuoto');
    }

    debugPrint('Eliminazione profilo $profileId');

    try {
      final profileFile = await _getProfileFile(profileId);
      final tempFile = File('${profileFile.path}$_tempExtension');
      final backupFile = File('${profileFile.path}$_backupExtension');

      for (final file in [profileFile, tempFile, backupFile]) {
        if (await file.exists()) {
          await file.delete();
          debugPrint('File eliminato: ${file.path}');
        }
      }

      debugPrint('Profilo eliminato con successo');
    } catch (e) {
      debugPrint('Errore nell\'eliminazione del profilo $profileId: $e');
      rethrow;
    }
  }

  Future<List<String>> getAllProfileIds() async {
    debugPrint('Recupero lista profili');

    try {
      final baseDir = await _baseDir;
      if (!await baseDir.exists()) {
        debugPrint('Directory base non trovata');
        return [];
      }

      final files = await baseDir
          .list()
          .where((entity) =>
      entity is File &&
          path.extension(entity.path) == _profileExtension)
          .map((file) {
        final fileName = path.basename(file.path);
        return fileName.replaceFirst('profile_', '').replaceFirst(_profileExtension, '');
      }).toList();

      debugPrint('Profili trovati: $files');
      return files;
    } catch (e) {
      debugPrint('Errore nel recupero lista profili: $e');
      return [];
    }
  }

  Future<void> deleteAllData() async {
    debugPrint('Eliminazione di tutti i dati');

    try {
      final baseDir = await _baseDir;
      if (await baseDir.exists()) {
        await baseDir.delete(recursive: true);
        debugPrint('Directory base eliminata');
      }
      _baseDirectory = null;
    } catch (e) {
      debugPrint('Errore nell\'eliminazione di tutti i dati: $e');
      rethrow;
    }
  }

  Future<int> getTotalStorageSize() async {
    debugPrint('Calcolo dimensione storage');

    try {
      final baseDir = await _baseDir;
      if (!await baseDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final file in baseDir.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      debugPrint('Dimensione totale storage: $totalSize bytes');
      return totalSize;
    } catch (e) {
      debugPrint('Errore nel calcolo dimensione storage: $e');
      return 0;
    }
  }
}
