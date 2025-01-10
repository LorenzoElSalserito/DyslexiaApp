// lib/services/exercise_manager.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../models/recognition_result.dart';
import '../services/content_service.dart';
import '../services/learning_analytics_service.dart';

enum ExerciseType {
  word,
  sentence,
  paragraph,
  page
}

class ExercisePool {
  final List<String> easyWords;
  final List<String> mediumWords;
  final List<String> hardWords;
  final List<String> sentenceTemplates;
  final List<String> paragraphTemplates;
  final List<String> pageTemplates;
  final Random random = Random();

  ExercisePool({
    required this.easyWords,
    required this.mediumWords,
    required this.hardWords,
    required this.sentenceTemplates,
    required this.paragraphTemplates,
    required this.pageTemplates,
  });

  String getRandomWord(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return easyWords[random.nextInt(easyWords.length)];
      case Difficulty.medium:
        return mediumWords[random.nextInt(mediumWords.length)];
      case Difficulty.hard:
        return hardWords[random.nextInt(hardWords.length)];
    }
  }

  String getRandomTemplate(ExerciseType type) {
    switch (type) {
      case ExerciseType.sentence:
        return sentenceTemplates[random.nextInt(sentenceTemplates.length)];
      case ExerciseType.paragraph:
        return paragraphTemplates[random.nextInt(paragraphTemplates.length)];
      case ExerciseType.page:
        return pageTemplates[random.nextInt(pageTemplates.length)];
      default:
        throw Exception('Invalid exercise type for template');
    }
  }
}

class Exercise {
  final String content;
  final ExerciseType type;
  final int difficulty;
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
  late ExercisePool _exercisePool;
  final List<String> _usedContent = [];
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
        _analyticsService = analyticsService {
    _initializeExercisePool();
  }

  Exercise? get currentExercise => _currentExercise;
  Difficulty get currentDifficulty => _currentDifficulty;

  Future<void> _initializeExercisePool() async {
    // In un'app reale, questi verrebbero caricati da file o database
    _exercisePool = ExercisePool(
      easyWords: await _loadWords('assets/easy_words.txt'),
      mediumWords: await _loadWords('assets/medium_words.txt'),
      hardWords: await _loadWords('assets/hard_words.txt'),
      sentenceTemplates: await _loadTemplates('assets/sentences.txt'),
      paragraphTemplates: await _loadTemplates('assets/paragraphs.txt'),
      pageTemplates: await _loadTemplates('assets/pages.txt'),
    );
  }

  Future<List<String>> _loadWords(String path) async {
    try {
      final content = await _contentService.loadAsset(path);
      return content.split('\n').where((word) => word.isNotEmpty).toList();
    } catch (e) {
      print('Error loading words from $path: $e');
      return [];
    }
  }

  Future<List<String>> _loadTemplates(String path) async {
    try {
      final content = await _contentService.loadAsset(path);
      return content.split('\n\n').where((template) => template.isNotEmpty).toList();
    } catch (e) {
      print('Error loading templates from $path: $e');
      return [];
    }
  }

  Future<Exercise> generateExercise() async {
    ExerciseType type = _getExerciseTypeForLevel(_player.currentLevel);
    String content = await _generateContent(type);
    int baseValue = _calculateBaseValue(content, type);
    int difficulty = _calculateDifficulty();

    _currentExercise = Exercise(
      content: content,
      type: type,
      difficulty: difficulty,
      crystalValue: _calculateCrystalValue(baseValue, difficulty),
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
    switch (type) {
      case ExerciseType.word:
        return _exercisePool.getRandomWord(_currentDifficulty);
      case ExerciseType.sentence:
        String template = _exercisePool.getRandomTemplate(type);
        return _fillTemplate(template);
      case ExerciseType.paragraph:
        String template = _exercisePool.getRandomTemplate(type);
        return _fillTemplate(template);
      case ExerciseType.page:
        String template = _exercisePool.getRandomTemplate(type);
        return _fillTemplate(template);
    }
  }

  String _fillTemplate(String template) {
    // Sostituisci i placeholder con parole appropriate
    RegExp placeholderRegex = RegExp(r'\{(\w+)\}');
    return template.replaceAllMapped(placeholderRegex, (match) {
      String type = match.group(1)?.toLowerCase() ?? '';
      return _exercisePool.getRandomWord(_currentDifficulty);
    });
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

  int _calculateDifficulty() {
    return _player.currentLevel + _player.newGamePlusCount;
  }

  int _calculateCrystalValue(int baseValue, int difficulty) {
    double multiplier = 1.0;

    // Bonus per difficoltà
    multiplier *= 1.0 + (difficulty * 0.1);

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
      _handleSuccess(result);
    } else {
      _handleFailure(result);
    }

    // Aggiorna la difficoltà se necessario
    _updateDifficulty(result.similarity);

    // Aggiorna le analytics
    await _analyticsService.addResult(result);

    notifyListeners();
  }

  void _handleSuccess(RecognitionResult result) {
    _consecutiveSuccesses++;
    _consecutiveFailures = 0;
  }

  void _handleFailure(RecognitionResult result) {
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
  }

  void resetProgress() {
    _usedContent.clear();
    _consecutiveSuccesses = 0;
    _consecutiveFailures = 0;
    _currentDifficulty = Difficulty.medium;
    notifyListeners();
  }
}