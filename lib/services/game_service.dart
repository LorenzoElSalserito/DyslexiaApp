import 'dart:async';
import '../models/player.dart';
import '../models/content_models.dart';
import 'content_service.dart';

class GameService {
  final Player player;
  final ContentService contentService;

  GameService({required this.player, required this.contentService});

  static const Map<int, int> levelTargets = {
    1: 30,  // 30 parole
    2: 20,  // 20 frasi
    3: 20,  // 20 paragrafi
    4: 10,  // 10 pagine
  };

  static const Map<int, int> levelCrystalTargets = {
    1: 300,
    2: 1500,
    3: 5000,
    4: 0,  // Il livello 4 non ha un target di cristalli
  };

  double get levelProgress {
    return player.currentStep / levelTargets[player.currentLevel]!;
  }

  Future<void> startLevel() async {
    player.currentStep = 0;
    player.saveProgress();
  }

  Future<bool> completeStep() async {
    player.incrementStep();
    int crystalsEarned = await calculateCrystalsForStep();
    player.addCrystals(crystalsEarned);

    if (player.currentStep >= levelTargets[player.currentLevel]! ||
        (player.isAdmin && player.currentStep > 0)) {
      return true;  // Livello completato
    }

    if (player.totalCrystals >= levelCrystalTargets[player.currentLevel]! && player.currentLevel < 4) {
      return true;  // Livello completato per cristalli (solo per livelli 1-3)
    }

    return false;  // Livello non ancora completato
  }

  Future<int> calculateCrystalsForStep() async {
    switch (player.currentLevel) {
      case 1:
        return contentService.getRandomWordForLevel1().crystalValue;
      case 2:
        return contentService.getRandomSentenceForLevel2().crystalValue;
      case 3:
        return contentService.getRandomParagraphForLevel3().crystalValue;
      case 4:
        return contentService.getRandomPageForLevel4().crystalValue;
      default:
        return 0;
    }
  }
}