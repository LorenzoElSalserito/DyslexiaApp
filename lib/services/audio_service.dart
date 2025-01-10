// audio_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';

enum AudioState {
  stopped,
  recording,
  paused
}

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isInitialized = false;
  AudioState _state = AudioState.stopped;
  late String _recordingPath;
  StreamSubscription? _recorderSubscription;
  final _volumeLevelController = StreamController<double>.broadcast();
  final _stateController = StreamController<AudioState>.broadcast();

  // Streams pubblici
  Stream<double> get volumeLevel => _volumeLevelController.stream;
  Stream<AudioState> get audioState => _stateController.stream;
  AudioState get currentState => _state;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Verifica permessi
      if (!await _checkPermissions()) {
        throw Exception('Permessi microfono non concessi');
      }

      // Inizializza il recorder
      await _recorder.openRecorder();

      // Configura i parametri di registrazione
      await _recorder.setSubscriptionDuration(
          const Duration(milliseconds: 100)
      );

      // Imposta il percorso di registrazione
      final tempDir = await _getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/temp_recording.wav';

      _isInitialized = true;
      _updateState(AudioState.stopped);
    } catch (e) {
      print('Errore nell\'inizializzazione dell\'AudioService: $e');
      rethrow;
    }
  }

  Future<bool> _checkPermissions() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<Directory> _getTemporaryDirectory() async {
    final tempDir = await Directory.systemTemp.createTemp();
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  Future<void> startRecording() async {
    if (!_isInitialized) await initialize();
    if (_state == AudioState.recording) return;

    try {
      // Configura la registrazione audio
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: AppConfig.sampleRate,
        numChannels: AppConfig.channels,
      );

      // Monitora il livello del volume
      _recorderSubscription = _recorder.onProgress!.listen((event) {
        if (event.decibels != null) {
          // Normalizza i decibel in un valore tra 0 e 1
          final normalizedLevel = (event.decibels! + 160) / 160;
          _volumeLevelController.add(normalizedLevel.clamp(0.0, 1.0));
        }
      });

      _updateState(AudioState.recording);
    } catch (e) {
      print('Errore nell\'avvio della registrazione: $e');
      _updateState(AudioState.stopped);
      rethrow;
    }
  }

  Future<String> stopRecording() async {
    if (!_isInitialized || _state != AudioState.recording) {
      return '';
    }

    try {
      // Ferma il monitoraggio del volume
      await _recorderSubscription?.cancel();
      _recorderSubscription = null;

      // Ferma la registrazione
      final recordingResult = await _recorder.stopRecorder();
      _updateState(AudioState.stopped);

      return recordingResult ?? '';
    } catch (e) {
      print('Errore nello stop della registrazione: $e');
      _updateState(AudioState.stopped);
      rethrow;
    }
  }

  Future<void> pauseRecording() async {
    if (_state != AudioState.recording) return;

    try {
      await _recorder.pauseRecorder();
      _updateState(AudioState.paused);
    } catch (e) {
      print('Errore nella pausa della registrazione: $e');
      rethrow;
    }
  }

  Future<void> resumeRecording() async {
    if (_state != AudioState.paused) return;

    try {
      await _recorder.resumeRecorder();
      _updateState(AudioState.recording);
    } catch (e) {
      print('Errore nella ripresa della registrazione: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      await stopRecording();
      await _recorderSubscription?.cancel();
      await _recorder.closeRecorder();
      await _volumeLevelController.close();
      await _stateController.close();

      _isInitialized = false;
      _state = AudioState.stopped;
    } catch (e) {
      print('Errore nella dispose dell\'AudioService: $e');
    }
  }

  void _updateState(AudioState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  // Getters utili
  bool get isInitialized => _isInitialized;
  bool get isRecording => _state == AudioState.recording;
  String get recordingPath => _recordingPath;
}