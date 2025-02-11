import 'dart:io' show Directory, File, Platform;
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  static const String _savesDirectoryName = 'saves';
  static const String _profileExtension = '.profile';
  static const String _tempExtension = '.tmp';
  static const String _backupExtension = '.bak';

  Directory? _baseDirectory;

  Future<Directory> get _baseDir async {
    if (_baseDirectory != null) {
      return _baseDirectory!;
    }
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final appDir = Directory(path.join(appDocDir.path, 'OpenDSA'));
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      final saveDir = Directory(path.join(appDir.path, _savesDirectoryName));
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      _baseDirectory = saveDir;
      return _baseDirectory!;
    } catch (e) {
      _logError('Errore nell\'inizializzazione della directory di base', e);
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
    final profileFile = await _getProfileFile(profileId);
    // Assicuriamoci che la directory esista
    await profileFile.parent.create(recursive: true);
    final tempFile = File('${profileFile.path}$_tempExtension');
    final backupFile = File('${profileFile.path}$_backupExtension');

    try {
      final dir = profileFile.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final jsonString = json.encode(data);
      await tempFile.writeAsString(jsonString, flush: true);
      if (await profileFile.exists()) {
        await profileFile.copy(backupFile.path);
      }
      if (await tempFile.exists()) {
        await tempFile.rename(profileFile.path);
      }
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (e) {
      _logError('Errore nella scrittura del profilo $profileId', e);
      try {
        if (await backupFile.exists()) {
          await backupFile.copy(profileFile.path);
          await backupFile.delete();
        }
      } catch (backupError) {
        _logError('Errore nel ripristino del backup per $profileId', backupError);
      }
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (cleanupError) {
        _logError('Errore nella pulizia dei file temporanei per $profileId', cleanupError);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> readProfile(String profileId) async {
    if (profileId.isEmpty) {
      throw ArgumentError('ProfileId non può essere vuoto');
    }
    try {
      final profileFile = await _getProfileFile(profileId);
      final backupFile = File('${profileFile.path}$_backupExtension');

      if (!await profileFile.exists()) {
        if (await backupFile.exists()) {
          final backupData = await backupFile.readAsString();
          return json.decode(backupData) as Map<String, dynamic>;
        }
        return {};
      }
      final jsonString = await profileFile.readAsString();
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      _logError('Errore nella lettura del profilo $profileId', e);
      return {};
    }
  }

  Future<bool> profileExists(String profileId) async {
    if (profileId.isEmpty) return false;
    try {
      final profileFile = await _getProfileFile(profileId);
      return await profileFile.exists();
    } catch (e) {
      _logError('Errore nel controllo esistenza profilo $profileId', e);
      return false;
    }
  }

  Future<void> deleteProfile(String profileId) async {
    if (profileId.isEmpty) {
      throw ArgumentError('ProfileId non può essere vuoto');
    }
    try {
      final profileFile = await _getProfileFile(profileId);
      final tempFile = File('${profileFile.path}$_tempExtension');
      final backupFile = File('${profileFile.path}$_backupExtension');
      for (final file in [profileFile, tempFile, backupFile]) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      _logError('Errore nell\'eliminazione del profilo $profileId', e);
      rethrow;
    }
  }

  Future<List<String>> getAllProfileIds() async {
    try {
      final baseDir = await _baseDir;
      if (!await baseDir.exists()) {
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
      return files;
    } catch (e) {
      _logError('Errore nel recupero lista profili', e);
      return [];
    }
  }

  Future<void> deleteAllData() async {
    try {
      final baseDir = await _baseDir;
      if (await baseDir.exists()) {
        await baseDir.delete(recursive: true);
      }
      _baseDirectory = null;
    } catch (e) {
      _logError('Errore nell\'eliminazione di tutti i dati', e);
      rethrow;
    }
  }

  Future<int> getTotalStorageSize() async {
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
      return totalSize;
    } catch (e) {
      _logError('Errore nel calcolo dimensione storage', e);
      return 0;
    }
  }

  Future<String?> exportProfile(String profileId) async {
    try {
      final data = await readProfile(profileId);
      if (data.isEmpty) return null;
      return json.encode(data);
    } catch (e) {
      _logError('Errore nell\'esportazione del profilo $profileId', e);
      return null;
    }
  }

  Future<bool> importProfile(String profileId, String jsonString) async {
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      await writeProfile(profileId, data);
      return true;
    } catch (e) {
      _logError('Errore nell\'importazione del profilo $profileId', e);
      return false;
    }
  }

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
      _logError('Errore nella creazione del backup', e);
      return null;
    }
  }

  Future<bool> restoreFromBackup(String backupJson) async {
    try {
      await deleteAllData();
      final backupData = json.decode(backupJson) as Map<String, dynamic>;
      for (final entry in backupData.entries) {
        await writeProfile(entry.key, entry.value as Map<String, dynamic>);
      }
      return true;
    } catch (e) {
      _logError('Errore nel ripristino dal backup', e);
      return false;
    }
  }

  void _logError(String message, Object error) {
    final timestamp = DateTime.now().toIso8601String();
    print('[$timestamp] FileStorageService - $message: $error');
  }
}
