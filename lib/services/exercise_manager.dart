import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import '../models/player.dart';
import '../models/recognition_result.dart';
import '../services/content_service.dart';
import '../services/learning_analytics_service.dart';
import '../models/enums.dart';

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

class ExerciseManager extends ChangeNotifier {
  final Player _player;
  final ContentService _contentService;
  final LearningAnalyticsService _analyticsService;
  final Random _random = Random();

  Exercise? _currentExercise;
  List<String> _usedContent = [];
  int _consecutiveSuccesses = 0;
  int _consecutiveFailures = 0;
  Difficulty _currentDifficulty = Difficulty.medium;

  static const int maxConsecutiveAttempts = 3;
  static const double difficultyThreshold = 0.85;

  ExerciseManager({
    required Player player,
    required ContentService contentService,
    required LearningAnalyticsService analyticsService,
  }) : _player = player,
        _contentService = contentService,
        _analyticsService = analyticsService;

  Exercise? get currentExercise => _currentExercise;
  Difficulty get currentDifficulty => _currentDifficulty;

  Future<Exercise> generateExercise() async {
    ExerciseType type = _getExerciseTypeForLevel(_player.currentLevel);
    String content = await _generateContent(type);
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

  Future<String> _generateContent(ExerciseType type) async {
    String content;
    int attempts = 0;
    const maxAttempts = 10;

    do {
      content = await _generateRawContent(type);
      attempts++;
    } while (_usedContent.contains(content) && attempts < maxAttempts);

    if (attempts >= maxAttempts) {
      _usedContent.clear(); // Reset if we can't find unused content
    }

    _usedContent.add(content);
    return content;
  }

  Future<String> _generateRawContent(ExerciseType type) async {
    final word = _contentService.getRandomWordForLevel(
      _player.currentLevel,
      _currentDifficulty,
    );
    return word.text;
  }

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

  int _calculateBaseValue(String content, ExerciseType type) {
    double multiplier = switch (type) {
      ExerciseType.word => 1.0,
      ExerciseType.sentence => 2.0,
      ExerciseType.paragraph => 3.0,
      ExerciseType.page => 4.0,
    };

    return (content.length * multiplier).round();
  }

  int _calculateCrystalValue(int baseValue) {
    double multiplier = 1.0;

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

    // Bonus per New Game+
    multiplier *= (1.0 + (_player.newGamePlusCount * 0.5));

    // Bonus per streak
    if (_consecutiveSuccesses >= 3) {
      multiplier *= 1.5;
    }

    return (baseValue * multiplier).round();
  }

  Future<void> processExerciseResult(RecognitionResult result) async {
    if (result.isCorrect) {
      _handleSuccess();
    } else {
      _handleFailure();
    }

    // Aggiorna la difficoltà se necessario
    _updateDifficulty(result.similarity);

    // Aggiorna le analytics
    _analyticsService.addResult(result);

    notifyListeners();
  }

  void _handleSuccess() {
    _consecutiveSuccesses++;
    _consecutiveFailures = 0;
  }

  void _handleFailure() {
    _consecutiveFailures++;
    _consecutiveSuccesses = 0;
  }

  void _updateDifficulty(double performance) {
    if (_consecutiveSuccesses >= maxConsecutiveAttempts &&
        performance >= difficultyThreshold) {
      // Aumenta la difficoltà dopo 3 successi consecutivi con alta performance
      _increaseDifficulty();
    } else if (_consecutiveFailures >= maxConsecutiveAttempts) {
      // Diminuisci la difficoltà dopo 3 fallimenti consecutivi
      _decreaseDifficulty();
    }
  }

  void _increaseDifficulty() {
    switch (_currentDifficulty) {
      case Difficulty.easy:
        _currentDifficulty = Difficulty.medium;
        break;
      case Difficulty.medium:
        _currentDifficulty = Difficulty.hard;
        break;
      case Difficulty.hard:
      // Già al massimo
        break;
    }
    notifyListeners();
  }

  void _decreaseDifficulty() {
    switch (_currentDifficulty) {
      case Difficulty.hard:
        _currentDifficulty = Difficulty.medium;
        break;
      case Difficulty.medium:
        _currentDifficulty = Difficulty.easy;
        break;
      case Difficulty.easy:
      // Già al minimo
        break;
    }
    notifyListeners();
  }

  void resetProgress() {
    _usedContent.clear();
    _consecutiveSuccesses = 0;
    _consecutiveFailures = 0;
    _currentDifficulty = Difficulty.medium;
    notifyListeners();
  }
}