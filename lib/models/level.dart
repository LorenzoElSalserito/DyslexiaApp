// level.dart
import 'crystal.dart';
import 'enums.dart';

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
      targetCrystals: 0,  // Rimosso costo
      subLevels: [
        SubLevel(name: "Parole Semplici", minWordLength: 3, maxWordLength: 5),
      ],
      difficultyMultipliers: defaultMultipliers,
    ),
    Level(
      number: 2,
      crystalType: CrystalType.Orange,
      targetWords: 20,
      targetCrystals: 0,  // Rimosso costo
      subLevels: [
        SubLevel(name: "Parole Medie", minWords: 6, maxWords: 8),
      ],
      difficultyMultipliers: defaultMultipliers,
    ),
    Level(
      number: 3,
      crystalType: CrystalType.Yellow,
      targetWords: 20,
      targetCrystals: 0,  // Rimosso costo
      subLevels: [
        SubLevel(name: "Parole Difficili", minWords: 9, maxWords: 12),
      ],
      difficultyMultipliers: defaultMultipliers,
    ),
    Level(
      number: 4,
      crystalType: CrystalType.Green,
      targetWords: 15,
      targetCrystals: 0,  // Rimosso costo
      subLevels: [
        SubLevel(name: "Frasi", minSentences: 1, maxSentences: 1),
      ],
      difficultyMultipliers: {
        Difficulty.easy: 1.0,
        Difficulty.medium: 1.8,
        Difficulty.hard: 2.5,
      },
    ),
    Level(
      number: 5,
      crystalType: CrystalType.Blue,
      targetWords: 10,
      targetCrystals: 0,  // Rimosso costo
      subLevels: [
        SubLevel(name: "Paragrafi", minParagraphs: 1, maxParagraphs: 1),
      ],
      difficultyMultipliers: {
        Difficulty.easy: 1.0,
        Difficulty.medium: 2.0,
        Difficulty.hard: 3.0,
      },
    ),
    Level(
      number: 6,
      crystalType: CrystalType.Purple,
      targetWords: 5,
      targetCrystals: 0,  // Rimosso costo
      subLevels: [
        SubLevel(name: "Pagine", minParagraphs: 2, maxParagraphs: 3),
      ],
      difficultyMultipliers: {
        Difficulty.easy: 1.0,
        Difficulty.medium: 2.0,
        Difficulty.hard: 3.0,
      },
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