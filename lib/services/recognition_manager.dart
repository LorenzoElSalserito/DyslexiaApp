import 'package:flutter/foundation.dart';
import '../models/recognition_result.dart';
import '../services/speech_recognition_service.dart';
import '../models/enums.dart';
import '../config/app_config.dart';


/// Il RecognitionManager è responsabile di coordinare il processo di riconoscimento vocale,
/// gestire i risultati e mantenere le statistiche della sessione corrente.
class RecognitionManager extends ChangeNotifier {
  // Il servizio di riconoscimento vocale sottostante
  final SpeechRecognitionService _speechService;

  // Stati del riconoscimento
  bool _isRecording = false;
  RecognitionResult? _lastResult;
  String? _currentText;
  String? _targetText;
  String? _lastError;
  double _volumeLevel = 0.0;

  // Statistiche della sessione
  List<RecognitionResult> _sessionResults = [];
  int _totalAttempts = 0;
  int _successfulAttempts = 0;

  /// Costruisce un nuovo manager con il servizio di riconoscimento fornito
  RecognitionManager({
    required SpeechRecognitionService speechService,
  }) : _speechService = speechService {
    _initializeListeners();
  }

  /// Inizializza gli ascoltatori per i vari eventi del servizio di riconoscimento
  void _initializeListeners() {
    // Monitora il livello del volume in tempo reale
    _speechService.volumeStream.listen((volume) {
      _volumeLevel = volume;
      notifyListeners();
    });

    // Gestisce i risultati del riconoscimento vocale
    _speechService.resultStream.listen((result) {
      _handleRecognitionResult(result);
    });

    // Gestisce gli errori del servizio
    _speechService.errorStream.listen((error) {
      _lastError = error;
      notifyListeners();
    });
  }

  /// Avvia una nuova sessione di riconoscimento con il testo target fornito
  Future<void> startNewRecognition(String text) async {
    if (_isRecording) return;

    _targetText = text;
    if (_targetText == null) {
      _lastError = 'Nessun testo disponibile per il riconoscimento';
      notifyListeners();
      return;
    }

    try {
      await _speechService.startRecognition(_targetText!);
      _totalAttempts++;
      _isRecording = true;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Errore nell\'avvio del riconoscimento: $e';
      notifyListeners();
    }
  }

  /// Ferma la sessione di riconoscimento corrente
  Future<void> stopRecognition() async {
    if (!_isRecording) return;

    try {
      await _speechService.stopRecognition();
      _isRecording = false;
      notifyListeners();
    } catch (e) {
      _lastError = 'Errore nello stop del riconoscimento: $e';
      notifyListeners();
    }
  }

  /// Gestisce il risultato del riconoscimento vocale.
  Future<void> _handleRecognitionResult(RecognitionResult result) async {
    if (_currentText == null || _targetText == null) return;

    try {
      // Usiamo direttamente la similarity calcolata da VOSK che è già presente nel result
      final similarity = result.similarity;

      if (similarity >= AppConfig.minSimilarityScore) {
        _successfulAttempts++;
        _resetForNextAttempt();
      }

      _lastResult = result;
      _sessionResults.add(result);

      notifyListeners();
    } catch (e) {
      _lastError = 'Errore nel processare il risultato: $e';
      notifyListeners();
    }
  }

  /// Elabora un tentativo riuscito di riconoscimento
  void _processSuccessfulAttempt(RecognitionResult result) {
    try {
      if (_targetText != null) {
        double similarity = result.similarity;

        // Verifica se il risultato supera la soglia di successo
        if (similarity >= 0.85) {
          _successfulAttempts++;
          _resetForNextAttempt();
        }
      }
    } catch (e) {
      _lastError = 'Errore nel processare il risultato: $e';
      notifyListeners();
    }
  }

  /// Resetta lo stato per il prossimo tentativo
  void _resetForNextAttempt() {
    _currentText = null;
    _lastResult = null;
    _isRecording = false;
    notifyListeners();
  }

  /// Resetta completamente la sessione corrente
  void _resetSession() {
    _sessionResults.clear();
    _totalAttempts = 0;
    _successfulAttempts = 0;
    _lastResult = null;
    _currentText = null;
    _isRecording = false;
    notifyListeners();
  }

  /// Calcola l'accuratezza della sessione corrente
  double get sessionAccuracy {
    if (_totalAttempts == 0) return 0.0;
    return _successfulAttempts / _totalAttempts;
  }

  /// Calcola la similarità media dei risultati della sessione
  double get averageSimilarity {
    if (_sessionResults.isEmpty) return 0.0;
    final total = _sessionResults
        .map((r) => r.similarity)
        .reduce((a, b) => a + b);
    return total / _sessionResults.length;
  }

  // Getters per accedere allo stato del manager
  RecognitionResult? get lastResult => _lastResult;
  String? get currentText => _currentText;
  String? get lastError => _lastError;
  double get volumeLevel => _volumeLevel;
  bool get isRecording => _isRecording;
  int get totalAttempts => _totalAttempts;
  int get successfulAttempts => _successfulAttempts;
  List<RecognitionResult> get sessionResults => List.unmodifiable(_sessionResults);

  @override
  void dispose() {
    _speechService.dispose();
    super.dispose();
  }
}