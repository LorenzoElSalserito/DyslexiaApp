// training_session_service.dart

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recognition_result.dart';
import '../services/learning_analytics_service.dart';
import '../services/game_service.dart';
import '../services/recognition_manager.dart';

class TrainingSession {
  final DateTime startTime;
  final int targetWords;
  final int currentLevel;
  List<RecognitionResult> results;
  int crystalsEarned;
  bool isCompleted;

  TrainingSession({
    required this.startTime,
    required this.targetWords,
    required this.currentLevel,
    this.results = const [],
    this.crystalsEarned = 0,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'targetWords': targetWords,
    'currentLevel': currentLevel,
    'results': results.map((r) => r.toJson()).toList(),
    'crystalsEarned': crystalsEarned,
    'isCompleted': isCompleted,
  };

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      startTime: DateTime.parse(json['startTime'] as String),
      targetWords: json['targetWords'] as int,
      currentLevel: json['currentLevel'] as int,
      results: (json['results'] as List).map((r) => RecognitionResult.fromVoskResult(r, '')).toList(),
      crystalsEarned: json['crystalsEarned'] as int,
      isCompleted: json['isCompleted'] as bool,
    );
  }
}

class TrainingSessionService {
  final SharedPreferences _prefs;
  final LearningAnalyticsService _analyticsService;
  final GameService _gameService;
  final RecognitionManager _recognitionManager;

  static const String _currentSessionKey = 'current_training_session';
  static const String _sessionsHistoryKey = 'training_sessions_history';

  TrainingSession? _currentSession;
  final _sessionController = StreamController<TrainingSession?>.broadcast();

  TrainingSessionService({
    required SharedPreferences prefs,
    required LearningAnalyticsService analyticsService,
    required GameService gameService,
    required RecognitionManager recognitionManager,
  }) : _prefs = prefs,
        _analyticsService = analyticsService,
        _gameService = gameService,
        _recognitionManager = recognitionManager {
    _loadCurrentSession();
    _setupRecognitionListener();
  }

  Stream<TrainingSession?> get sessionStream => _sessionController.stream;

  void _setupRecognitionListener() {
    _recognitionManager.addListener(() {
      if (_recognitionManager.lastResult != null) {
        _handleNewResult(_recognitionManager.lastResult!);
      }
    });
  }

  Future<void> _loadCurrentSession() async {
    final sessionJson = _prefs.getString(_currentSessionKey);
    if (sessionJson != null) {
      _currentSession = TrainingSession.fromJson(
          Map<String, dynamic>.from(json.decode(sessionJson))
      );
      _sessionController.add(_currentSession);
    }
  }

  Future<void> startNewSession() async {
    if (_currentSession?.isCompleted == false) {
      await _saveSessionToHistory(_currentSession!);
    }

    _currentSession = TrainingSession(
      startTime: DateTime.now(),
      targetWords: _gameService.currentLevelTarget,
      currentLevel: _gameService.player.currentLevel,
    );

    await _saveCurrentSession();
    _analyticsService.startSession();
    _sessionController.add(_currentSession);
  }

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

  int _calculateCrystalsForResult(RecognitionResult result) {
    // Base di cristalli per livello
    final baseCrystals = switch (_currentSession!.currentLevel) {
      1 => 10,  // Parole
      2 => 30,  // Frasi
      3 => 50,  // Paragrafi
      4 => 100, // Pagine
      _ => 10,
    };

    // Calcola bonus basato sulla performance
    double multiplier = 1.0;
    if (result.similarity >= 0.95) multiplier = 1.5;
    else if (result.similarity >= 0.90) multiplier = 1.3;
    else if (result.similarity >= 0.85) multiplier = 1.1;

    return (baseCrystals * multiplier).round();
  }

  Future<void> _saveCurrentSession() async {
    if (_currentSession == null) {
      await _prefs.remove(_currentSessionKey);
    } else {
      await _prefs.setString(
        _currentSessionKey,
        json.encode(_currentSession!.toJson()),
      );
    }
  }

  Future<void> _saveSessionToHistory(TrainingSession session) async {
    final history = await getSessionHistory();
    history.add(session);

    // Mantieni solo le ultime 50 sessioni
    if (history.length > 50) {
      history.removeAt(0);
    }

    await _prefs.setString(
      _sessionsHistoryKey,
      json.encode(history.map((s) => s.toJson()).toList()),
    );
  }

  Future<List<TrainingSession>> getSessionHistory() async {
    final historyJson = _prefs.getString(_sessionsHistoryKey);
    if (historyJson == null) return [];

    final historyList = json.decode(historyJson) as List;
    return historyList
        .map((s) => TrainingSession.fromJson(Map<String, dynamic>.from(s)))
        .toList();
  }

  Future<void> cancelCurrentSession() async {
    _currentSession = null;
    await _saveCurrentSession();
    _sessionController.add(null);
  }

  TrainingSession? getCurrentSession() => _currentSession;

  // Statistiche della sessione corrente
  Map<String, dynamic> getCurrentSessionStats() {
    if (_currentSession == null) return {};

    final results = _currentSession!.results;
    if (results.isEmpty) return {};

    final successfulAttempts = results.where((r) => r.isCorrect).length;
    final averageSimilarity = results.fold<double>(0, (sum, r) => sum + r.similarity) / results.length;
    final averageTime = results.fold<double>(0, (sum, r) => sum + r.duration.inSeconds) / results.length;

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

  Future<void> dispose() async {
    await _sessionController.close();
  }
}