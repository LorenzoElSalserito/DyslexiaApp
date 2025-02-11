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

  static const int _dailyChallengeBaseReward = 100;
  static const int _weeklyChallengeBaseReward = 500;
  static const double _streakMultiplier = 0.2;

  ChallengeService(this._prefs, this._player) {
    _initializeChallenges();
  }

  void _initializeChallenges() {
    _loadChallenges();
    _checkAndResetChallenges();
    _generateNewChallengesIfNeeded();
  }

  void _loadChallenges() {
    try {
      final savedChallenges = _prefs.getString(_challengesKey);
      if (savedChallenges != null) {
        final List<dynamic> challengesList = json.decode(savedChallenges);
        _activeChallenges = challengesList.map((data) {
          final template = _getChallengeTemplate(data['id']);
          if (template != null) {
            return Challenge.fromJson(data as Map<String, dynamic>, template);
          }
          return null;
        }).whereType<Challenge>().toList();
      }
    } catch (e) {
      print('Errore nel caricamento delle sfide: $e');
    }
  }

  Challenge? _getChallengeTemplate(String id) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final nextWeek = now.add(const Duration(days: 7));

    switch (id) {
      case 'daily_streak':
        return Challenge(
          id: id,
          title: 'Streak Maestro',
          description: 'Mantieni una streak di 5 esercizi',
          type: ChallengeType.daily,
          targetValue: 5,
          crystalReward: _calculateDailyReward(),
          expiration: tomorrow,
        );
      case 'daily_accuracy':
        return Challenge(
          id: id,
          title: 'Precisione Perfetta',
          description: 'Completa 3 esercizi con accuratezza superiore al 90%',
          type: ChallengeType.daily,
          targetValue: 3,
          crystalReward: _calculateDailyReward(),
          expiration: tomorrow,
        );
      case 'weekly_exercises':
        return Challenge(
          id: id,
          title: 'Allenamento Costante',
          description: 'Completa 20 esercizi questa settimana',
          type: ChallengeType.weekly,
          targetValue: 20,
          crystalReward: _calculateWeeklyReward(),
          expiration: nextWeek,
        );
      case 'daily_perfect':
        return Challenge(
          id: id,
          title: 'Perfezione',
          description: 'Ottieni 100% di accuratezza in 3 esercizi',
          type: ChallengeType.daily,
          targetValue: 3,
          crystalReward: _calculateDailyReward() * 2,
          expiration: tomorrow,
        );
      case 'weekly_streak':
        return Challenge(
          id: id,
          title: 'Super Streak Settimanale',
          description: 'Raggiungi una streak di 15 esercizi',
          type: ChallengeType.weekly,
          targetValue: 15,
          crystalReward: _calculateWeeklyReward(),
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
        description: 'Mantieni una streak di 5 serie di Esercizi da 5',
        type: ChallengeType.daily,
        targetValue: 5,
        crystalReward: _calculateDailyReward(),
        expiration: tomorrow,
      ),
      Challenge(
        id: 'daily_accuracy',
        title: 'Precisione Perfetta',
        description: 'Completa 3 esercizi con accuratezza superiore al 90%',
        type: ChallengeType.daily,
        targetValue: 3,
        crystalReward: _calculateDailyReward(),
        expiration: tomorrow,
      ),
    ];
    _activeChallenges.addAll(dailyChallenges);
    _saveChallenges();
    notifyListeners();
  }

  void _generateWeeklyChallenges() {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    final weeklyChallenges = [
      Challenge(
        id: 'weekly_exercises',
        title: 'Allenamento Costante',
        description: 'Completa 20 esercizi questa settimana',
        type: ChallengeType.weekly,
        targetValue: 20,
        crystalReward: _calculateWeeklyReward(),
        expiration: nextWeek,
      ),
      Challenge(
        id: 'weekly_streak',
        title: 'Super Streak Settimanale',
        description: 'Raggiungi una streak di 15 esercizi',
        type: ChallengeType.weekly,
        targetValue: 15,
        crystalReward: _calculateWeeklyReward(),
        expiration: nextWeek,
      ),
    ];
    _activeChallenges.addAll(weeklyChallenges);
    _saveChallenges();
    notifyListeners();
  }

  int _calculateDailyReward() {
    final streakBonus = _player.currentConsecutiveDays * _streakMultiplier;
    final levelBonus = (_player.currentLevel - 1) * 0.5;
    final ngPlusBonus = _player.newGamePlusCount * 1.0;
    return (_dailyChallengeBaseReward * (1 + streakBonus + levelBonus + ngPlusBonus)).round();
  }

  int _calculateWeeklyReward() {
    final levelBonus = (_player.currentLevel - 1) * 0.5;
    final ngPlusBonus = _player.newGamePlusCount * 1.0;
    return (_weeklyChallengeBaseReward * (1 + levelBonus + ngPlusBonus)).round();
  }

  void _generateNewChallengesIfNeeded() {
    if (_activeChallenges.isEmpty) {
      _generateDailyChallenges();
      _generateWeeklyChallenges();
    }
  }

  void updateChallengeProgress(String challengeId, int progress) {
    final challenge = _findChallenge(challengeId);
    if (challenge == null) return;
    challenge.currentProgress = progress;
    if (challenge.currentProgress >= challenge.targetValue &&
        challenge.status != ChallengeStatus.completed) {
      challenge.status = ChallengeStatus.completed;
      _player.addCrystals(challenge.crystalReward);
    }
    _saveChallenges();
    notifyListeners();
  }

  Challenge? _findChallenge(String id) {
    try {
      return _activeChallenges.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveChallenges() async {
    final challengesData = _activeChallenges.map((c) => c.toJson()).toList();
    await _prefs.setString(_challengesKey, json.encode(challengesData));
  }

  void processExerciseResult(RecognitionResult result) {
    if (result.similarity >= 0.9) {
      final accuracyChallenge = _findChallenge('daily_accuracy');
      if (accuracyChallenge != null) {
        updateChallengeProgress(accuracyChallenge.id, accuracyChallenge.currentProgress + 1);
      }
    }
    if (result.similarity >= 0.95) {
      final perfectChallenge = _findChallenge('daily_perfect');
      if (perfectChallenge != null) {
        updateChallengeProgress(perfectChallenge.id, perfectChallenge.currentProgress + 1);
      }
    }
    final weeklyChallenge = _findChallenge('weekly_exercises');
    if (weeklyChallenge != null) {
      updateChallengeProgress(weeklyChallenge.id, weeklyChallenge.currentProgress + 1);
    }
  }

  List<Challenge> get activeChallenges => List.unmodifiable(_activeChallenges);
  List<Challenge> get dailyChallenges => _activeChallenges.where((c) => c.type == ChallengeType.daily).toList();
  List<Challenge> get weeklyChallenges => _activeChallenges.where((c) => c.type == ChallengeType.weekly).toList();
  List<Challenge> get completedChallenges => _activeChallenges.where((c) => c.status == ChallengeStatus.completed).toList();
}
