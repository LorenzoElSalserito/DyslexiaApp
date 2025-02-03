// lib/services/game_service.dart

import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../models/level.dart';
import '../models/enums.dart';
import '../services/content_service.dart';
import '../services/exercise_manager.dart';
import '../models/recognition_result.dart';

/// GameService gestisce la logica principale del gioco, coordinando
/// l'interazione tra il Player, il sistema di livelli e gli esercizi.
/// Il progresso è basato unicamente sulle performance del giocatore.
class GameService extends ChangeNotifier {
  // Dipendenze fondamentali per il funzionamento del gioco
  final Player player;
  final ContentService contentService;
  final ExerciseManager exerciseManager;

  // Stato interno del gioco per tracciare le performance
  int _currentStreak = 0;
  int _totalAttempts = 0;
  int _successfulAttempts = 0;

  // Registro dell'accuratezza per il sistema di progressione
  // Mantiene traccia delle performance giornaliere per determinare l'avanzamento
  List<double> _accuracyHistory = [];

  // Costanti per il sistema di progressione
  static const int requiredDaysForLevelUp = 5;  // Giorni di pratica necessari per salire di livello
  static const double requiredAccuracy = 0.80;  // Accuratezza minima richiesta (80%)

  /// Costruttore che inizializza il servizio con le dipendenze necessarie
  GameService({
    required this.player,
    required this.contentService,
    required this.exerciseManager,
  });

  // Getters pubblici per accedere allo stato del gioco
  int get currentStreak => _currentStreak;
  double get levelProgress => _getLevelProgress();
  Difficulty get currentDifficulty => exerciseManager.currentDifficulty;
  bool get hasActiveStreak => _currentStreak >= 2;

  /// Calcola il progresso corrente del livello basato sull'accuratezza
  /// Restituisce un valore tra 0.0 e 1.0 che rappresenta il progresso
  double _getLevelProgress() {
    if (_accuracyHistory.isEmpty) return 0.0;

    if (_accuracyHistory.length >= requiredDaysForLevelUp) {
      // Considera solo gli ultimi giorni richiesti per il level up
      var recentAccuracy = _accuracyHistory.reversed.take(requiredDaysForLevelUp).toList();
      // Conta i giorni in cui l'accuratezza supera la soglia richiesta
      var daysAboveThreshold = recentAccuracy.where((acc) => acc >= requiredAccuracy).length;
      return daysAboveThreshold / requiredDaysForLevelUp;
    }

    // Se non ci sono ancora abbastanza giorni, il progresso è proporzionale
    return _accuracyHistory.length / requiredDaysForLevelUp;
  }

  /// Ottiene il target di esercizi per il livello corrente
  int getCurrentLevelTarget() {
    return Level.allLevels.firstWhere(
          (level) => level.number == player.currentLevel,
      orElse: () => Level.allLevels.first,
    ).targetWords;
  }

  /// Determina il sottolivello corrente basato sul progresso dell'utente
  SubLevel getCurrentSubLevel() {
    final level = Level.allLevels.firstWhere(
          (level) => level.number == player.currentLevel,
      orElse: () => Level.allLevels.first,
    );

    final progress = levelProgress;
    // Divisione in tre fasce di progresso per i sottolivelli
    if (progress < 0.33) {
      return level.subLevels[0];     // Livello base
    } else if (progress < 0.66) {
      return level.subLevels[1];     // Livello intermedio
    } else {
      return level.subLevels[2];     // Livello avanzato
    }
  }

  /// Verifica se il giocatore può avanzare di livello
  /// basato sulle performance degli ultimi giorni
  bool canAdvanceLevel() {
    if (_accuracyHistory.length < requiredDaysForLevelUp) return false;

    // Controlla che tutti gli ultimi giorni abbiano accuratezza sufficiente
    var recentAccuracy = _accuracyHistory.reversed.take(requiredDaysForLevelUp).toList();
    return recentAccuracy.every((accuracy) => accuracy >= requiredAccuracy);
  }

  /// Calcola la ricompensa in cristalli per un esercizio completato
  int calculateReward(RecognitionResult result) {
    // Ricompensa base in base al livello corrente
    final baseReward = switch (player.currentLevel) {
      1 => 10,  // Parole singole
      2 => 30,  // Frasi
      3 => 50,  // Paragrafi
      4 => 100, // Pagine
      _ => 10,  // Fallback sicuro
    };

    double multiplier = 1.0;

    // Bonus per difficoltà dell'esercizio
    switch (currentDifficulty) {
      case Difficulty.easy:
        multiplier *= 1.0;  // Nessun bonus
      case Difficulty.medium:
        multiplier *= 1.5;  // +50%
      case Difficulty.hard:
        multiplier *= 2.0;  // +100%
    }

    // Bonus per accuratezza nel completamento
    if (result.similarity >= 0.95) {
      multiplier *= 1.5;      // +50% per accuratezza eccellente
    } else if (result.similarity >= 0.90) {
      multiplier *= 1.3;      // +30% per accuratezza ottima
    } else if (result.similarity >= 0.85) {
      multiplier *= 1.1;      // +10% per accuratezza buona
    }

    // Bonus per streak di successi
    if (_currentStreak >= 3) {
      multiplier *= 1.5;  // +50% per streak di 3 o più successi
    }

    // Bonus per giorni consecutivi di pratica
    multiplier *= (1.0 + (player.currentConsecutiveDays * 0.1));  // +10% per ogni giorno

    // Bonus per New Game Plus
    multiplier *= (1.0 + (player.newGamePlusCount * 0.5));  // +50% per ogni NG+

    return (baseReward * multiplier).round();
  }

  /// Gestisce il completamento di un esercizio
  /// Aggiorna statistiche, calcola ricompense e verifica progressione
  Future<bool> completeExercise(RecognitionResult result) async {
    // Aggiorna contatori generali
    _totalAttempts++;
    if (result.isCorrect) {
      _successfulAttempts++;
      _currentStreak++;
    } else {
      _currentStreak = 0;  // Reset della streak in caso di errore
    }

    // Aggiorna accuratezza e verifica progresso
    _updateAccuracy(result.similarity);
    final canLevelUp = canAdvanceLevel();

    // Assegna ricompensa
    int reward = calculateReward(result);
    player.addCrystals(reward);

    // Incrementa passo del giocatore
    player.incrementStep();

    notifyListeners();
    return canLevelUp;
  }

  /// Aggiorna l'accuratezza per il giorno corrente
  void _updateAccuracy(double accuracy) {
    if (_accuracyHistory.isEmpty || _isNewDay()) {
      // Nuovo giorno, aggiungi nuova entry
      _accuracyHistory.add(accuracy);
    } else {
      // Aggiorna media del giorno corrente
      var currentDayAccuracy = _accuracyHistory.last;
      var totalExercises = _totalAttempts == 0 ? 1 : _totalAttempts;
      _accuracyHistory[_accuracyHistory.length - 1] =
          (currentDayAccuracy * (totalExercises - 1) + accuracy) / totalExercises;
    }

    // Mantieni solo gli ultimi 30 giorni di storia
    if (_accuracyHistory.length > 30) {
      _accuracyHistory.removeAt(0);
    }
  }

  /// Verifica se è iniziato un nuovo giorno
  bool _isNewDay() {
    if (_accuracyHistory.isEmpty) return true;

    final now = DateTime.now();
    final lastPlayDate = player.lastPlayDate;

    if (lastPlayDate == null) return true;

    return now.year != lastPlayDate.year ||
        now.month != lastPlayDate.month ||
        now.day != lastPlayDate.day;
  }

  /// Ottiene la media dell'accuratezza degli ultimi N giorni
  double getAverageAccuracy([int days = 5]) {
    if (_accuracyHistory.isEmpty) return 0.0;

    var recentAccuracy = _accuracyHistory.reversed.take(days).toList();
    if (recentAccuracy.isEmpty) return 0.0;

    return recentAccuracy.reduce((a, b) => a + b) / recentAccuracy.length;
  }

  /// Ottiene la percentuale di completamento per il prossimo livello
  double getLevelUpProgress() {
    if (_accuracyHistory.length < requiredDaysForLevelUp) {
      return _accuracyHistory.length / requiredDaysForLevelUp;
    }

    var recentAccuracy = _accuracyHistory.reversed.take(requiredDaysForLevelUp).toList();
    var daysAboveThreshold = recentAccuracy.where((acc) => acc >= requiredAccuracy).length;

    return daysAboveThreshold / requiredDaysForLevelUp;
  }

  /// Resetta il progresso corrente
  void reset() {
    _currentStreak = 0;
    _totalAttempts = 0;
    _successfulAttempts = 0;
    _accuracyHistory.clear();
    notifyListeners();
  }
}