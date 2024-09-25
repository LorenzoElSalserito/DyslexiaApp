import 'dart:io';
import 'package:path/path.dart' as path;

class FileStorageService {
  static const String _savesDirectoryName = 'saves';
  static const String _profileFileName = 'profile.txt';

  Future<String> get _localPath async {
    // Ottieni il percorso della directory lib
    String currentScriptPath = Platform.script.toFilePath();
    String libPath = path.dirname(currentScriptPath);

    // Costruisci il percorso completo per la directory saves
    return path.join(libPath, _savesDirectoryName);
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_profileFileName');
  }

  Future<void> createSavesDirectory() async {
    final path = await _localPath;
    final saveDir = Directory(path);
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
  }

  Future<void> writeProfile(Map<String, dynamic> profileData) async {
    await createSavesDirectory();
    final file = await _localFile;
    final content = profileData.entries.map((e) => '${e.key}:${e.value.toString()}').join('\n');
    await file.writeAsString(content);
  }

  Future<Map<String, dynamic>> readProfile() async {
    try {
      final file = await _localFile;
      final contents = await file.readAsString();
      return Map.fromEntries(
        contents.split('\n').map((line) {
          final parts = line.split(':');
          return MapEntry(parts[0], parts.length > 1 ? parts[1] : '');
        }),
      );
    } catch (e) {
      print('Error reading profile: $e');
      return {};
    }
  }

  Future<bool> profileExists() async {
    final file = await _localFile;
    return file.exists();
  }

  Future<void> deleteProfile() async {
    final file = await _localFile;
    if (await file.exists()) {
      await file.delete();
    }
  }
}