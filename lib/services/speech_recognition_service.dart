// lib/services/speech_recognition_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart'; // Per debugPrint
import '../services/vosk_service.dart';
import '../services/audio_service.dart';
import '../models/recognition_result.dart';

/// Definisce i possibili stati del processo di riconoscimento vocale
enum RecognitionState {
  idle,         // In attesa di iniziare
  initializing, // Inizializzazione dei servizi
  recording,    // Registrazione in corso
  processing,   // Elaborazione del risultato
  waiting,      // In attesa della prossima registrazione
  completed,    // Riconoscimento completato
  error         // Errore durante il processo
}

/// Servizio che coordina il processo di riconoscimento vocale,
/// gestendo sia singole registrazioni che sessioni multiple.
class SpeechRecognitionService {
  // Servizi di base
  final VoskService _voskService;
  final AudioService _audioService;

  // Gestione dello stato
  RecognitionState _state = RecognitionState.idle;
  String? _currentTargetText;
  DateTime? _sessionStartTime;
  final List<RecognitionResult> _currentSessionResults = [];
  int _currentAttempt = 0;

  // Stream controllers per la comunicazione con l'UI
  final _stateController = StreamController<RecognitionState>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _resultController = StreamController<RecognitionResult>.broadcast();
  final _progressController = StreamController<int>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Stream pubblici
  Stream<RecognitionState> get stateStream => _stateController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<RecognitionResult> get resultStream => _resultController.stream;
  Stream<int> get progressStream => _progressController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Costruttore
  SpeechRecognitionService()
      : _voskService = VoskService.instance,
        _audioService = AudioService() {
    debugPrint('SpeechRecognitionService: Inizializzazione del servizio.');
    _setupAudioServiceListeners();
  }

  // Configurazione dei listener per l'AudioService
  void _setupAudioServiceListeners() {
    _audioService.volumeLevel.listen((volume) {
      debugPrint('SpeechRecognitionService: Volume aggiornato: $volume');
      _volumeController.add(volume);
    });
    _audioService.recordingProgress.listen((progress) {
      _currentAttempt = progress;
      debugPrint('SpeechRecognitionService: Progresso registrazione: $progress');
      _progressController.add(progress);
    });
    _audioService.audioState.listen((audioState) {
      debugPrint('SpeechRecognitionService: Stato audio ricevuto: $audioState');
      switch (audioState) {
        case AudioState.recording:
          _updateState(RecognitionState.recording);
          break;
        case AudioState.waitingNext:
          _updateState(RecognitionState.waiting);
          break;
        case AudioState.stopped:
          if (_audioService.isSessionComplete) {
            _updateState(RecognitionState.completed);
          }
          break;
        default:
          break;
      }
    });
  }

  /// Inizializza i servizi necessari
  Future<void> initialize() async {
    _updateState(RecognitionState.initializing);
    debugPrint('SpeechRecognitionService: Inizializzazione in corso...');
    try {
      await Future.wait([
        _voskService.initialize(),
        _audioService.initialize(),
      ]);
      _updateState(RecognitionState.idle);
      debugPrint('SpeechRecognitionService: Inizializzazione completata.');
    } catch (e) {
      _handleError('Errore nell\'inizializzazione: $e');
    }
  }

  /// Avvia il riconoscimento vocale per un testo target
  Future<void> startRecognition(String targetText) async {
    debugPrint('SpeechRecognitionService: startRecognition() chiamato per target: $targetText');
    if (_state != RecognitionState.idle) {
      debugPrint('SpeechRecognitionService: startRecognition() non eseguito. Stato corrente: $_state');
      return;
    }
    try {
      _currentTargetText = targetText;
      _sessionStartTime = DateTime.now();
      _updateState(RecognitionState.recording);
      await _audioService.startRecording();
      debugPrint('SpeechRecognitionService: Registrazione avviata.');
    } catch (e) {
      _handleError('Errore nell\'avvio del riconoscimento: $e');
    }
  }

  /// Ferma il riconoscimento vocale in corso
  Future<void> stopRecognition() async {
    debugPrint('SpeechRecognitionService: stopRecognition() chiamato.');
    if (_state != RecognitionState.recording) {
      debugPrint('SpeechRecognitionService: stopRecognition() non eseguito. Stato corrente: $_state');
      return;
    }
    try {
      _updateState(RecognitionState.processing);
      final audioPath = await _audioService.stopRecording();
      debugPrint('SpeechRecognitionService: Registrazione stoppata. File audio: $audioPath');
      if (audioPath.isNotEmpty && _currentTargetText != null) {
        final result = await _voskService.startRecognition(_currentTargetText!);
        debugPrint('SpeechRecognitionService: Risultato ottenuto: ${result.text}');
        debugPrint('SpeechRecognitionService: Similarità: ${result.similarity}');
        _resultController.add(result);
        _currentSessionResults.add(result);
        if (_audioService.isSessionComplete) {
          _updateState(RecognitionState.completed);
        } else {
          _updateState(RecognitionState.waiting);
        }
      } else {
        _handleError('File audio vuoto o testo target non impostato.');
      }
    } catch (e) {
      _handleError('Errore nello stop del riconoscimento: $e');
    }
  }

  /// Aggiorna lo stato del servizio
  void _updateState(RecognitionState newState) {
    _state = newState;
    debugPrint('SpeechRecognitionService: Stato aggiornato a $_state');
    _stateController.add(newState);
  }

  /// Gestisce gli errori in modo centralizzato
  void _handleError(String error) {
    debugPrint('SpeechRecognitionService Error: $error');
    _errorController.add(error);
    _updateState(RecognitionState.error);
  }

  /// Rilascia le risorse utilizzate
  Future<void> dispose() async {
    debugPrint('SpeechRecognitionService: Dispose chiamato.');
    await Future.wait([
      _stateController.close(),
      _volumeController.close(),
      _resultController.close(),
      _progressController.close(),
      _errorController.close(),
    ]);
    await _audioService.dispose();
    debugPrint('SpeechRecognitionService: Dispose completato.');
  }

  // Getters pubblici
  RecognitionState get currentState => _state;
  bool get isRecording => _state == RecognitionState.recording;
  String? get currentTargetText => _currentTargetText;
  int get currentAttempt => _currentAttempt;
  int get maxAttempts => _audioService.maxAttempts;
  bool get isSessionComplete => _audioService.isSessionComplete;
  Duration get delayBetweenRecordings => _audioService.delayBetweenRecordings;
  List<RecognitionResult> get currentResults => List.unmodifiable(_currentSessionResults);
}
