import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../models/level.dart';
import '../models/recognition_result.dart';
import '../services/content_service.dart';
import '../services/exercise_manager.dart';
import '../models/enums.dart';

class GameService extends ChangeNotifier {
  final Player player;
  final ContentService contentService;
  final ExerciseManager exerciseManager;

  int _currentStreak = 0;
  int _totalAttempts = 0;
  int _successfulAttempts = 0;
  int _currentLevelTarget = 30; // Default value

  GameService({
    required this.player,
    required this.contentService,
    required this.exerciseManager,
  });

  // Getters
  int get currentStreak => _currentStreak;
  double get levelProgress => player.currentStep / currentLevelTarget;
  int get totalAttempts => _totalAttempts;
  int get successfulAttempts => _successfulAttempts;
  Difficulty get currentDifficulty => exerciseManager.currentDifficulty;
  int get currentLevelTarget => _currentLevelTarget;

  bool get hasActiveStreak => _currentStreak >= 2;

  // Methods for text management
  String getTextForCurrentLevel() {
    return contentService.getRandomWordForLevel(
      player.currentLevel,
      currentDifficulty,
    ).text;
  }

  int getCurrentLevelTarget() {
    final level = Level.allLevels.firstWhere(
          (level) => level.number == player.currentLevel,
      orElse: () => Level.allLevels.first,
    );
    return level.targetWords;
  }

  SubLevel getCurrentSubLevel() {
    final level = Level.allLevels.firstWhere(
          (level) => level.number == player.currentLevel,
      orElse: () => Level.allLevels.first,
    );

    final progress = levelProgress;
    if (progress < 0.33) {
      return level.subLevels[0];
    } else if (progress < 0.66) {
      return level.subLevels[1];
    } else {
      return level.subLevels[2];
    }
  }

  double getCurrentStreakMultiplier() {
    if (_currentStreak < 2) return 1.0;

    final currentLevel = Level.allLevels.firstWhere(
          (level) => level.number == player.currentLevel,
      orElse: () => Level.allLevels.first,
    );

    // Calcola il moltiplicatore base
    double multiplier = 1.0 + ((_currentStreak - 1) * 0.1);

    // Applica bonus di livello se applicabile
    if (_currentStreak >= currentLevel.streakBonusThreshold) {
      multiplier *= currentLevel.streakBonusMultiplier;
    }

    return multiplier.clamp(1.0, 3.0);
  }

  Future<bool> processRecognitionResult(RecognitionResult result) async {
    _totalAttempts++;

    if (result.isCorrect) {
      _successfulAttempts++;
      _currentStreak++;
      await completeStep();
      notifyListeners();
      return player.currentStep >= currentLevelTarget;
    } else {
      _currentStreak = 0;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeStep() async {
    player.incrementStep();

    final levelCompleted = player.currentStep >= currentLevelTarget;
    if (levelCompleted) {
      player.levelUp();
      player.currentStep = 0;
      _currentStreak = 0;
      _updateLevelTarget();
    }

    notifyListeners();
    return levelCompleted;
  }

  void _updateLevelTarget() {
    final level = Level.allLevels.firstWhere(
          (level) => level.number == player.currentLevel,
      orElse: () => Level.allLevels.first,
    );
    _currentLevelTarget = level.targetWords;
  }

  bool canBuyLevel() {
    return player.canLevelUp();
  }

  Future<bool> buyLevel() async {
    if (!canBuyLevel()) return false;

    player.levelUp();
    _updateLevelTarget();
    notifyListeners();
    return true;
  }

  void resetStreak() {
    _currentStreak = 0;
    notifyListeners();
  }
}