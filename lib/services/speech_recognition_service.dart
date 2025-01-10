// speech_recognition_service.dart

import 'dart:async';
import '../services/vosk_service.dart';
import '../services/audio_service.dart';
import '../models/recognition_result.dart';

enum RecognitionState {
  idle,
  initializing,
  recording,
  processing,
  completed,
  error
}

class SpeechRecognitionService {
  final VoskService _voskService;
  final AudioService _audioService;

  RecognitionState _state = RecognitionState.idle;
  String? _currentTargetText;

  final _stateController = StreamController<RecognitionState>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _resultController = StreamController<RecognitionResult>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Streams pubblici
  Stream<RecognitionState> get stateStream => _stateController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<RecognitionResult> get resultStream => _resultController.stream;
  Stream<String> get errorStream => _errorController.stream;

  SpeechRecognitionService() :
        _voskService = VoskService.instance,
        _audioService = AudioService() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _updateState(RecognitionState.initializing);
    try {
      // Inizializza entrambi i servizi
      await Future.wait([
        _voskService.initialize(),
        _audioService.initialize(),
      ]);

      // Sottoscrivi agli stream dell'audio service
      _audioService.volumeLevel.listen((volume) {
        _volumeController.add(volume);
      });

      _updateState(RecognitionState.idle);
    } catch (e) {
      _handleError('Errore nell\'inizializzazione: $e');
    }
  }

  Future<void> startRecognition(String targetText) async {
    if (_state != RecognitionState.idle) return;

    try {
      _currentTargetText = targetText;
      _updateState(RecognitionState.recording);

      // Avvia la registrazione audio
      await _audioService.startRecording();

      // Avvia il riconoscimento VOSK
      final result = await _voskService.startRecognition(targetText);

      _updateState(RecognitionState.processing);

      // Emetti il risultato
      _resultController.add(result);

      _updateState(RecognitionState.completed);
    } catch (e) {
      _handleError('Errore durante il riconoscimento: $e');
    }
  }

  Future<void> stopRecognition() async {
    if (_state != RecognitionState.recording) return;

    try {
      // Ferma la registrazione audio
      await _audioService.stopRecording();

      // Ferma il riconoscimento VOSK
      await _voskService.stopRecognition();

      _updateState(RecognitionState.processing);
    } catch (e) {
      _handleError('Errore durante lo stop del riconoscimento: $e');
    }
  }

  Future<void> cancelRecognition() async {
    try {
      await _audioService.stopRecording();
      await _voskService.stopRecognition();
      _updateState(RecognitionState.idle);
    } catch (e) {
      _handleError('Errore durante la cancellazione: $e');
    }
  }

  void _updateState(RecognitionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _handleError(String error) {
    print('SpeechRecognitionService Error: $error');
    _errorController.add(error);
    _updateState(RecognitionState.error);
  }

  Future<void> dispose() async {
    await cancelRecognition();
    await _stateController.close();
    await _volumeController.close();
    await _resultController.close();
    await _errorController.close();
    await _audioService.dispose();
  }

  // Getters utili
  RecognitionState get currentState => _state;
  bool get isRecording => _state == RecognitionState.recording;
  String? get currentTargetText => _currentTargetText;
}