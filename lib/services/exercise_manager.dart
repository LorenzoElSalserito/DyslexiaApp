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
  final String content;          // Il testo da leggere
  final ExerciseType type;       // Tipo di esercizio (parola, frase, ecc.)
  final Difficulty difficulty;   // Livello di difficoltà
  final int crystalValue;        // Valore base in cristalli
  final bool isBonus;           // Se l'esercizio è bonus
  final Map<String, dynamic>? metadata; // Metadati aggiuntivi

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
  // Servizi e stato necessari
  final Player _player;
  final ContentService _contentService;
  final LearningAnalyticsService _analyticsService;
  final Random _random = Random();

  // Stato della sessione corrente
  Exercise? _currentExercise;
  List<String> _usedContent = [];
  List<RecognitionResult> _sessionResults = [];
  int _currentSessionIndex = 0;
  Difficulty _currentDifficulty = Difficulty.easy;

  // Costanti per la gestione della sessione
  static const int exercisesPerSession = 5;
  static const double difficultyThreshold = 0.85;

  /// Costruttore che richiede tutti i servizi necessari
  ExerciseManager({
    required Player player,
    required ContentService contentService,
    required LearningAnalyticsService analyticsService,
  }) : _player = player,
        _contentService = contentService,
        _analyticsService = analyticsService;

  /// Genera un nuovo esercizio appropriato per il livello corrente
  Future<Exercise> generateExercise() async {
    // Determina il tipo di contenuto in base al livello
    ExerciseType type = _getExerciseTypeForLevel(_player.currentLevel);

    // Ottiene il contenuto appropriato
    String content = await _generateContent(type);

    // Calcola il valore base in cristalli
    int syllables = _countSyllables(content);
    int baseValue = syllables * 5; // 5 cristalli per sillaba

    _currentExercise = Exercise(
      content: content,
      type: type,
      difficulty: _currentDifficulty,
      crystalValue: baseValue,
      isBonus: _sessionResults.length >= 3 &&
          _sessionResults.every((r) => r.isCorrect),
      metadata: {
        'sessionIndex': _currentSessionIndex,
        'difficulty': _currentDifficulty,
      },
    );

    notifyListeners();
    return _currentExercise!;
  }

  /// Genera il contenuto appropriato per il tipo di esercizio
  Future<String> _generateContent(ExerciseType type) async {
    String content;
    do {
      content = _contentService.getRandomWordForLevel(
        _player.currentLevel,
        _currentDifficulty,
      ).text;
    } while (_usedContent.contains(content));

    _usedContent.add(content);
    return content;
  }

  /// Determina il tipo di esercizio appropriato per il livello
  ExerciseType _getExerciseTypeForLevel(int level) {
    switch (level) {
      case 1:
        return ExerciseType.word;
      case 2:
        return ExerciseType.sentence;
      case 3:
        return ExerciseType.paragraph;
      case 4:
        return ExerciseType.page;
      default:
        return ExerciseType.word;
    }
  }

  /// Conta le sillabe in una parola italiana
  int _countSyllables(String word) {
    final vowels = RegExp('[aeiouAEIOU]');
    final diphthongs = RegExp('(ai|au|ei|eu|oi|ou|ia|ie|io|iu|ua|ue|ui|uo)');

    int count = vowels.allMatches(word).length;
    count -= diphthongs.allMatches(word).length;
    return count > 0 ? count : 1;
  }

  /// Processa il risultato di un esercizio e restituisce i cristalli guadagnati
  Future<int> processExerciseResult(RecognitionResult result) async {
    if (_currentExercise == null) return 0;

    // Calcola i cristalli prima di aggiungere il risultato
    int crystals = _calculateFinalCrystals(result);

    // Aggiunge il risultato alla sessione corrente
    _sessionResults.add(result);
    _currentSessionIndex++;

    // Aggiunge i cristalli guadagnati al giocatore
    _player.addCrystals(crystals);

    // Aggiorna statistiche
    _analyticsService.addResult(result);

    // Aggiorna la difficoltà se necessario
    _updateDifficulty();

    notifyListeners();
    return crystals;
  }

  /// Calcola i cristalli finali considerando bonus e moltiplicatori
  int _calculateFinalCrystals(RecognitionResult result) {
    if (_currentExercise == null) return 0;

    double multiplier = 1.0;

    // Bonus per alta accuratezza
    if (result.similarity >= 0.95) multiplier += 0.5;
    else if (result.similarity >= 0.90) multiplier += 0.3;
    else if (result.similarity >= 0.85) multiplier += 0.1;

    // Bonus per streak nella sessione
    if (_sessionResults.length >= 3 &&
        _sessionResults.every((r) => r.isCorrect)) {
      multiplier += 0.5;
    }

    // Bonus per difficoltà
    switch (_currentDifficulty) {
      case Difficulty.easy:
        multiplier *= 1.0;
        break;
      case Difficulty.medium:
        multiplier *= 1.5;
        break;
      case Difficulty.hard:
        multiplier *= 2.0;
        break;
    }

    // Bonus New Game+
    multiplier *= (1.0 + (_player.newGamePlusCount * 0.5));

    return (_currentExercise!.crystalValue * multiplier).round();
  }

  /// Aggiorna la difficoltà in base alle performance
  void _updateDifficulty() {
    if (_sessionResults.length < 3) return;

    // Calcola l'accuratezza media degli ultimi 3 risultati
    final recentResults = _sessionResults.reversed.take(3).toList();
    final averageAccuracy = recentResults
        .map((r) => r.similarity)
        .reduce((a, b) => a + b) / recentResults.length;

    // Aggiusta la difficoltà
    if (averageAccuracy >= 0.95 && _currentDifficulty != Difficulty.hard) {
      _currentDifficulty = Difficulty.hard;
    } else if (averageAccuracy >= 0.85 && _currentDifficulty == Difficulty.easy) {
      _currentDifficulty = Difficulty.medium;
    } else if (averageAccuracy < 0.75 && _currentDifficulty != Difficulty.easy) {
      _currentDifficulty = Difficulty.easy;
    }
  }

  /// Resetta la sessione corrente
  void _resetSession() {
    _currentSessionIndex = 0;
    _sessionResults.clear();
    _usedContent.clear();

    // Reset della difficoltà se le performance sono state scarse
    if (_sessionResults.where((r) => !r.isCorrect).length >
        exercisesPerSession / 2) {
      _currentDifficulty = Difficulty.easy;
    }
  }

  /// Forza il reset manuale della sessione
  void forceSessionReset() {
    _resetSession();
    notifyListeners();
  }

  /// Ottiene le statistiche della sessione corrente
  Map<String, dynamic> getSessionStats() {
    if (_sessionResults.isEmpty) {
      return {
        'totalExercises': exercisesPerSession,
        'completedExercises': 0,
        'averageAccuracy': 0.0,
        'successfulExercises': 0,
        'totalCrystals': 0,
      };
    }

    final successfulExercises = _sessionResults
        .where((r) => r.isCorrect)
        .length;

    final averageAccuracy = _sessionResults
        .map((r) => r.similarity)
        .reduce((a, b) => a + b) / _sessionResults.length;

    return {
      'totalExercises': exercisesPerSession,
      'completedExercises': _currentSessionIndex,
      'averageAccuracy': averageAccuracy,
      'successfulExercises': successfulExercises,
      'totalCrystals': _player.totalCrystals,
    };
  }

  // Getters pubblici
  Exercise? get currentExercise => _currentExercise;
  Difficulty get currentDifficulty => _currentDifficulty;
  int get sessionProgress => _currentSessionIndex;
  bool get isSessionComplete => _currentSessionIndex >= exercisesPerSession;
  List<RecognitionResult> get sessionResults => List.unmodifiable(_sessionResults);
}