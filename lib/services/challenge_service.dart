// lib/services/challenge_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/player.dart';
import '../models/enums.dart';
import '../models/challenge.dart';
import '../models/recognition_result.dart';

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

  List<Challenge> get activeChallenges => List.unmodifiable(_activeChallenges);

  void _initializeChallenges() {
    _loadChallenges();
    _checkAndResetChallenges();
    _generateNewChallengesIfNeeded();
  }

  void _loadChallenges() {
    final savedChallenges = _prefs.getString(_challengesKey);
    if (savedChallenges != null) {
      try {
        final List<dynamic> challengesList = json.decode(savedChallenges);
        _activeChallenges = challengesList.map((data) {
          final template = _getChallengeTemplate(data['id']);
          if (template != null) {
            return Challenge.fromJson(data as Map<String, dynamic>, template);
          }
          return null;
        }).whereType<Challenge>().toList();
      } catch (e) {
        print('Errore nel caricamento delle sfide: $e');
      }
    }
  }

  Challenge? _getChallengeTemplate(String id) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final nextWeek = now.add(Duration(days: 7));

    switch (id) {
      case 'daily_streak':
        return Challenge(
          id: id,
          title: 'Streak Maestro',
          description: 'Mantieni una streak di 5 esercizi',
          type: ChallengeType.daily,
          targetValue: 5,
          crystalReward: 100,
          expiration: tomorrow,
        );
      case 'daily_accuracy':
        return Challenge(
          id: id,
          title: 'Precisione Perfetta',
          description: 'Completa 3 esercizi con accuratezza superiore al 90%',
          type: ChallengeType.daily,
          targetValue: 3,
          crystalReward: 150,
          expiration: tomorrow,
        );
      case 'weekly_exercises':
        return Challenge(
          id: id,
          title: 'Allenamento Costante',
          description: 'Completa 20 esercizi questa settimana',
          type: ChallengeType.weekly,
          targetValue: 20,
          crystalReward: 500,
          expiration: nextWeek,
        );
      default:
        return null;
    }
  }

  void _checkAndResetChallenges() {
    final now = DateTime.now();

    if (_lastDailyReset == null || !_isSameDay(_lastDailyReset!, now)) {
      _resetDailyChallenges();
      _lastDailyReset = now;
    }

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
    final monday1 = date1.subtract(Duration(days: date1.weekday - 1));
    final monday2 = date2.subtract(Duration(days: date2.weekday - 1));
    return _isSameDay(monday1, monday2);
  }

  void _resetDailyChallenges() {
    _activeChallenges.removeWhere((challenge) => challenge.type == ChallengeType.daily);
    _generateDailyChallenges();
  }

  void _resetWeeklyChallenges() {
    _activeChallenges.removeWhere((challenge) => challenge.type == ChallengeType.weekly);
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
    await _prefs.setString(_challengesKey, json.encode(challengesData));
  }

  void processExerciseResult(RecognitionResult result) {
    if (result.similarity >= 0.9) {
      final accuracyChallenge = _activeChallenges.firstWhere(
            (c) => c.id == 'daily_accuracy',
        orElse: () => throw Exception('Challenge not found: daily_accuracy'),
      );
      updateChallengeProgress(
          accuracyChallenge.id, accuracyChallenge.currentProgress + 1);
    }
  }
}