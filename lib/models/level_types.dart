// lib/models/level_types.dart

enum Difficulty { easy, medium, hard }

enum ExerciseType { word, sentence, paragraph, page }

class DifficultySettings {
  final double scoreMultiplier;
  final int minWordLength;
  final int maxWordLength;

  const DifficultySettings({
    required this.scoreMultiplier,
    required this.minWordLength,
    required this.maxWordLength,
  });

  static const Map<Difficulty, DifficultySettings> defaults = {
    Difficulty.easy: DifficultySettings(
      scoreMultiplier: 1.0,
      minWordLength: 3,
      maxWordLength: 5,
    ),
    Difficulty.medium: DifficultySettings(
      scoreMultiplier: 1.5,
      minWordLength: 6,
      maxWordLength: 8,
    ),
    Difficulty.hard: DifficultySettings(
      scoreMultiplier: 2.0,
      minWordLength: 9,
      maxWordLength: 12,
    ),
  };
}