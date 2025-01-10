// level.dart
import 'crystal.dart';

enum Difficulty { easy, medium, hard }

class Level {
  final int number;
  final CrystalType crystalType;
  final int targetWords;
  final int targetCrystals;
  final List<SubLevel> subLevels;
  final Map<Difficulty, double> difficultyMultipliers;
  final int streakBonusThreshold;
  final double streakBonusMultiplier;

  const Level({
    required this.number,
    required this.crystalType,
    required this.targetWords,
    required this.targetCrystals,
    required this.subLevels,
    required this.difficultyMultipliers,
    this.streakBonusThreshold = 3,
    this.streakBonusMultiplier = 1.5,
  });

  static const Map<Difficulty, double> defaultMultipliers = {
    Difficulty.easy: 1.0,
    Difficulty.medium: 1.5,
    Difficulty.hard: 2.0,
  };

  static List<Level> allLevels = [
    Level(
      number: 1,
      crystalType: CrystalType.Red,
      targetWords: 30,
      targetCrystals: 300,
      subLevels: [
        SubLevel(name: "Parole Semplici", minWordLength: 3, maxWordLength: 5),
        SubLevel(name: "Parole Medie", minWordLength: 6, maxWordLength: 8),
        SubLevel(name: "Parole Complesse", minWordLength: 9, maxWordLength: 12),
      ],
      difficultyMultipliers: defaultMultipliers,
    ),
    Level(
      number: 2,
      crystalType: CrystalType.Orange,
      targetWords: 20,
      targetCrystals: 1500,
      subLevels: [
        SubLevel(name: "Frasi Brevi", minWords: 3, maxWords: 5),
        SubLevel(name: "Frasi Medie", minWords: 6, maxWords: 8),
        SubLevel(name: "Frasi Lunghe", minWords: 9, maxWords: 12),
      ],
      difficultyMultipliers: defaultMultipliers,
    ),
    Level(
      number: 3,
      crystalType: CrystalType.Yellow,
      targetWords: 20,
      targetCrystals: 5000,
      subLevels: [
        SubLevel(name: "Paragrafi Semplici", minSentences: 2, maxSentences: 3),
        SubLevel(name: "Paragrafi Medi", minSentences: 4, maxSentences: 6),
        SubLevel(name: "Paragrafi Complessi", minSentences: 7, maxSentences: 9),
      ],
      difficultyMultipliers: {
        Difficulty.easy: 1.0,
        Difficulty.medium: 1.8,
        Difficulty.hard: 2.5,
      },
    ),
    Level(
      number: 4,
      crystalType: CrystalType.White,
      targetWords: 10,
      targetCrystals: 0,
      subLevels: [
        SubLevel(name: "Pagine Brevi", minParagraphs: 2, maxParagraphs: 3),
        SubLevel(name: "Pagine Medie", minParagraphs: 4, maxParagraphs: 6),
        SubLevel(name: "Pagine Complete", minParagraphs: 7, maxParagraphs: 9),
      ],
      difficultyMultipliers: {
        Difficulty.easy: 1.0,
        Difficulty.medium: 2.0,
        Difficulty.hard: 3.0,
      },
      streakBonusThreshold: 2,
      streakBonusMultiplier: 2.0,
    ),
  ];

  int calculateReward(
      int baseReward, {
        required Difficulty difficulty,
        required int streak,
        required int newGamePlusLevel,
      }) {
    double multiplier = 1.0;

    // Applica il moltiplicatore di difficoltà
    multiplier *= difficultyMultipliers[difficulty] ?? 1.0;

    // Applica il bonus streak se applicabile
    if (streak >= streakBonusThreshold) {
      multiplier *= streakBonusMultiplier;
    }

    // Bonus New Game+
    multiplier *= (1.0 + (newGamePlusLevel * 0.5));

    return (baseReward * multiplier).round();
  }
}

class SubLevel {
  final String name;
  final int? minWordLength;
  final int? maxWordLength;
  final int? minWords;
  final int? maxWords;
  final int? minSentences;
  final int? maxSentences;
  final int? minParagraphs;
  final int? maxParagraphs;

  const SubLevel({
    required this.name,
    this.minWordLength,
    this.maxWordLength,
    this.minWords,
    this.maxWords,
    this.minSentences,
    this.maxSentences,
    this.minParagraphs,
    this.maxParagraphs,
  });

  bool get isWordLevel => minWordLength != null && maxWordLength != null;
  bool get isSentenceLevel => minWords != null && maxWords != null;
  bool get isParagraphLevel => minSentences != null && maxSentences != null;
  bool get isPageLevel => minParagraphs != null && maxParagraphs != null;
}