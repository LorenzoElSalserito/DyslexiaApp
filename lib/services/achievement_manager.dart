// achievement_manager.dart

import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../services/learning_analytics_service.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final int requiredProgress;
  final int crystalReward;
  final bool isSecret;
  bool isUnlocked;
  int currentProgress;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredProgress,
    required this.crystalReward,
    this.isSecret = false,
    this.isUnlocked = false,
    this.currentProgress = 0,
  });

  double get progressPercentage =>
      currentProgress / requiredProgress;

  Map<String, dynamic> toJson() => {
    'id': id,
    'isUnlocked': isUnlocked,
    'currentProgress': currentProgress,
  };

  factory Achievement.fromJson(Map<String, dynamic> json, Achievement template) {
    return Achievement(
      id: template.id,
      title: template.title,
      description: template.description,
      requiredProgress: template.requiredProgress,
      crystalReward: template.crystalReward,
      isSecret: template.isSecret,
      isUnlocked: json['isUnlocked'] ?? false,
      currentProgress: json['currentProgress'] ?? 0,
    );
  }
}

class AchievementManager extends ChangeNotifier {
  final Player _player;
  final LearningAnalyticsService _analytics;
  final Map<String, Achievement> _achievements = {};

  static final List<Achievement> _achievementTemplates = [
    // Achievements di base
    Achievement(
      id: 'first_word',
      title: 'Prima Parola',
      description: 'Completa il tuo primo esercizio di lettura',
      requiredProgress: 1,
      crystalReward: 50,
    ),
    Achievement(
      id: 'word_master',
      title: 'Maestro delle Parole',
      description: 'Completa 100 esercizi con parole singole',
      requiredProgress: 100,
      crystalReward: 500,
    ),

    // Achievements di streak
    Achievement(
      id: 'perfect_streak',
      title: 'Streak Perfetta',
      description: 'Mantieni una streak di 10 esercizi corretti',
      requiredProgress: 10,
      crystalReward: 200,
    ),

    // Achievements segreti
    Achievement(
      id: 'speed_reader',
      title: '???',
      description: 'Completa un esercizio in meno di 5 secondi',
      requiredProgress: 1,
      crystalReward: 300,
      isSecret: true,
    ),

    // Achievements di progresso
    Achievement(
      id: 'level_master',
      title: 'Maestro di Livello',
      description: 'Raggiungi il livello 4',
      requiredProgress: 4,
      crystalReward: 1000,
    ),

    // Achievements di New Game+
    Achievement(
      id: 'new_game_plus',
      title: 'Nuovo Inizio',
      description: 'Inizia un New Game+',
      requiredProgress: 1,
      crystalReward: 2000,
    ),
  ];

  AchievementManager({
    required Player player,
    required LearningAnalyticsService analytics,
  }) : _player = player,
        _analytics = analytics {
    _initializeAchievements();
  }

  List<Achievement> get achievements => _achievements.values.toList();
  List<Achievement> get unlockedAchievements =>
      achievements.where((a) => a.isUnlocked).toList();
  List<Achievement> get visibleAchievements =>
      achievements.where((a) => !a.isSecret || a.isUnlocked).toList();

  Future<void> _initializeAchievements() async {
    // Carica i template
    for (var template in _achievementTemplates) {
      _achievements[template.id] = template;
    }

    // Carica i progressi salvati
    await _loadProgress();
  }

  Future<void> _loadProgress() async {
    final stats = await _analytics.getStats();

    // Aggiorna i progressi basati sulle statistiche
    _updateWordProgress(stats.totalAttempts);
    _updateStreakProgress(stats.successfulAttempts);
    _updateLevelProgress(_player.currentLevel);
    _updateNewGameProgress(_player.newGamePlusCount);

    notifyListeners();
  }

  void _updateWordProgress(int attempts) {
    _updateAchievementProgress('first_word', attempts);
    _updateAchievementProgress('word_master', attempts);
  }

  void _updateStreakProgress(int streak) {
    _updateAchievementProgress('perfect_streak', streak);
  }

  void _updateLevelProgress(int level) {
    _updateAchievementProgress('level_master', level);
  }

  void _updateNewGameProgress(int count) {
    _updateAchievementProgress('new_game_plus', count);
  }

  void _updateAchievementProgress(String id, int progress) {
    final achievement = _achievements[id];
    if (achievement != null && !achievement.isUnlocked) {
      achievement.currentProgress = progress;
      if (achievement.currentProgress >= achievement.requiredProgress) {
        _unlockAchievement(achievement);
      }
      notifyListeners();
    }
  }

  void _unlockAchievement(Achievement achievement) {
    if (!achievement.isUnlocked) {
      achievement.isUnlocked = true;
      _player.addCrystals(achievement.crystalReward);
      notifyListeners();

      // TODO: Mostra notifica achievement sbloccato
    }
  }

  // Metodi pubblici per l'aggiornamento dei progressi
  void onExerciseCompleted(double time) {
    if (time < 5.0) {
      _updateAchievementProgress('speed_reader', 1);
    }
  }

  void onStreakUpdated(int streak) {
    _updateAchievementProgress('perfect_streak', streak);
  }

  void onLevelUp(int level) {
    _updateAchievementProgress('level_master', level);
  }

  void onNewGamePlus() {
    _updateAchievementProgress('new_game_plus', 1);
  }

  // Salvataggio e caricamento
  Map<String, dynamic> toJson() {
    return {
      'achievements': _achievements.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  void loadFromJson(Map<String, dynamic> json) {
    final achievementsData = json['achievements'] as Map<String, dynamic>;
    achievementsData.forEach((key, value) {
      final template = _achievements[key];
      if (template != null) {
        _achievements[key] = Achievement.fromJson(value as Map<String, dynamic>, template);
      }
    });
    notifyListeners();
  }
}