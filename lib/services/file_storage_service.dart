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

  // Variabile di lock per evitare operazioni concorrenti
  bool _writeInProgress = false;

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

  /// Metodo privato per eseguire operazioni in modalità esclusiva.
  Future<void> _performExclusiveOperation(Future<void> Function() operation) async {
    while (_writeInProgress) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    _writeInProgress = true;
    try {
      await operation();
    } finally {
      _writeInProgress = false;
    }
  }

  /// Genera il nome del file per un profilo
  String _getProfileFileName(String profileId) {
    if (profileId.isEmpty) {
      throw ArgumentError('ProfileId non può essere vuoto');
    }
    return 'profile_$profileId$_profileExtension';
  }

  /// Ottiene il file associato a un profilo
  Future<File> _getProfileFile(String profileId) async {
    if (profileId.isEmpty) {
      throw ArgumentError('ProfileId non può essere vuoto');
    }
    final baseDir = await _baseDir;
    final fileName = _getProfileFileName(profileId);
    return File(path.join(baseDir.path, fileName));
  }

  /// Scrive i dati di un profilo su file con backup di sicurezza
  Future<void> writeProfile(String profileId, Map<String, dynamic> data) async {
    if (profileId.isEmpty) {
      throw ArgumentError('ProfileId non può essere vuoto');
    }
    if (data.isEmpty) {
      throw ArgumentError('I dati del profilo non possono essere vuoti');
    }
    await _performExclusiveOperation(() async {
      debugPrint('Scrittura profilo $profileId');
      final profileFile = await _getProfileFile(profileId);
      final tempFile = File('${profileFile.path}$_tempExtension');
      final backupFile = File('${profileFile.path}$_backupExtension');
      // Assicura che la directory esista
      final dir = profileFile.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      // Scrive i dati in un file temporaneo
      final jsonString = json.encode(data);
      await tempFile.writeAsString(jsonString, flush: true);
      debugPrint('File temporaneo scritto: ${tempFile.path}');
      // Se il file esistente esiste, crea un backup
      if (await profileFile.exists()) {
        await profileFile.copy(backupFile.path);
        debugPrint('Backup creato: ${backupFile.path}');
      }
      // Rinomina il file temporaneo nel file definitivo (se esiste)
      if (await tempFile.exists()) {
        await tempFile.rename(profileFile.path);
        debugPrint('File temporaneo rinominato in definitivo: ${profileFile.path}');
      }
      // Elimina il backup se esiste
      if (await backupFile.exists()) {
        await backupFile.delete();
        debugPrint('Backup eliminato dopo scrittura corretta');
      }
      debugPrint('Scrittura profilo completata con successo');
    });
  }

  /// Legge i dati di un profilo da file
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

  /// Verifica se un profilo esiste
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

  /// Elimina un profilo e tutti i suoi file associati
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

  /// Ottiene la lista degli ID di tutti i profili salvati
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
      entity is File && path.extension(entity.path) == _profileExtension)
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

  /// Elimina tutti i dati salvati
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

  /// Calcola la dimensione totale dei dati salvati
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
