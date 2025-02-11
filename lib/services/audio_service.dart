// lib/services/audio_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/enums.dart';

/// Servizio che gestisce tutti gli aspetti delle registrazioni audio nell'applicazione.
/// Si occupa della registrazione, della gestione del volume e del ciclo di vita
/// delle sessioni audio.
class AudioService {
  // Costanti per la gestione della registrazione
  static const Duration _recordingDuration = Duration(seconds: 5);
  static const Duration _delayBetweenRecordings = Duration(seconds: 3);
  static const int _maxAttempts = 5;

  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  // Stato interno del servizio
  final _AudioServiceState _state = _AudioServiceState();
  final _StreamControllers _streamControllers = _StreamControllers();

  // Componenti audio
  FlutterSoundRecorder? _recorder;
  String? _recordingPath;
  Timer? _recordingTimer;
  Timer? _volumeUpdateTimer;
  bool _processingResult = false;
  final Random _random = Random();

  /// Costruttore privato per il singleton
  AudioService._internal() {
    debugPrint('AudioService inizializzato per ${Platform.operatingSystem}');
  }

  /// Inizializza il servizio audio
  Future<void> initialize() async {
    if (_state.isInitialized) {
      _streamControllers.reset();
      _state.reset();
    }

    try {
      if (!_isRecordingSupported()) {
        _state.isSimulatedMode = true;
        await _initializeSimulated();
      } else {
        await _initializeNative();
      }

      await _setupRecordingDirectory();
      _state.isInitialized = true;
    } catch (e, stack) {
      debugPrint('Errore inizializzazione: $e\n$stack');
      _state.isSimulatedMode = true;
      await _initializeSimulated();
    }
  }

  /// Verifica se la registrazione è supportata sulla piattaforma
  bool _isRecordingSupported() {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Inizializza la modalità simulata
  Future<void> _initializeSimulated() async {
    _state.isReady = true;
    debugPrint('Modalità simulata attivata');
  }

  /// Inizializza la modalità nativa
  Future<void> _initializeNative() async {
    try {
      _recorder = FlutterSoundRecorder();
      await _recorder?.openRecorder();
      await _recorder?.setSubscriptionDuration(const Duration(milliseconds: 100));
      _state.isReady = true;
    } catch (e) {
      debugPrint('Fallback a modalità simulata: $e');
      _state.isSimulatedMode = true;
      await _initializeSimulated();
    }
  }

  /// Configura la directory di registrazione
  Future<void> _setupRecordingDirectory() async {
    try {
      final tempDir = await Directory.systemTemp.createTemp('audio_recording_');
      _recordingPath = '${tempDir.path}/recording.wav';
    } catch (e) {
      debugPrint('Errore setup directory: $e');
      _recordingPath = 'recording.wav';
    }
  }

  /// Avvia la registrazione audio
  Future<void> startRecording() async {
    if (!_canStartRecording() || _processingResult) return;

    try {
      _streamControllers.reset();

      if (_state.isSimulatedMode) {
        await _startSimulatedRecording();
      } else {
        await _startNativeRecording();
      }

      _startRecordingTimer();
      _updateState(AudioState.recording);

      _state.currentAttempt++;
      _streamControllers.progress.add(_state.currentAttempt);
    } catch (e, stack) {
      debugPrint('Errore avvio registrazione: $e\n$stack');
      _updateState(AudioState.stopped);
      rethrow;
    }
  }

  /// Avvia la registrazione simulata
  Future<void> _startSimulatedRecording() async {
    _state.volumeTimer?.cancel();
    _state.volumeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
          (timer) {
        if (_state.currentState == AudioState.recording) {
          _state.currentVolume = _random.nextDouble() * 0.5 + 0.3;
          _streamControllers.volume.add(_state.currentVolume);
        } else {
          timer.cancel();
        }
      },
    );
  }

  /// Avvia la registrazione nativa
  Future<void> _startNativeRecording() async {
    try {
      await _recorder?.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: AppConfig.sampleRate,
        numChannels: AppConfig.channels,
      );
    } catch (e) {
      debugPrint('Fallback a simulata per errore: $e');
      _state.isSimulatedMode = true;
      await _startSimulatedRecording();
    }
  }

  /// Avvia il timer di registrazione
  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer(_recordingDuration, () {
      if (_state.currentState == AudioState.recording) {
        stopRecording();
      }
    });
  }

  /// Ferma la registrazione corrente
  Future<String> stopRecording() async {
    if (_state.currentState != AudioState.recording || _processingResult) {
      return '';
    }

    try {
      _processingResult = true;
      final path = await _stopCurrentRecording();
      _processingResult = false;

      if (_state.currentAttempt >= _state._maxAttempts) {
        _state.isSessionComplete = true;
        _updateState(AudioState.stopped);
      } else {
        _updateState(AudioState.waitingNext);
        Timer(_state._delayBetweenRecordings, () {
          if (_state.currentState == AudioState.waitingNext) {
            _updateState(AudioState.stopped);
          }
        });
      }

      return path;
    } catch (e, stack) {
      debugPrint('Errore stop registrazione: $e\n$stack');
      _updateState(AudioState.stopped);
      _processingResult = false;
      rethrow;
    }
  }

  /// Ferma l'attuale registrazione e restituisce il path del file
  Future<String> _stopCurrentRecording() async {
    _recordingTimer?.cancel();
    _state.volumeTimer?.cancel();

    if (!_state.isSimulatedMode && _recorder != null) {
      try {
        await _recorder?.stopRecorder();
      } catch (e) {
        debugPrint('Errore stop recorder: $e');
      }
    }

    return _recordingPath ?? '';
  }

  /// Aggiorna lo stato del servizio
  void _updateState(AudioState newState) {
    _state.currentState = newState;
    if (!_streamControllers.isClosed) {
      _streamControllers.state.add(newState);
    }
  }

  /// Verifica se è possibile avviare la registrazione
  bool _canStartRecording() {
    if (!_state.isInitialized) return false;
    if (_state.currentState == AudioState.recording) return false;
    if (_state.isSessionComplete) return false;
    return true;
  }

  /// Rilascia le risorse utilizzate
  Future<void> dispose() async {
    _recordingTimer?.cancel();
    _state.volumeTimer?.cancel();
    if (!_state.isSimulatedMode) {
      await _recorder?.closeRecorder();
      _recorder = null;
    }
    await _streamControllers.dispose();
    _state.reset();
  }

  // Getters pubblici

  /// Stream del livello di volume aggiornato
  Stream<double> get volumeLevel => _streamControllers.volume.stream;

  /// Stream dello stato audio
  Stream<AudioState> get audioState => _streamControllers.state.stream;

  /// Stream del progresso della registrazione (tentativi)
  Stream<int> get recordingProgress => _streamControllers.progress.stream;

  /// Ritorna true se è in corso una registrazione
  bool get isRecording => _state.currentState == AudioState.recording;

  /// Stato corrente del servizio audio
  AudioState get currentState => _state.currentState;

  /// Ritorna true se la sessione di registrazione è completa
  bool get isSessionComplete => _state.isSessionComplete;

  /// (Getter esistente) Numero massimo di tentativi
  int get attemptCount => _state._maxAttempts;

  /// (Getter esistente) Ritardo tra una registrazione e l'altra
  Duration get recordingDelay => _state._delayBetweenRecordings;

  /// **Nuovi Getters** aggiunti per correzione:
  int get maxAttempts => _state._maxAttempts;
  Duration get delayBetweenRecordings => _state._delayBetweenRecordings;
}

/// Stato interno del servizio audio
class _AudioServiceState {
  bool isInitialized = false;
  bool isSimulatedMode = false;
  bool isReady = false;
  AudioState currentState = AudioState.stopped;
  int currentAttempt = 0;
  final int _maxAttempts = AudioService._maxAttempts;
  bool isSessionComplete = false;
  final Duration _delayBetweenRecordings = AudioService._delayBetweenRecordings;
  double currentVolume = 0.0;
  Timer? volumeTimer;

  void reset() {
    volumeTimer?.cancel();
    isInitialized = false;
    isReady = false;
    currentState = AudioState.stopped;
    currentAttempt = 0;
    isSessionComplete = false;
    currentVolume = 0.0;
  }
}

/// Controller per gli stream di eventi audio
class _StreamControllers {
  StreamController<double>? _volume;
  StreamController<AudioState>? _state;
  StreamController<int>? _progress;

  // Inizializzazione lazy degli stream
  StreamController<double> get volume {
    _volume ??= StreamController<double>.broadcast();
    return _volume!;
  }

  StreamController<AudioState> get state {
    _state ??= StreamController<AudioState>.broadcast();
    return _state!;
  }

  StreamController<int> get progress {
    _progress ??= StreamController<int>.broadcast();
    return _progress!;
  }

  // Verifica se gli stream sono chiusi
  bool get isClosed {
    return (_volume?.isClosed ?? false) ||
        (_state?.isClosed ?? false) ||
        (_progress?.isClosed ?? false);
  }

  // Reinizializza gli stream se necessario
  void reset() {
    if (_volume?.isClosed ?? false) {
      _volume = StreamController<double>.broadcast();
    }
    if (_state?.isClosed ?? false) {
      _state = StreamController<AudioState>.broadcast();
    }
    if (_progress?.isClosed ?? false) {
      _progress = StreamController<int>.broadcast();
    }
  }

  // Chiude gli stream in modo sicuro
  Future<void> dispose() async {
    if (!(_volume?.isClosed ?? true)) await _volume?.close();
    if (!(_state?.isClosed ?? true)) await _state?.close();
    if (!(_progress?.isClosed ?? true)) await _progress?.close();
    _volume = null;
    _state = null;
    _progress = null;
  }
}
