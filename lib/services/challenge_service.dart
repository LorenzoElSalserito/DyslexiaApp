// lib/services/challenge_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/player.dart';
import '../models/enums.dart';
import '../models/challenge.dart';
import '../models/recognition_result.dart';

/// ChallengeService gestisce la creazione, il monitoraggio e il completamento
/// delle sfide giornaliere e settimanali del gioco.
class ChallengeService extends ChangeNotifier {
  // Dipendenze e stato
  final SharedPreferences _prefs;
  final Player _player;
  static const String _challengesKey = 'active_challenges';

  // Gestione delle sfide
  List<Challenge> _activeChallenges = [];
  DateTime? _lastDailyReset;
  DateTime? _lastWeeklyReset;

  // Costanti per le ricompense
  static const int _dailyChallengeBaseReward = 100;
  static const int _weeklyChallengeBaseReward = 500;
  static const double _streakMultiplier = 0.2; // +20% per sfida consecutiva

  ChallengeService(this._prefs, this._player) {
    _initializeChallenges();
  }

  /// Inizializza il servizio caricando le sfide salvate e verificando i reset
  void _initializeChallenges() {
    _loadChallenges();
    _checkAndResetChallenges();
    _generateNewChallengesIfNeeded();
  }

  /// Carica le sfide salvate dalle SharedPreferences
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

  /// Ottiene il template di una sfida dal suo ID
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
          crystalReward: _calculateDailyReward() * 2, // Doppia ricompensa
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

  /// Verifica e resetta le sfide scadute
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

  /// Verifica se due date sono nello stesso giorno
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Verifica se due date sono nella stessa settimana
  bool _isSameWeek(DateTime date1, DateTime date2) {
    final monday1 = date1.subtract(Duration(days: date1.weekday - 1));
    final monday2 = date2.subtract(Duration(days: date2.weekday - 1));
    return _isSameDay(monday1, monday2);
  }

  /// Resetta le sfide giornaliere
  void _resetDailyChallenges() {
    _activeChallenges.removeWhere((challenge) =>
    challenge.type == ChallengeType.daily
    );
    _generateDailyChallenges();
  }

  /// Resetta le sfide settimanali
  void _resetWeeklyChallenges() {
    _activeChallenges.removeWhere((challenge) =>
    challenge.type == ChallengeType.weekly
    );
    _generateWeeklyChallenges();
  }

  /// Genera le sfide giornaliere
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

  /// Genera le sfide settimanali
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

  /// Calcola la ricompensa per una sfida giornaliera
  int _calculateDailyReward() {
    // Bonus basato sui giorni consecutivi
    final streakBonus = _player.currentConsecutiveDays * _streakMultiplier;
    // Bonus basato sul livello
    final levelBonus = (_player.currentLevel - 1) * 0.5;
    // Bonus New Game+
    final ngPlusBonus = _player.newGamePlusCount * 1.0;

    return (_dailyChallengeBaseReward *
        (1 + streakBonus + levelBonus + ngPlusBonus)).round();
  }

  /// Calcola la ricompensa per una sfida settimanale
  int _calculateWeeklyReward() {
    // Bonus basato sul livello
    final levelBonus = (_player.currentLevel - 1) * 0.5;
    // Bonus New Game+
    final ngPlusBonus = _player.newGamePlusCount * 1.0;

    return (_weeklyChallengeBaseReward *
        (1 + levelBonus + ngPlusBonus)).round();
  }

  /// Genera nuove sfide se necessario
  void _generateNewChallengesIfNeeded() {
    if (_activeChallenges.isEmpty) {
      _generateDailyChallenges();
      _generateWeeklyChallenges();
    }
  }

  /// Aggiorna il progresso di una sfida
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

  /// Trova una sfida dal suo ID
  Challenge? _findChallenge(String id) {
    try {
      return _activeChallenges.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Salva lo stato delle sfide
  Future<void> _saveChallenges() async {
    final challengesData = _activeChallenges.map((c) => c.toJson()).toList();
    await _prefs.setString(_challengesKey, json.encode(challengesData));
  }

  /// Processa il risultato di un esercizio aggiornando le sfide pertinenti
  void processExerciseResult(RecognitionResult result) {
    // Aggiorna le sfide di accuratezza
    if (result.similarity >= 0.9) {
      final accuracyChallenge = _findChallenge('daily_accuracy');
      if (accuracyChallenge != null) {
        updateChallengeProgress(
            accuracyChallenge.id,
            accuracyChallenge.currentProgress + 1
        );
      }
    }

    // Aggiorna le sfide perfette
    if (result.similarity >= 0.95) {
      final perfectChallenge = _findChallenge('daily_perfect');
      if (perfectChallenge != null) {
        updateChallengeProgress(
            perfectChallenge.id,
            perfectChallenge.currentProgress + 1
        );
      }
    }

    // Aggiorna le sfide settimanali
    final weeklyChallenge = _findChallenge('weekly_exercises');
    if (weeklyChallenge != null) {
      updateChallengeProgress(
          weeklyChallenge.id,
          weeklyChallenge.currentProgress + 1
      );
    }
  }

  // Getters pubblici
  List<Challenge> get activeChallenges => List.unmodifiable(_activeChallenges);
  List<Challenge> get dailyChallenges => _activeChallenges
      .where((c) => c.type == ChallengeType.daily)
      .toList();
  List<Challenge> get weeklyChallenges => _activeChallenges
      .where((c) => c.type == ChallengeType.weekly)
      .toList();
  List<Challenge> get completedChallenges => _activeChallenges
      .where((c) => c.status == ChallengeStatus.completed)
      .toList();
}