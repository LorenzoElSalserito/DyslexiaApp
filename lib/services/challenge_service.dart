// lib/services/challenge_service.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences.dart';
import '../models/player.dart';

enum ChallengeType {
  daily,
  weekly,
  special
}

enum ChallengeStatus {
  notStarted,
  inProgress,
  completed,
  failed
}

class Challenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int targetValue;
  final int crystalReward;
  final DateTime expiration;
  ChallengeStatus status;
  int currentProgress;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.crystalReward,
    required this.expiration,
    this.status = ChallengeStatus.notStarted,
    this.currentProgress = 0,
  });

  double get progressPercentage => currentProgress / targetValue;

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.index,
    'currentProgress': currentProgress,
  };

  factory Challenge.fromJson(Map<String, dynamic> json, Challenge template) {
    return Challenge(
      id: template.id,
      title: template.title,
      description: template.description,
      type: template.type,
      targetValue: template.targetValue,
      crystalReward: template.crystalReward,
      expiration: template.expiration,
      status: ChallengeStatus.values[json['status'] as int],
      currentProgress: json['currentProgress'] as int,
    );
  }
}

class ChallengeService extends ChangeNotifier {
  final SharedPreferences _prefs;
  final Player _player;
  static const String _challengesKey = 'active_challenges';

  List<Challenge> _activeChallenges = [];
  DateTime? _lastDailyReset;
  DateTime? _lastWeeklyReset;

  ChallengeService(this._prefs, this._player) {
    _initializeChallenges();
  }

  List<Challenge> get activeChallenges => _activeChallenges;

  void _initializeChallenges() {
    _loadChallenges();
    _checkAndResetChallenges();
    _generateNewChallengesIfNeeded();
  }

  Future<void> _loadChallenges() async {
    final savedChallenges = _prefs.getString(_challengesKey);
    if (savedChallenges != null) {
      // Implementa il caricamento delle sfide salvate
    }
  }

  void _checkAndResetChallenges() {
    final now = DateTime.now();

    // Controllo reset giornaliero
    if (_lastDailyReset == null || !_isSameDay(_lastDailyReset!, now)) {
      _resetDailyChallenges();
      _lastDailyReset = now;
    }

    // Controllo reset settimanale
    if (_lastWeeklyReset == null || !_isSameWeek(_lastWeeklyReset!, now)) {
      _resetWeeklyChallenges();
      _lastWeeklyReset = now;
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isSameWeek(DateTime date1, DateTime date2) {
    // Considera la settimana da lunedì a domenica
    final monday1 = date1.subtract(Duration(days: date1.weekday - 1));
    final monday2 = date2.subtract(Duration(days: date2.weekday - 1));
    return _isSameDay(monday1, monday2);
  }

  void _resetDailyChallenges() {
    _activeChallenges.removeWhere((challenge) =>
    challenge.type == ChallengeType.daily);
    _generateDailyChallenges();
  }

  void _resetWeeklyChallenges() {
    _activeChallenges.removeWhere((challenge) =>
    challenge.type == ChallengeType.weekly);
    _generateWeeklyChallenges();
  }

  void _generateDailyChallenges() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final dailyChallenges = [
      Challenge(
        id: 'daily_streak',
        title: 'Streak Maestro',
        description: 'Mantieni una streak di 5 esercizi',
        type: ChallengeType.daily,
        targetValue: 5,
        crystalReward: 100,
        expiration: tomorrow,
      ),
      Challenge(
        id: 'daily_accuracy',
        title: 'Precisione Perfetta',
        description: 'Completa 3 esercizi con accuratezza superiore al 90%',
        type: ChallengeType.daily,
        targetValue: 3,
        crystalReward: 150,
        expiration: tomorrow,
      ),
    ];

    _activeChallenges.addAll(dailyChallenges);
    _saveChallenges();
    notifyListeners();
  }

  void _generateWeeklyChallenges() {
    final now = DateTime.now();
    final nextWeek = now.add(Duration(days: 7));

    final weeklyChallenges = [
      Challenge(
        id: 'weekly_exercises',
        title: 'Allenamento Costante',
        description: 'Completa 20 esercizi questa settimana',
        type: ChallengeType.weekly,
        targetValue: 20,
        crystalReward: 500,
        expiration: nextWeek,
      ),
      Challenge(
        id: 'weekly_perfect',
        title: 'Perfezione Settimanale',
        description: 'Ottieni 5 risultati perfetti',
        type: ChallengeType.weekly,
        targetValue: 5,
        crystalReward: 750,
        expiration: nextWeek,
      ),
    ];

    _activeChallenges.addAll(weeklyChallenges);
    _saveChallenges();
    notifyListeners();
  }

  void _generateNewChallengesIfNeeded() {
    if (_activeChallenges.isEmpty) {
      _generateDailyChallenges();
      _generateWeeklyChallenges();
    }
  }

  void updateChallengeProgress(String challengeId, int progress) {
    final challenge = _activeChallenges.firstWhere(
          (c) => c.id == challengeId,
      orElse: () => throw Exception('Challenge not found: $challengeId'),
    );

    challenge.currentProgress = progress;
    if (challenge.currentProgress >= challenge.targetValue) {
      challenge.status = ChallengeStatus.completed;
      _player.addCrystals(challenge.crystalReward);
    }

    _saveChallenges();
    notifyListeners();
  }

  Future<void> _saveChallenges() async {
    final challengesData = _activeChallenges.map((c) => c.toJson()).toList();
    await _prefs.setString(_challengesKey, challengesData.toString());
  }

  void processExerciseResult(RecognitionResult result) {
    // Aggiorna le sfide relative all'accuratezza
    if (result.similarity >= 0.9) {
      final accuracyChallenge = _activeChallenges.firstWhere(
            (c) => c.id == 'daily_accuracy',
        orElse: () => throw Exception('Challenge not found: daily_accuracy'),
      );
      updateChallengeProgress(accuracyChallenge.id, accuracyChallenge.cu