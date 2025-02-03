// lib/services/file_storage_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  // Costanti per la gestione dei file
  static const String _savesDirectoryName = 'saves';
  static const String _profileExtension = '.profile';

  // Metodo privato per ottenere la directory di base per i salvataggi
  Future<String> get _basePath async {
    final appDir = await getApplicationDocumentsDirectory();
    final savePath = path.join(appDir.path, _savesDirectoryName);

    // Crea la directory se non esiste
    final directory = Directory(savePath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return savePath;
  }

  // Genera il nome del file per un profilo
  String _getProfileFileName(String profileId) {
    return 'profile_$profileId$_profileExtension';
  }

  // Ottiene il percorso completo del file per un profilo
  Future<String> _getProfilePath(String profileId) async {
    final basePath = await _basePath;
    return path.join(basePath, _getProfileFileName(profileId));
  }

  // Scrive i dati di un profilo su file
  Future<void> writeProfile(String profileId, Map<String, dynamic> data) async {
    try {
      final filePath = await _getProfilePath(profileId);
      final file = File(filePath);
      final jsonString = json.encode(data);
      await file.writeAsString(jsonString, flush: true);
    } catch (e) {
      print('Error writing profile to file: $e');
      rethrow;
    }
  }

  // Legge i dati di un profilo da file
  Future<Map<String, dynamic>> readProfile(String profileId) async {
    try {
      final filePath = await _getProfilePath(profileId);
      final file = File(filePath);

      if (!await file.exists()) {
        return {};
      }

      final jsonString = await file.readAsString();
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error reading profile from file: $e');
      return {};
    }
  }

  // Verifica se esiste un profilo
  Future<bool> profileExists(String profileId) async {
    try {
      final filePath = await _getProfilePath(profileId);
      return await File(filePath).exists();
    } catch (e) {
      print('Error checking profile existence: $e');
      return false;
    }
  }

  // Elimina un profilo
  Future<void> deleteProfile(String profileId) async {
    try {
      final filePath = await _getProfilePath(profileId);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting profile file: $e');
      rethrow;
    }
  }

  // Ottiene la lista di tutti i profili salvati
  Future<List<String>> getAllProfileIds() async {
    try {
      final basePath = await _basePath;
      final directory = Directory(basePath);

      if (!await directory.exists()) {
        return [];
      }

      final files = await directory
          .list()
          .where((entity) => entity is File &&
          entity.path.endsWith(_profileExtension))
          .map((file) {
        final fileName = path.basename(file.path);
        final profileId = fileName
            .replaceFirst('profile_', '')
            .replaceFirst(_profileExtension, '');
        return profileId;
      })
          .toList();

      return files;
    } catch (e) {
      print('Error getting profile list: $e');
      return [];
    }
  }

  // Elimina tutti i dati salvati
  Future<void> deleteAllData() async {
    try {
      final basePath = await _basePath;
      final directory = Directory(basePath);

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      print('Error deleting all data: $e');
      rethrow;
    }
  }

  // Ottiene la dimensione totale dei dati salvati
  Future<int> getTotalStorageSize() async {
    try {
      final basePath = await _basePath;
      final directory = Directory(basePath);

      if (!await directory.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final file in directory.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      return totalSize;
    } catch (e) {
      print('Error calculating storage size: $e');
      return 0;
    }
  }

  // Esporta un profilo come stringa JSON
  Future<String?> exportProfile(String profileId) async {
    try {
      final data = await readProfile(profileId);
      if (data.isEmpty) return null;
      return json.encode(data);
    } catch (e) {
      print('Error exporting profile: $e');
      return null;
    }
  }

  // Importa un profilo da stringa JSON
  Future<bool> importProfile(String profileId, String jsonString) async {
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      await writeProfile(profileId, data);
      return true;
    } catch (e) {
      print('Error importing profile: $e');
      return false;
    }
  }

  // Backup di tutti i profili in una singola stringa JSON
  Future<String?> backupAllProfiles() async {
    try {
      final profiles = await getAllProfileIds();
      final backupData = <String, Map<String, dynamic>>{};

      for (final profileId in profiles) {
        final profileData = await readProfile(profileId);
        if (profileData.isNotEmpty) {
          backupData[profileId] = profileData;
        }
      }

      return json.encode(backupData);
    } catch (e) {
      print('Error creating backup: $e');
      return null;
    }
  }

  // Ripristina tutti i profili da un backup
  Future<bool> restoreFromBackup(String backupJson) async {
    try {
      // Prima elimina tutti i dati esistenti
      await deleteAllData();

      final backupData = json.decode(backupJson) as Map<String, dynamic>;
      for (final entry in backupData.entries) {
        await writeProfile(
            entry.key,
            entry.value as Map<String, dynamic>
        );
      }

      return true;
    } catch (e) {
      print('Error restoring from backup: $e');
      return false;
    }
  }
}