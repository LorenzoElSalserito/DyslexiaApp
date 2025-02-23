// lib/platform/linux_audio.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record_linux/record_linux.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

class LinuxAudioRecorder {
  static final LinuxAudioRecorder _instance = LinuxAudioRecorder._internal();
  factory LinuxAudioRecorder() => _instance;

  RecordLinux? _recorder;
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _currentPath;

  LinuxAudioRecorder._internal() {
    _recorder = RecordLinux();
    _isInitialized = true;
  }

  Future<String?> startRecording() async {
    if (!_isInitialized) {
      throw Exception('Recorder non inizializzato');
    }

    try {
      if (_isRecording) {
        debugPrint('LinuxAudioRecorder: Registrazione già in corso');
        return _currentPath;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${appDir.path}/record_$timestamp.wav';

      await _recorder?.start(
        path: _currentPath!,
        encoder: AudioEncoder.wav,
        bitRate: 16000,
        samplingRate: 16000,
        numChannels: 1,
      );

      _isRecording = true;
      debugPrint('LinuxAudioRecorder: Registrazione avviata: $_currentPath');
      return _currentPath;
    } catch (e) {
      debugPrint('LinuxAudioRecorder: Errore nell\'avvio della registrazione: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return _currentPath;
    }

    try {
      await _recorder?.stop();
      _isRecording = false;
      debugPrint('LinuxAudioRecorder: Registrazione fermata');
      return _currentPath;
    } catch (e) {
      debugPrint('LinuxAudioRecorder: Errore nello stop della registrazione: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    await _recorder?.dispose();
    _recorder = null;
    _isInitialized = false;
    debugPrint('LinuxAudioRecorder: Risorse rilasciate');
  }

  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized;
}