// Aggiungi questo metodo alla classe GameService in game_service.dart

double getCurrentStreakMultiplier() {
  if (_currentStreak < 2) return 1.0;

  final currentLevel = Level.allLevels.firstWhere(
        (level) => level.number == player.currentLevel,
    orElse: () => Level.allLevels.first,
  );

  // Calcola il moltiplicatore base della streak
  double multiplier = 1.0 + ((_currentStreak - 1) * 0.1); // +10% per ogni streak dopo la prima

  // Applica il bonus di livello se applicabile
  if (_currentStreak >= currentLevel.streakBonusThreshold) {
    multiplier *= currentLevel.streakBonusMultiplier;
  }

  // Limita il moltiplicatore massimo
  return multiplier.clamp(1.0, 3.0);
}

// Aggiungi anche questi metodi di utility per la gestione della streak
bool get hasActiveStreak => _currentStreak >= 2;

int getStreakBonusThreshold() {
  final currentLevel = Level.allLevels.firstWhere(
        (level) => level.number == player.currentLevel,
    orElse: () => Level.allLevels.first,
  );
  return currentLevel.streakBonusThreshold;
}

double getStreakBonusMultiplier() {
  final currentLevel = Level.allLevels.firstWhere(
        (level) => level.number == player.currentLevel,
    orElse: () => Level.allLevels.first,
  );
  return currentLevel.streakBonusMultiplier;
}