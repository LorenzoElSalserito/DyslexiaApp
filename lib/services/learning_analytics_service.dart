import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recognition_result.dart';

/// Classe che rappresenta le statistiche di apprendimento dell'utente
class LearningStats {
  final int totalAttempts;
  final int successfulAttempts;
  final double averageSimilarity;
  final double averageTime;
  final Map<String, int> commonErrors;

  LearningStats({
    required this.totalAttempts,
    required this.successfulAttempts,
    required this.averageSimilarity,
    required this.averageTime,
    required this.commonErrors,
  });

  Map<String, dynamic> toJson() => {
    'totalAttempts': totalAttempts,
    'successfulAttempts': successfulAttempts,
    'averageSimilarity': averageSimilarity,
    'averageTime': averageTime,
    'commonErrors': commonErrors,
  };

  factory LearningStats.fromJson(Map<String, dynamic> json) {
    return LearningStats(
      totalAttempts: json['totalAttempts'] as int,
      successfulAttempts: json['successfulAttempts'] as int,
      averageSimilarity: json['averageSimilarity'] as double,
      averageTime: json['averageTime'] as double,
      commonErrors: Map<String, int>.from(json['commonErrors'] as Map),
    );
  }
}

/// Servizio per l'analisi e il tracciamento dell'apprendimento
class LearningAnalyticsService {
  static const String _statsKey = 'learning_stats';
  static const String _sessionKey = 'current_session';
  final SharedPreferences _prefs;

  // Stato della sessione corrente
  List<RecognitionResult> _currentSessionResults = [];
  DateTime? _sessionStartTime;

  LearningAnalyticsService(this._prefs);

  /// Inizia una nuova sessione di apprendimento
  void startSession() {
    _sessionStartTime = DateTime.now();
    _currentSessionResults.clear();
  }

  /// Aggiunge un risultato alla sessione corrente e restituisce Future<void>
  Future<void> addResult(RecognitionResult result) async {
    _currentSessionResults.add(result);
    await _saveCurrentSession();
    await _updateStats(result);
  }

  /// Salva lo stato della sessione corrente
  Future<void> _saveCurrentSession() async {
    if (_sessionStartTime == null) return;

    final sessionData = {
      'startTime': _sessionStartTime!.toIso8601String(),
      'results': _currentSessionResults.map((r) => r.toJson()).toList(),
    };

    await _prefs.setString(_sessionKey, json.encode(sessionData));
  }

  /// Aggiorna le statistiche globali con un nuovo risultato
  Future<void> _updateStats(RecognitionResult result) async {
    final currentStats = await getStats();

    final newTotalAttempts = currentStats.totalAttempts + 1;
    final newSuccessfulAttempts = currentStats.successfulAttempts +
        (result.isCorrect ? 1 : 0);

    final newAverageSimilarity = ((currentStats.averageSimilarity *
        currentStats.totalAttempts) + result.similarity) / newTotalAttempts;

    final newAverageTime = ((currentStats.averageTime *
        currentStats.totalAttempts) +
        result.duration.inSeconds) / newTotalAttempts;

    final newCommonErrors = Map<String, int>.from(currentStats.commonErrors);
    if (!result.isCorrect) {
      final error = _analyzeError(result);
      newCommonErrors[error] = (newCommonErrors[error] ?? 0) + 1;
    }

    final newStats = LearningStats(
      totalAttempts: newTotalAttempts,
      successfulAttempts: newSuccessfulAttempts,
      averageSimilarity: newAverageSimilarity,
      averageTime: newAverageTime,
      commonErrors: newCommonErrors,
    );

    await _saveStats(newStats);
  }

  String _analyzeError(RecognitionResult result) {
    return 'error_general';
  }

  Future<LearningStats> getStats() async {
    final statsJson = _prefs.getString(_statsKey);
    if (statsJson == null) {
      return LearningStats(
        totalAttempts: 0,
        successfulAttempts: 0,
        averageSimilarity: 0.0,
        averageTime: 0.0,
        commonErrors: {},
      );
    }

    return LearningStats.fromJson(json.decode(statsJson));
  }

  Future<void> _saveStats(LearningStats stats) async {
    await _prefs.setString(_statsKey, json.encode(stats.toJson()));
  }

  LearningStats getCurrentSessionStats() {
    if (_currentSessionResults.isEmpty) {
      return LearningStats(
        totalAttempts: 0,
        successfulAttempts: 0,
        averageSimilarity: 0.0,
        averageTime: 0.0,
        commonErrors: {},
      );
    }

    final successfulAttempts = _currentSessionResults
        .where((r) => r.isCorrect).length;

    final totalSimilarity = _currentSessionResults
        .fold<double>(0, (sum, result) => sum + result.similarity);

    final totalTime = _currentSessionResults
        .fold<int>(0, (sum, result) => sum + result.duration.inSeconds);

    final commonErrors = <String, int>{};
    for (var result in _currentSessionResults.where((r) => !r.isCorrect)) {
      final error = _analyzeError(result);
      commonErrors[error] = (commonErrors[error] ?? 0) + 1;
    }

    return LearningStats(
      totalAttempts: _currentSessionResults.length,
      successfulAttempts: successfulAttempts,
      averageSimilarity: totalSimilarity / _currentSessionResults.length,
      averageTime: totalTime / _currentSessionResults.length,
      commonErrors: commonErrors,
    );
  }

  Future<void> resetStats() async {
    await _prefs.remove(_statsKey);
    await _prefs.remove(_sessionKey);
    _currentSessionResults.clear();
    _sessionStartTime = null;
  }

  double calculateProgress() {
    final sessionStats = getCurrentSessionStats();
    if (sessionStats.totalAttempts == 0) return 0.0;

    const accuracyWeight = 0.4;
    const timeWeight = 0.3;
    const similarityWeight = 0.3;

    final accuracyScore = sessionStats.successfulAttempts /
        sessionStats.totalAttempts;
    final timeScore = sessionStats.averageTime < 10 ? 1.0 :
    10 / sessionStats.averageTime;
    final similarityScore = sessionStats.averageSimilarity;

    return (accuracyScore * accuracyWeight) +
        (timeScore * timeWeight) +
        (similarityScore * similarityWeight);
  }
}