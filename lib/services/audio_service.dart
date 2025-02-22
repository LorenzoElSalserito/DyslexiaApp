// lib/services/audio_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:record/record.dart';
import '../models/enums.dart';
import '../config/app_config.dart';

/// Interfaccia base per il servizio audio
abstract class IAudioService {
  // Proprietà di base
  bool get isInitialized;
  bool get isRecording;
  int get currentAttempt;
  int get maxAttempts;
  bool get isSessionComplete;
  Duration get delayBetweenRecordings;

  // Stream per gli aggiornamenti
  Stream<double> get volumeLevel;
  Stream<AudioState> get audioState;
  Stream<int> get recordingProgress;

  // Metodi base
  Future<void> initialize();
  Future<String> startRecording();
  Future<String> stopRecording();
  Future<void> dispose();
}

/// Implementazione del servizio audio che supporta diverse piattaforme
class AudioService implements IAudioService {
  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  // Costanti pubbliche
  @override
  final int maxAttempts = 5;
  @override
  final Duration delayBetweenRecordings = const Duration(seconds: 3);

  // Durata massima di registrazione (opzionale)
  final Duration _maxRecordingDuration = const Duration(seconds: 30);

  // Stato interno
  bool _isInitialized = false;
  bool _isRecording = false;
  int _currentAttempt = 0;
  Timer? _volumeTimer;
  late String _recordingPath;

  // Stream controllers
  final _volumeController = StreamController<double>.broadcast();
  final _stateController = StreamController<AudioState>.broadcast();
  final _progressController = StreamController<int>.broadcast();

  // Recorder (utilizzato solo se non siamo su Linux)
  AudioRecorder? _audioRecorder;
  Process? _linuxRecordingProcess;

  AudioService._internal() {
    // Su Linux non utilizziamo il plugin record (per evitare il problema di compilazione)
    if (!Platform.isLinux) {
      _audioRecorder = AudioRecorder();
    }
  }

  // Getters
  @override
  Stream<double> get volumeLevel => _volumeController.stream;
  @override
  Stream<AudioState> get audioState => _stateController.stream;
  @override
  Stream<int> get recordingProgress => _progressController.stream;
  @override
  bool get isInitialized => _isInitialized;
  @override
  bool get isRecording => _isRecording;
  @override
  int get currentAttempt => _currentAttempt;
  @override
  bool get isSessionComplete => _currentAttempt >= maxAttempts;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('AudioService: Inizializzazione...');

    if (!Platform.isLinux) {
      // Su piattaforme diverse da Linux usiamo il plugin record per controllare i permessi ed il supporto encoder
      final hasPermission = await _audioRecorder!.hasPermission();
      if (!hasPermission) {
        throw Exception('Permessi audio non concessi');
      }
      final isWavSupported = await _audioRecorder!.isEncoderSupported(AudioEncoder.wav);
      if (!isWavSupported) {
        throw Exception('Encoder WAV non supportato su questa piattaforma');
      }
    }

    // Prepara la directory per le registrazioni
    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(path.join(appDir.path, 'OpenDSA_recordings'));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    _recordingPath = path.join(recordingsDir.path, 'recording.wav');

    // Su Linux verifichiamo la presenza di arecord per il fallback
    if (Platform.isLinux) {
      try {
        final result = await Process.run('which', ['arecord']);
        if (result.exitCode != 0) {
          debugPrint('AudioService: arecord non trovato, usare il plugin record se disponibile');
        }
      } catch (e) {
        debugPrint('AudioService: Errore verifica arecord: $e');
      }
    }

    _isInitialized = true;
    _updateState(AudioState.stopped);
    debugPrint('AudioService: Inizializzazione completata');
  }

  @override
  Future<String> startRecording() async {
    if (!_isInitialized) throw Exception('Servizio non inizializzato');
    if (_isRecording) return _recordingPath;

    _currentAttempt++;
    _progressController.add(_currentAttempt);

    if (Platform.isLinux) {
      // Su Linux usiamo il fallback con arecord
      await _startLinuxRecording();
    } else {
      // Su altre piattaforme usiamo il plugin record
      await _audioRecorder!.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 16 * 1000,
          numChannels: 1,
        ),
        path: _recordingPath,
      );
    }

    _isRecording = true;
    _updateState(AudioState.recording);
    _startVolumeMonitoring();

    debugPrint('AudioService: Registrazione avviata');
    return _recordingPath;
  }

  Future<String> _startLinuxRecording() async {
    final args = [
      '-f', 'S16_LE',    // Formato PCM a 16-bit little-endian
      '-r', '16000',     // Sample rate: 16 kHz
      '-c', '1',         // Canale: mono
      '-D', 'default',   // Dispositivo di default
      _recordingPath,    // File di output
    ];

    _linuxRecordingProcess = await Process.start('arecord', args);
    return _recordingPath;
  }

  @override
  Future<String> stopRecording() async {
    if (!_isRecording) return '';

    _stopVolumeMonitoring();

    if (Platform.isLinux) {
      await _stopLinuxRecording();
    } else {
      await _audioRecorder!.stop();
    }

    _isRecording = false;
    _updateState(AudioState.stopped);

    debugPrint('AudioService: Registrazione fermata');
    return _recordingPath;
  }

  Future<void> _stopLinuxRecording() async {
    if (_linuxRecordingProcess != null) {
      _linuxRecordingProcess!.kill();
      await _linuxRecordingProcess!.exitCode;
      _linuxRecordingProcess = null;
    }
  }

  void _startVolumeMonitoring() {
    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_isRecording) return;

      double volume = 0.0;
      if (Platform.isLinux) {
        // Simulazione del volume per Linux
        volume = 0.3 + (DateTime.now().millisecondsSinceEpoch % 1000) / 2000;
      } else {
        // Otteniamo il volume reale dal plugin record
        volume = await _audioRecorder!
            .getAmplitude()
            .then((amp) => amp.current / 100)
            .catchError((e) => 0.0);
      }
      _volumeController.add(volume.clamp(0.0, 1.0));
    });
  }

  void _stopVolumeMonitoring() {
    _volumeTimer?.cancel();
    _volumeTimer = null;
  }

  void _updateState(AudioState newState) {
    _stateController.add(newState);
  }

  @override
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }
    if (!Platform.isLinux) {
      await _audioRecorder!.dispose();
    }
    await _volumeController.close();
    await _stateController.close();
    await _progressController.close();

    _isInitialized = false;
    debugPrint('AudioService: Risorse rilasciate');
  }
}
