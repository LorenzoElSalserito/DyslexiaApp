// speech_recognition_service.dart

import 'dart:async';
import '../services/vosk_service.dart';
import '../services/audio_service.dart';
import '../models/recognition_result.dart';

/// Definisce i possibili stati del processo di riconoscimento vocale
enum RecognitionState {
  idle,         // In attesa di iniziare
  initializing, // Inizializzazione dei servizi
  recording,    // Registrazione in corso
  processing,   // Elaborazione del risultato
  completed,    // Riconoscimento completato
  error         // Errore durante il processo
}

/// Servizio che coordina il processo di riconoscimento vocale,
/// integrando il servizio audio con il motore VOSK
class SpeechRecognitionService {
  // Servizi fondamentali per il riconoscimento
  final VoskService _voskService;
  final AudioService _audioService;

  // Gestione dello stato interno
  RecognitionState _state = RecognitionState.idle;
  String? _currentTargetText;

  // Stream controllers per la comunicazione con l'esterno
  final _stateController = StreamController<RecognitionState>.broadcast();
  final _volumeController = StreamController<double>.broadcast();
  final _resultController = StreamController<RecognitionResult>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  // Stream pubblici per osservare gli eventi del servizio
  Stream<RecognitionState> get stateStream => _stateController.stream;
  Stream<double> get volumeStream => _volumeController.stream;
  Stream<RecognitionResult> get resultStream => _resultController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Costruttore che inizializza i servizi necessari
  SpeechRecognitionService() :
        _voskService = VoskService.instance,
        _audioService = AudioService() {
    _initializeServices();
  }

  /// Inizializza i servizi di base necessari per il riconoscimento
  Future<void> _initializeServices() async {
    _updateState(RecognitionState.initializing);
    try {
      // Inizializza entrambi i servizi in parallelo
      await Future.wait([
        _voskService.initialize(),
        _audioService.initialize(),
      ]);

      // Sottoscrizione agli eventi del servizio audio
      _audioService.volumeLevel.listen((volume) {
        _volumeController.add(volume);
      });

      _updateState(RecognitionState.idle);
    } catch (e) {
      _handleError('Errore nell\'inizializzazione: $e');
    }
  }

  /// Avvia una nuova sessione di riconoscimento
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

      // Comunica il risultato agli ascoltatori
      _resultController.add(result);

      _updateState(RecognitionState.completed);
    } catch (e) {
      _handleError('Errore durante il riconoscimento: $e');
    }
  }

  /// Interrompe la sessione di riconoscimento corrente
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

  /// Annulla completamente la sessione corrente
  Future<void> cancelRecognition() async {
    try {
      await _audioService.stopRecording();
      await _voskService.stopRecognition();
      _updateState(RecognitionState.idle);
    } catch (e) {
      _handleError('Errore durante la cancellazione: $e');
    }
  }

  /// Aggiorna lo stato interno e notifica gli ascoltatori
  void _updateState(RecognitionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Gestisce gli errori in modo centralizzato
  void _handleError(String error) {
    print('SpeechRecognitionService Error: $error');
    _errorController.add(error);
    _updateState(RecognitionState.error);
  }

  /// Rilascia tutte le risorse utilizzate dal servizio
  Future<void> dispose() async {
    await cancelRecognition();
    await _stateController.close();
    await _volumeController.close();
    await _resultController.close();
    await _errorController.close();
    await _audioService.dispose();
  }

  // Getters per lo stato del servizio
  RecognitionState get currentState => _state;
  bool get isRecording => _state == RecognitionState.recording;
  String? get currentTargetText => _currentTargetText;
}