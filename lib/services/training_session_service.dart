import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recognition_result.dart';
import '../services/learning_analytics_service.dart';
import '../services/recognition_manager.dart';

/// Rappresenta una singola sessione di allenamento con tutti i suoi dettagli
class TrainingSession {
  final DateTime startTime;         // Momento di inizio della sessione
  final int targetWords;           // Obiettivo di parole da completare
  final int currentLevel;          // Livello attuale del giocatore
  List<RecognitionResult> results; // Risultati ottenuti durante la sessione
  int crystalsEarned;             // Cristalli guadagnati nella sessione
  bool isCompleted;               // Indica se la sessione è stata completata

  TrainingSession({
    required this.startTime,
    required this.targetWords,
    required this.currentLevel,
    this.results = const [],
    this.crystalsEarned = 0,
    this.isCompleted = false,
  });

  /// Converte la sessione in formato JSON per il salvataggio
  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'targetWords': targetWords,
    'currentLevel': currentLevel,
    'results': results.map((r) => r.toJson()).toList(),
    'crystalsEarned': crystalsEarned,
    'isCompleted': isCompleted,
  };

  /// Crea una sessione da un oggetto JSON
  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      startTime: DateTime.parse(json['startTime'] as String),
      targetWords: json['targetWords'] as int,
      currentLevel: json['currentLevel'] as int,
      results: (json['results'] as List)
          .map((r) => RecognitionResult.fromVoskResult(r, ''))
          .toList(),
      crystalsEarned: json['crystalsEarned'] as int,
      isCompleted: json['isCompleted'] as bool,
    );
  }
}

/// Servizio che gestisce le sessioni di allenamento e analizza le performance
class TrainingSessionService {
  // Costanti per la gestione della persistenza
  static const String _currentSessionKey = 'current_training_session';
  static const String _sessionsHistoryKey = 'training_sessions_history';

  // Dipendenze del servizio
  final SharedPreferences _prefs;
  final LearningAnalyticsService _analyticsService;
  final RecognitionManager _recognitionManager;

  // Stato interno del servizio
  TrainingSession? _currentSession;
  final _sessionController = StreamController<TrainingSession?>.broadcast();

  TrainingSessionService({
    required SharedPreferences prefs,
    required LearningAnalyticsService analyticsService,
    required RecognitionManager recognitionManager,
  }) : _prefs = prefs,
        _analyticsService = analyticsService,
        _recognitionManager = recognitionManager {
    _loadCurrentSession();
    _setupRecognitionListener();
  }

  /// Stream per osservare i cambiamenti nella sessione corrente
  Stream<TrainingSession?> get sessionStream => _sessionController.stream;

  /// Configura l'ascolto dei risultati del riconoscimento
  void _setupRecognitionListener() {
    _recognitionManager.addListener(() {
      if (_recognitionManager.lastResult != null) {
        _handleNewResult(_recognitionManager.lastResult!);
      }
    });
  }

  /// Carica la sessione corrente dalle preferenze salvate
  Future<void> _loadCurrentSession() async {
    final sessionJson = _prefs.getString(_currentSessionKey);
    if (sessionJson != null) {
      try {
        final sessionData = jsonDecode(sessionJson);
        _currentSession = TrainingSession.fromJson(sessionData);
        _sessionController.add(_currentSession);
      } catch (e) {
        print('Errore nel caricamento della sessione: $e');
      }
    }
  }

  /// Avvia una nuova sessione di allenamento
  Future<void> startNewSession(int targetWords, int currentLevel) async {
    if (_currentSession?.isCompleted == false) {
      await _saveSessionToHistory(_currentSession!);
    }

    _currentSession = TrainingSession(
      startTime: DateTime.now(),
      targetWords: targetWords,
      currentLevel: currentLevel,
    );

    await _saveCurrentSession();
    _analyticsService.startSession();
    _sessionController.add(_currentSession);
  }

  /// Gestisce un nuovo risultato di riconoscimento
  void _handleNewResult(RecognitionResult result) {
    if (_currentSession == null) return;

    _currentSession!.results.add(result);
    _currentSession!.crystalsEarned += _calculateCrystalsForResult(result);

    if (_currentSession!.results.length >= _currentSession!.targetWords) {
      _currentSession!.isCompleted = true;
      _saveSessionToHistory(_currentSession!);
      _currentSession = null;
    }

    _saveCurrentSession();
    _sessionController.add(_currentSession);
  }

  /// Calcola i cristalli guadagnati per un risultato
  int _calculateCrystalsForResult(RecognitionResult result) {
    final baseCrystals = switch (_currentSession!.currentLevel) {
      1 => 10,  // Parole
      2 => 30,  // Frasi
      3 => 50,  // Paragrafi
      4 => 100, // Pagine
      _ => 10,
    };

    double multiplier = 1.0;
    if (result.similarity >= 0.95) multiplier = 1.5;
    else if (result.similarity >= 0.90) multiplier = 1.3;
    else if (result.similarity >= 0.85) multiplier = 1.1;

    return (baseCrystals * multiplier).round();
  }

  /// Salva la sessione corrente nelle preferenze
  Future<void> _saveCurrentSession() async {
    if (_currentSession == null) {
      await _prefs.remove(_currentSessionKey);
    } else {
      final sessionJson = jsonEncode(_currentSession!.toJson());
      await _prefs.setString(_currentSessionKey, sessionJson);
    }
  }

  /// Salva una sessione completata nella cronologia
  Future<void> _saveSessionToHistory(TrainingSession session) async {
    final history = await getSessionHistory();
    history.add(session);

    // Mantiene solo le ultime 50 sessioni
    if (history.length > 50) {
      history.removeAt(0);
    }

    final historyJson = jsonEncode(
        history.map((s) => s.toJson()).toList()
    );
    await _prefs.setString(_sessionsHistoryKey, historyJson);
  }

  /// Recupera la cronologia delle sessioni
  Future<List<TrainingSession>> getSessionHistory() async {
    final historyJson = _prefs.getString(_sessionsHistoryKey);
    if (historyJson == null) return [];

    try {
      final List<dynamic> historyData = jsonDecode(historyJson);
      return historyData
          .map((data) => TrainingSession.fromJson(data))
          .toList();
    } catch (e) {
      print('Errore nel caricamento della cronologia: $e');
      return [];
    }
  }

  /// Annulla la sessione corrente
  Future<void> cancelCurrentSession() async {
    _currentSession = null;
    await _saveCurrentSession();
    _sessionController.add(null);
  }

  /// Ottiene la sessione corrente
  TrainingSession? getCurrentSession() => _currentSession;

  /// Ottiene le statistiche della sessione corrente
  Map<String, dynamic> getCurrentSessionStats() {
    if (_currentSession == null) return {};

    final results = _currentSession!.results;
    if (results.isEmpty) return {};

    final successfulAttempts = results.where((r) => r.isCorrect).length;
    final averageSimilarity = results.fold<double>(
        0, (sum, r) => sum + r.similarity) / results.length;
    final averageTime = results.fold<int>(
        0, (sum, r) => sum + r.duration.inSeconds) / results.length;

    return {
      'totalAttempts': results.length,
      'successfulAttempts': successfulAttempts,
      'accuracy': successfulAttempts / results.length,
      'averageSimilarity': averageSimilarity,
      'averageTime': averageTime,
      'crystalsEarned': _currentSession!.crystalsEarned,
      'progress': results.length / _currentSession!.targetWords,
    };
  }

  /// Rilascio delle risorse
  Future<void> dispose() async {
    await _sessionController.close();
  }
}