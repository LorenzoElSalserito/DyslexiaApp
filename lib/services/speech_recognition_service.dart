// lib/services/speech_recognition_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/recognition_result.dart';
import '../services/audio_service.dart';
import '../services/vosk_service.dart';
import '../models/enums.dart';

/// Stati possibili del riconoscimento vocale
enum RecognitionState {
  idle,         // In attesa di iniziare
  initializing, // Inizializzazione in corso
  recording,    // Registrazione in corso
  processing,   // Elaborazione audio
  waiting,      // In attesa del prossimo tentativo
  completed,    // Sessione completata
  error,        // Errore nel riconoscimento
}

class SpeechRecognitionService {
  // Servizi di base
  final VoskService _voskService;
  final AudioService _audioService;

  // Stato del servizio
  RecognitionState _state = RecognitionState.idle;
  String? _currentTargetText;
  DateTime? _sessionStartTime;
  final List<RecognitionResult> _currentSessionResults = [];
  int _currentAttempt = 0;
  bool _isProcessing = false;
  bool _hasDetectedSpeech = false;
  double _volumeThreshold = AppConfig.volumeThreshold;

  // Stream controllers
  final _stateController = StreamController<RecognitionState>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _resultController = StreamController<RecognitionResult>.broadcast();
  final _progressController = StreamController<int>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Subscriptions
  StreamSubscription? _volumeSubscription;
  StreamSubscription? _audioStateSubscription;

  // Mutex per operazioni mutualmente esclusive
  bool _operationInProgress = false;
  final List<Completer<void>> _operationQueue = [];

  SpeechRecognitionService()
      : _voskService = VoskService.instance,
        _audioService = AudioService() {
    debugPrint('SpeechRecognitionService: Inizializzazione');
    _setupAudioSubscriptions();
  }

  void _setupAudioSubscriptions() {
    _volumeSubscription = _audioService.volumeLevel.listen(
          (volume) {
        _volumeController.add(volume);
        if (volume > _volumeThreshold) {
          _hasDetectedSpeech = true;
        }
      },
      onError: (error) {
        debugPrint('Errore nel monitoraggio del volume: $error');
        _handleError('Errore nel monitoraggio del volume: $error');
      },
    );

    _audioStateSubscription = _audioService.audioState.listen(
          (audioState) {
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
            } else {
              _updateState(RecognitionState.idle);
            }
            break;
          case AudioState.paused:
            _updateState(RecognitionState.waiting);
            break;
        }
      },
      onError: (error) {
        debugPrint('Errore nel monitoraggio dello stato audio: $error');
        _handleError('Errore nel monitoraggio dello stato audio: $error');
      },
    );
  }

  Future<void> initialize(BuildContext context) async {
    await _executeExclusive(() async {
      if (_state == RecognitionState.initializing) return;

      _updateState(RecognitionState.initializing);
      debugPrint('SpeechRecognitionService: Inizializzazione in corso...');

      try {
        await _voskService.initialize(context: context);
        await _audioService.initialize();

        _updateState(RecognitionState.idle);
        debugPrint('SpeechRecognitionService: Inizializzazione completata');
      } catch (e) {
        _handleError('Errore nell\'inizializzazione: $e');
        _updateState(RecognitionState.error);
        rethrow;
      }
    });
  }

  Future<void> startRecognition(String targetText) async {
    await _executeExclusive(() async {
      debugPrint('SpeechRecognitionService: Avvio riconoscimento per: $targetText');

      if (_state != RecognitionState.idle && _state != RecognitionState.completed) {
        debugPrint('SpeechRecognitionService: Stato non valido per avvio: $_state');
        return;
      }

      try {
        _currentTargetText = targetText;
        _sessionStartTime = DateTime.now();
        _hasDetectedSpeech = false;
        _isProcessing = false;

        await _audioService.startRecording();

        _updateState(RecognitionState.recording);
        debugPrint('SpeechRecognitionService: Registrazione avviata');
      } catch (e) {
        _handleError('Errore nell\'avvio del riconoscimento: $e');
        _updateState(RecognitionState.error);
      }
    });
  }

  Future<void> stopRecognition() async {
    await _executeExclusive(() async {
      debugPrint('SpeechRecognitionService: Stop riconoscimento');

      if (_state != RecognitionState.recording) {
        debugPrint('SpeechRecognitionService: Stato non valido per stop: $_state');
        return;
      }

      try {
        _isProcessing = true;
        _updateState(RecognitionState.processing);

        final audioPath = await _audioService.stopRecording();
        debugPrint('SpeechRecognitionService: Registrazione fermata: $audioPath');

        if (!_hasDetectedSpeech) {
          debugPrint('SpeechRecognitionService: Nessun parlato rilevato');
          _handleNoSpeechDetected();
          return;
        }

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
          throw Exception('File audio o testo target non validi');
        }
      } catch (e) {
        _handleError('Errore nello stop del riconoscimento: $e');
        _updateState(RecognitionState.error);
      } finally {
        _isProcessing = false;
      }
    });
  }

  void _handleNoSpeechDetected() {
    debugPrint('SpeechRecognitionService: Gestione assenza parlato');

    final emptyResult = RecognitionResult(
      text: '',
      confidence: 0.0,
      similarity: 0.0,
      isCorrect: false,
      duration: DateTime.now().difference(_sessionStartTime!),
    );

    _resultController.add(emptyResult);
    _currentSessionResults.add(emptyResult);

    if (_audioService.isSessionComplete) {
      _updateState(RecognitionState.completed);
    } else {
      _updateState(RecognitionState.waiting);
    }
  }

  Future<void> reset() async {
    await _executeExclusive(() async {
      debugPrint('SpeechRecognitionService: Reset chiamato');

      _currentTargetText = null;
      _sessionStartTime = null;
      _currentSessionResults.clear();
      _currentAttempt = 0;
      _isProcessing = false;
      _hasDetectedSpeech = false;

      await _audioService.dispose();
      await _audioService.initialize();

      _updateState(RecognitionState.idle);
      debugPrint('SpeechRecognitionService: Reset completato');
    });
  }

  void _updateState(RecognitionState newState) {
    _state = newState;
    debugPrint('SpeechRecognitionService: Stato aggiornato a $_state');
    _stateController.add(newState);
  }

  void _handleError(String error) {
    debugPrint('SpeechRecognitionService Error: $error');
    _errorController.add(error);
  }

  Future<void> _executeExclusive(Future<void> Function() operation) async {
    if (_operationInProgress) {
      final completer = Completer<void>();
      _operationQueue.add(completer);
      await completer.future;
    }

    _operationInProgress = true;
    try {
      await operation();
    } finally {
      _operationInProgress = false;
      if (_operationQueue.isNotEmpty) {
        final nextOperation = _operationQueue.removeAt(0);
        nextOperation.complete();
      }
    }
  }

  Future<void> dispose() async {
    debugPrint('SpeechRecognitionService: Dispose chiamato');

    await _volumeSubscription?.cancel();
    await _audioStateSubscription?.cancel();

    await Future.wait([
      _stateController.close(),
      _volumeController.close(),
      _resultController.close(),
      _progressController.close(),
      _errorController.close(),
    ]);

    await _audioService.dispose();
    debugPrint('SpeechRecognitionService: Dispose completato');
  }

  // Getters pubblici
  Stream<RecognitionState> get stateStream => _stateController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<RecognitionResult> get resultStream => _resultController.stream;
  Stream<int> get progressStream => _progressController.stream;
  Stream<String> get errorStream => _errorController.stream;
  RecognitionState get currentState => _state;
  bool get isRecording => _state == RecognitionState.recording;
  String? get currentTargetText => _currentTargetText;
  int get currentAttempt => _currentAttempt;
  List<RecognitionResult> get currentResults => List.unmodifiable(_currentSessionResults);
  AudioService get audioService => _audioService;
}