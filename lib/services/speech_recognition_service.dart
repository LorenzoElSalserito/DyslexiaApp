// lib/services/speech_recognition_service.dart

import 'dart:async';
import '../services/vosk_service.dart';
import '../services/audio_service.dart';
import '../models/recognition_result.dart';
import '../models/enums.dart';  // Aggiunto import per AudioState

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
/// gestendo sia singole registrazioni che sessioni multiple
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
    _setupAudioServiceListeners();
  }

  // Configurazione dei listener per l'AudioService
  void _setupAudioServiceListeners() {
    _audioService.volumeLevel.listen(_volumeController.add);
    _audioService.recordingProgress.listen((progress) {
      _currentAttempt = progress;
      _progressController.add(progress);
    });

    _audioService.audioState.listen((audioState) {
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
    try {
      // Inizializza entrambi i servizi in parallelo
      await Future.wait([
        _voskService.initialize(),
        _audioService.initialize(),
      ]);
      _updateState(RecognitionState.idle);
    } catch (e) {
      _handleError('Errore nell\'inizializzazione: $e');
    }
  }

  /// Avvia il riconoscimento vocale per un testo target
  Future<void> startRecognition(String targetText) async {
    if (_state != RecognitionState.idle) return;

    try {
      _currentTargetText = targetText;
      _sessionStartTime = DateTime.now();
      _updateState(RecognitionState.recording);
      await _audioService.startRecording();
    } catch (e) {
      _handleError('Errore nell\'avvio del riconoscimento: $e');
    }
  }

  /// Ferma il riconoscimento vocale in corso
  Future<void> stopRecognition() async {
    if (_state != RecognitionState.recording) return;

    try {
      _updateState(RecognitionState.processing);
      final audioPath = await _audioService.stopRecording();

      if (audioPath.isNotEmpty && _currentTargetText != null) {
        final result = await _voskService.startRecognition(_currentTargetText!);
        _resultController.add(result);
        _currentSessionResults.add(result);

        // Se la sessione è completa, aggiorna lo stato
        if (_audioService.isSessionComplete) {
          _updateState(RecognitionState.completed);
        } else {
          _updateState(RecognitionState.waiting);
        }
      }
    } catch (e) {
      _handleError('Errore nello stop del riconoscimento: $e');
    }
  }

  /// Aggiorna lo stato del servizio
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

  /// Rilascia le risorse utilizzate
  Future<void> dispose() async {
    await Future.wait([
      _stateController.close(),
      _volumeController.close(),
      _resultController.close(),
      _progressController.close(),
      _errorController.close(),
    ]);
    await _audioService.dispose();
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