// lib/services/speech_recognition_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/recognition_result.dart';
import '../services/audio_service.dart';
import '../services/vosk_service.dart';

/// Stati del processo di riconoscimento vocale
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
/// utilizzando flutter_sound per la registrazione e VOSK per il riconoscimento.
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
  bool _isProcessing = false;
  bool _hasDetectedSpeech = false;
  double _volumeThreshold = 0.1; // Soglia minima di volume per considerare parlato

  // Stream controllers
  final _stateController = StreamController<RecognitionState>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _resultController = StreamController<RecognitionResult>.broadcast();
  final _progressController = StreamController<int>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Sottoscrizioni agli stream
  StreamSubscription? _volumeSubscription;

  SpeechRecognitionService()
      : _voskService = VoskService.instance,
        _audioService = AudioService() {
    debugPrint('SpeechRecognitionService: Inizializzazione del servizio.');
  }

  Future<void> initialize(BuildContext context) async {
    if (_state == RecognitionState.initializing) return;

    _updateState(RecognitionState.initializing);
    debugPrint('SpeechRecognitionService: Inizializzazione in corso...');

    try {
      // Inizializza VOSK
      await _voskService.initialize();

      // Inizializza il servizio audio
      await _audioService.initialize();

      // Configura il listener per il volume
      _volumeSubscription = _audioService.volumeLevel.listen((volume) {
        _volumeController.add(volume);
        if (volume > _volumeThreshold) {
          _hasDetectedSpeech = true;
        }
      });

      _updateState(RecognitionState.idle);
      debugPrint('SpeechRecognitionService: Inizializzazione completata.');
    } catch (e) {
      _handleError('Errore nell\'inizializzazione: $e');
    }
  }

  Future<void> startRecognition(String targetText) async {
    debugPrint('SpeechRecognitionService: startRecognition() chiamato per target: $targetText');

    if (_state != RecognitionState.idle && _state != RecognitionState.completed) {
      debugPrint('SpeechRecognitionService: Stato non valido per avviare il riconoscimento: $_state');
      return;
    }

    try {
      _currentTargetText = targetText;
      _sessionStartTime = DateTime.now();
      _hasDetectedSpeech = false;
      _updateState(RecognitionState.recording);

      final recordingPath = await _audioService.startRecording();
      if (recordingPath.isEmpty) {
        throw Exception('Percorso registrazione non valido');
      }

      debugPrint('SpeechRecognitionService: Registrazione avviata.');
    } catch (e) {
      _handleError('Errore nell\'avvio del riconoscimento: $e');
    }
  }

  Future<void> stopRecognition() async {
    debugPrint('SpeechRecognitionService: stopRecognition() chiamato.');

    if (_state != RecognitionState.recording) {
      debugPrint('SpeechRecognitionService: Stato non valido per fermare il riconoscimento: $_state');
      return;
    }

    try {
      _isProcessing = true;
      _updateState(RecognitionState.processing);

      final audioPath = await _audioService.stopRecording();
      debugPrint('SpeechRecognitionService: Registrazione fermata. File audio: $audioPath');

      if (!_hasDetectedSpeech) {
        debugPrint('SpeechRecognitionService: Nessun parlato rilevato durante la registrazione');
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
        throw Exception('File audio vuoto o testo target non impostato');
      }
    } catch (e) {
      _handleError('Errore nello stop del riconoscimento: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _handleNoSpeechDetected() {
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
    debugPrint('SpeechRecognitionService: Reset chiamato.');
    _currentTargetText = null;
    _sessionStartTime = null;
    _currentSessionResults.clear();
    _currentAttempt = 0;
    _isProcessing = false;
    _hasDetectedSpeech = false;

    // Reinizializza i servizi
    await _audioService.dispose();
    await _audioService.initialize();

    _updateState(RecognitionState.idle);
    debugPrint('SpeechRecognitionService: Reset completato.');
  }

  void _updateState(RecognitionState newState) {
    _state = newState;
    debugPrint('SpeechRecognitionService: Stato aggiornato a $_state');
    _stateController.add(newState);
  }

  void _handleError(String error) {
    debugPrint('SpeechRecognitionService Error: $error');
    _errorController.add(error);
    _updateState(RecognitionState.error);
  }

  Future<void> dispose() async {
    debugPrint('SpeechRecognitionService: Dispose chiamato.');
    await _volumeSubscription?.cancel();
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
}