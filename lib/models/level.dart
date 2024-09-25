// lib/models/level.dart
import 'crystal.dart';

class Level {
  final int number;
  final CrystalType crystalType;
  final int targetWords;
  final int targetCrystals;

  Level(this.number, this.crystalType, this.targetWords, this.targetCrystals);

  static List<Level> allLevels = [
    Level(1, CrystalType.Red, 30, 300),
    Level(2, CrystalType.Orange, 20, 1500),
    Level(3, CrystalType.Yellow, 20, 5000),
    Level(4, CrystalType.White, 10, 0),  // Il livello 4 non ha un target di cristalli
  ];
}
