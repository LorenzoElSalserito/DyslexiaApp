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
/// Si occupa della registrazione, della gestione del volume e del ciclo di vita delle sessioni audio.
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
      debugPrint('AudioService: Già inizializzato, reset degli stream');
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
      debugPrint('Registrazione nativa inizializzata.');
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
      debugPrint('AudioService: Directory di registrazione impostata su $_recordingPath');
    } catch (e) {
      debugPrint('Errore setup directory: $e');
      _recordingPath = 'recording.wav';
    }
  }

  /// Avvia la registrazione audio
  Future<String> startRecording() async {
    if (!_canStartRecording() || _processingResult) return '';
    try {
      debugPrint('AudioService: startRecording() chiamato.');
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
      return _recordingPath ?? '';
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
    debugPrint('AudioService: Avvio registrazione simulata.');
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
      debugPrint('AudioService: Registrazione nativa avviata.');
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
    debugPrint('AudioService: Avvio recording timer per $_recordingDuration');
  }

  /// Ferma la registrazione corrente.
  ///
  /// Se lo stato corrente non è "recording" ma è già in "waitingNext" e
  /// il percorso di registrazione è stato impostato, restituisce quel percorso.
  Future<String> stopRecording() async {
    if (_state.currentState != AudioState.recording) {
      if (_state.currentState == AudioState.waitingNext && _recordingPath != null) {
        debugPrint('AudioService: stopRecording() chiamato in stato waitingNext, ritorno file path.');
        return _recordingPath!;
      }
      debugPrint('AudioService: stopRecording() chiamato, ma condizione non soddisfatta. Stato: ${_state.currentState}, processing: $_processingResult');
      return '';
    }
    if (_processingResult) return '';
    try {
      debugPrint('AudioService: stopRecording() chiamato.');
      _processingResult = true;
      final path = await _stopCurrentRecording();
      _processingResult = false;
      _updateState(AudioState.waitingNext);
      Timer(_delayBetweenRecordings, () {
        if (_state.currentState == AudioState.waitingNext) {
          _updateState(AudioState.stopped);
          debugPrint('AudioService: Stato aggiornato a AudioState.stopped dopo delay.');
        }
      });
      debugPrint('AudioService: stopRecording() completato. File: $path');
      return path;
    } catch (e, stack) {
      debugPrint('Errore stop registrazione: $e\n$stack');
      _updateState(AudioState.stopped);
      _processingResult = false;
      rethrow;
    }
  }

  /// Ferma l'attuale registrazione e restituisce il percorso del file
  Future<String> _stopCurrentRecording() async {
    _recordingTimer?.cancel();
    _state.volumeTimer?.cancel();
    debugPrint('AudioService: Timer cancellati in _stopCurrentRecording.');
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
    debugPrint('AudioService: Stato aggiornato a $newState');
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
    debugPrint('AudioService: Dispose chiamato.');
    _recordingTimer?.cancel();
    _state.volumeTimer?.cancel();
    if (!_state.isSimulatedMode) {
      await _recorder?.closeRecorder();
      _recorder = null;
    }
    await _streamControllers.dispose();
    _state.reset();
    debugPrint('AudioService: Dispose completato, risorse rilasciate.');
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

  /// Numero massimo di tentativi
  int get maxAttempts => _state._maxAttempts;

  /// Ritardo tra una registrazione e l'altra
  Duration get delayBetweenRecordings => _delayBetweenRecordings;
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
    if (_volume == null || _volume!.isClosed) {
      _volume = StreamController<double>.broadcast();
    }
    if (_state == null || _state!.isClosed) {
      _state = StreamController<AudioState>.broadcast();
    }
    if (_progress == null || _progress!.isClosed) {
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

enum AudioState { stopped, recording, waitingNext }
