// recognition_manager.dart

import 'package:flutter/foundation.dart';
import '../models/recognition_result.dart';
import '../services/speech_recognition_service.dart';
import '../services/game_service.dart';
import '../utils/text_similarity.dart';

class RecognitionManager extends ChangeNotifier {
  final SpeechRecognitionService _speechService;
  final GameService _gameService;

  RecognitionState _currentState = RecognitionState.idle;
  RecognitionResult? _lastResult;
  String? _currentText;
  String? _lastError;
  double _volumeLevel = 0.0;

  List<RecognitionResult> _sessionResults = [];
  int _totalAttempts = 0;
  int _successfulAttempts = 0;

  RecognitionManager({
    required SpeechRecognitionService speechService,
    required GameService gameService,
  }) : _speechService = speechService,
        _gameService = gameService {
    _initializeListeners();
  }

  void _initializeListeners() {
    // Ascolta i cambiamenti di stato
    _speechService.stateStream.listen((state) {
      _currentState = state;
      notifyListeners();
    });

    // Ascolta il livello del volume
    _speechService.volumeStream.listen((volume) {
      _volumeLevel = volume;
      notifyListeners();
    });

    // Ascolta i risultati
    _speechService.resultStream.listen((result) {
      _handleRecognitionResult(result);
    });

    // Ascolta gli errori
    _speechService.errorStream.listen((error) {
      _lastError = error;
      notifyListeners();
    });
  }

  Future<void> startNewRecognition() async {
    if (_currentState != RecognitionState.idle) return;

    _currentText = _gameService.getCurrentText();
    if (_currentText == null) {
      _lastError = 'Nessun testo disponibile per il riconoscimento';
      notifyListeners();
      return;
    }

    try {
      await _speechService.startRecognition(_currentText!);
      _totalAttempts++;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Errore nell\'avvio del riconoscimento: $e';
      notifyListeners();
    }
  }

  Future<void> stopRecognition() async {
    if (_currentState != RecognitionState.recording) return;

    try {
      await _speechService.stopRecognition();
    } catch (e) {
      _lastError = 'Errore nello stop del riconoscimento: $e';
      notifyListeners();
    }
  }

  void _handleRecognitionResult(RecognitionResult result) {
    _lastResult = result;
    _sessionResults.add(result);

    if (result.isCorrect) {
      _successfulAttempts++;
      _processSuccessfulAttempt(result);
    }

    notifyListeners();
  }

  Future<void> _processSuccessfulAttempt(RecognitionResult result) async {
    try {
      // Calcola i cristalli guadagnati basandosi sulla performance
      bool levelCompleted = await _gameService.processRecognitionResult(result);

      if (levelCompleted) {
        _resetSession();
      }
    } catch (e) {
      _lastError = 'Errore nel processare il risultato: $e';
      notifyListeners();
    }
  }

  void _resetSession() {
    _sessionResults.clear();
    _totalAttempts = 0;
    _successfulAttempts = 0;
    _lastResult = null;
    _currentText = null;
    notifyListeners();
  }

  // Metodi per ottenere statistiche della sessione
  double get sessionAccuracy {
    if (_totalAttempts == 0) return 0.0;
    return _successfulAttempts / _totalAttempts;
  }

  double get averageSimilarity {
    if (_sessionResults.isEmpty) return 0.0;
    final total = _sessionResults
        .map((r) => r.similarity)
        .reduce((a, b) => a + b);
    return total / _sessionResults.length;
  }

  List<RecognitionResult> get sessionResults => List.unmodifiable(_sessionResults);

  // Getters per lo stato corrente
  RecognitionState get currentState => _currentState;
  RecognitionResult? get lastResult => _lastResult;
  String? get currentText => _currentText;
  String? get lastError => _lastError;
  double get volumeLevel => _volumeLevel;
  bool get isRecording => _currentState == RecognitionState.recording;
  int get totalAttempts => _totalAttempts;
  int get successfulAttempts => _successfulAttempts;

  @override
  void dispose() {
    _speechService.dispose();
    super.dispose();
  }
}