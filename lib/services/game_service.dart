import 'dart:async';
import '../models/player.dart';
import '../models/content_models.dart';
import 'content_service.dart';

class GameService {
  final Player player;
  final ContentService contentService;

  GameService({required this.player, required this.contentService});

  static const Map<int, int> baseLevelTargets = {
    1: 30,  // 30 parole
    2: 20,  // 20 frasi
    3: 20,  // 20 paragrafi
    4: 10,  // 10 pagine
  };

  int get currentLevelTarget => (baseLevelTargets[player.currentLevel] ?? 0) + (player.newGamePlusCount * 5);

  double get levelProgress {
    return player.currentStep / currentLevelTarget;
  }

  Future<bool> completeStep() async {
    player.incrementStep();
    int crystalsEarned = await calculateCrystalsForStep();
    player.addCrystals(crystalsEarned);

    // Controlla se il livello è completato
    if (isLevelCompleted()) {
      return true;  // Livello completato
    }

    return false;  // Livello non ancora completato
  }

  bool isLevelCompleted() {
    return player.currentStep >= currentLevelTarget || player.isAdmin;
  }

  bool canBuyLevel() {
    return player.totalCrystals >= player.levelCrystalCost;
  }

  void buyLevel() {
    if (canBuyLevel()) {
      player.totalCrystals -= player.levelCrystalCost;
      player.levelUp();
    }
  }

  Future<int> calculateCrystalsForStep() async {
    int baseCrystals;
    switch (player.currentLevel) {
      case 1:
        Word word = await getUniqueWord();
        player.addUsedWord(word.text);
        baseCrystals = word.crystalValue;
        break;
      case 2:
        Sentence sentence = await getUniqueSentence();
        player.addUsedSentence(sentence.words.map((w) => w.text).join(' '));
        baseCrystals = sentence.crystalValue;
        break;
      case 3:
        baseCrystals = contentService.getRandomParagraphForLevel3().crystalValue;
        break;
      case 4:
        baseCrystals = contentService.getRandomPageForLevel4().crystalValue;
        break;
      default:
        baseCrystals = 0;
    }
    return baseCrystals * (player.newGamePlusCount + 1);
  }

  Future<Word> getUniqueWord() async {
    Word word;
    do {
      word = contentService.getRandomWordForLevel1();
    } while (player.usedWords.contains(word.text));
    return word;
  }

  Future<Sentence> getUniqueSentence() async {
    Sentence sentence;
    do {
      sentence = contentService.getRandomSentenceForLevel2();
    } while (player.usedSentences.contains(sentence.words.map((w) => w.text).join(' ')));
    return sentence;
  }

  void resetUsedContent() {
    player.usedWords.clear();
    player.usedSentences.clear();
  }
}