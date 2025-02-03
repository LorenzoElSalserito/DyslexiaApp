// lib/services/exercise_manager.dart

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import '../models/player.dart';
import '../models/recognition_result.dart';
import '../services/content_service.dart';
import '../services/learning_analytics_service.dart';
import '../models/enums.dart';

/// Rappresenta un singolo esercizio con tutte le sue proprietà
class Exercise {
  final String content;
  final ExerciseType type;
  final Difficulty difficulty;
  final int crystalValue;
  final bool isBonus;
  final Map<String, dynamic>? metadata;

  Exercise({
    required this.content,
    required this.type,
    required this.difficulty,
    required this.crystalValue,
    this.isBonus = false,
    this.metadata,
  });
}

/// Gestisce la creazione e la gestione degli esercizi, tracciando progressi e difficoltà
class ExerciseManager extends ChangeNotifier {
  // Servizi e stato necessari per la gestione degli esercizi
  final Player _player;
  final ContentService _contentService;
  final LearningAnalyticsService _analyticsService;
  final Random _random = Random();

  // Stato corrente dell'esercizio e progressione
  Exercise? _currentExercise;
  List<String> _usedContent = [];
  int _consecutiveSuccesses = 0;
  int _consecutiveFailures = 0;
  Difficulty _currentDifficulty = Difficulty.medium;

  // Costanti per la gestione della difficoltà
  static const int maxConsecutiveAttempts = 3;
  static const double difficultyThreshold = 0.85;

  /// Costruttore che richiede tutti i servizi necessari
  ExerciseManager({
    required Player player,
    required ContentService contentService,
    required LearningAnalyticsService analyticsService,
  }) : _player = player,
        _contentService = contentService,
        _analyticsService = analyticsService;

  // Getters pubblici per accedere allo stato
  Exercise? get currentExercise => _currentExercise;
  Difficulty get currentDifficulty => _currentDifficulty;

  /// Genera il contenuto grezzo per un nuovo esercizio
  Future<String> _generateRawContent(ExerciseType type) async {
    return _contentService.getRandomWordForLevel(
      _player.currentLevel,
      _currentDifficulty,
    ).text;
  }

  /// Genera un nuovo esercizio completo
  Future<Exercise> generateExercise() async {
    ExerciseType type = _getExerciseTypeForLevel(_player.currentLevel);
    String content = await _generateRawContent(type);
    int baseValue = _calculateBaseValue(content, type);

    _currentExercise = Exercise(
      content: content,
      type: type,
      difficulty: _currentDifficulty,
      crystalValue: _calculateCrystalValue(baseValue),
      isBonus: _consecutiveSuccesses >= 3,
      metadata: {
        'difficulty': _currentDifficulty,
        'attemptNumber': _consecutiveSuccesses + _consecutiveFailures + 1,
      },
    );

    notifyListeners();
    return _currentExercise!;
  }

  /// Determina il tipo di esercizio appropriato per il livello corrente
  ExerciseType _getExerciseTypeForLevel(int level) {
    switch (level) {
      case 1:
        return ExerciseType.word;     // Livello base: singole parole
      case 2:
        return ExerciseType.sentence; // Livello intermedio: frasi complete
      case 3:
        return ExerciseType.paragraph; // Livello avanzato: paragrafi
      case 4:
        return ExerciseType.page;     // Livello master: pagine intere
      default:
        return ExerciseType.word;     // Fallback sicuro al livello base
    }
  }

  /// Calcola il valore base di un esercizio
  int _calculateBaseValue(String content, ExerciseType type) {
    double multiplier = switch (type) {
      ExerciseType.word => 1.0,       // Ricompensa base per le parole
      ExerciseType.sentence => 2.0,   // Doppia ricompensa per le frasi
      ExerciseType.paragraph => 3.0,  // Tripla ricompensa per i paragrafi
      ExerciseType.page => 4.0,       // Quadrupla ricompensa per le pagine
    };

    return (content.length * multiplier).round();
  }

  /// Calcola il valore finale in cristalli considerando tutti i bonus
  int _calculateCrystalValue(int baseValue) {
    double multiplier = 1.0;

    // Applica il modificatore di difficoltà
    switch (_currentDifficulty) {
      case Difficulty.easy:
        multiplier *= 1.0;  // Nessun bonus per difficoltà facile
      case Difficulty.medium:
        multiplier *= 1.5;  // +50% per difficoltà media
      case Difficulty.hard:
        multiplier *= 2.0;  // +100% per difficoltà difficile
    }

    // Bonus per New Game+
    multiplier *= (1.0 + (_player.newGamePlusCount * 0.5));

    // Bonus per streak di successi
    if (_consecutiveSuccesses >= 3) {
      multiplier *= 1.5;  // +50% per streak di 3 o più successi
    }

    return (baseValue * multiplier).round();
  }

  /// Processa il risultato di un esercizio
  Future<void> processExerciseResult(RecognitionResult result) async {
    if (result.isCorrect) {
      _handleSuccess();
    } else {
      _handleFailure();
    }

    _updateDifficulty(result.similarity);
    _analyticsService.addResult(result);
    notifyListeners();
  }

  /// Gestisce un esercizio completato con successo
  void _handleSuccess() {
    _consecutiveSuccesses++;
    _consecutiveFailures = 0;
  }

  /// Gestisce un esercizio fallito
  void _handleFailure() {
    _consecutiveFailures++;
    _consecutiveSuccesses = 0;
  }

  /// Aggiorna la difficoltà in base alle performance
  void _updateDifficulty(double performance) {
    if (_consecutiveSuccesses >= maxConsecutiveAttempts &&
        performance >= difficultyThreshold) {
      _increaseDifficulty();
    } else if (_consecutiveFailures >= maxConsecutiveAttempts) {
      _decreaseDifficulty();
    }
  }

  /// Aumenta la difficoltà quando le performance sono costantemente buone
  void _increaseDifficulty() {
    switch (_currentDifficulty) {
      case Difficulty.easy:
        _currentDifficulty = Difficulty.medium;
      case Difficulty.medium:
        _currentDifficulty = Difficulty.hard;
      case Difficulty.hard:
        break;  // Già al massimo livello di difficoltà
    }
    notifyListeners();
  }

  /// Diminuisce la difficoltà quando l'utente ha difficoltà costanti
  void _decreaseDifficulty() {
    switch (_currentDifficulty) {
      case Difficulty.hard:
        _currentDifficulty = Difficulty.medium;
      case Difficulty.medium:
        _currentDifficulty = Difficulty.easy;
      case Difficulty.easy:
        break;  // Già al minimo livello di difficoltà
    }
    notifyListeners();
  }

  /// Resetta il progresso corrente
  void resetProgress() {
    _usedContent.clear();
    _consecutiveSuccesses = 0;
    _consecutiveFailures = 0;
    _currentDifficulty = Difficulty.easy;
    notifyListeners();
  }
}