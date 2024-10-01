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

  static const int crystalsPerLetter = 5;
  static const int defaultCrystals = 5;

  int get currentLevelTarget => (baseLevelTargets[player.currentLevel] ?? 0) + (player.newGamePlusCount * 5);

  double get levelProgress {
    return player.currentStep / currentLevelTarget;
  }

  Future<bool> completeStep() async {
    player.incrementStep();
    int crystalsEarned = await calculateCrystalsForStep();
    player.addCrystals(crystalsEarned);

    if (player.currentStep >= currentLevelTarget || player.isAdmin) {
      return true;  // Livello completato
    }

    return false;  // Livello non ancora completato
  }

  bool canBuyLevel() {
    return player.totalCrystals >= player.levelCrystalCost;
  }

  Future<bool> buyLevel() async {
    if (canBuyLevel()) {
      player.totalCrystals -= player.levelCrystalCost;
      player.levelUp();
      await player.saveProgress();
      return true;
    }
    return false;
  }

  Future<int> calculateCrystalsForStep() async {
    int baseCrystals;
    switch (player.currentLevel) {
      case 1:
        Word word = await getUniqueWord();
        baseCrystals = calculateCrystalsForContent(word.text);
        break;
      case 2:
        Sentence sentence = await getUniqueSentence();
        baseCrystals = calculateCrystalsForContent(sentence.words.map((w) => w.text).join());
        break;
      case 3:
        baseCrystals = calculateCrystalsForContent(contentService.getRandomParagraphForLevel3().sentences.map((s) => s.words.map((w) => w.text).join()).join());
        break;
      case 4:
        baseCrystals = calculateCrystalsForContent(contentService.getRandomPageForLevel4().paragraphs.map((p) => p.sentences.map((s) => s.words.map((w) => w.text).join()).join()).join());
        break;
      default:
        baseCrystals = defaultCrystals;
    }
    return baseCrystals * (player.newGamePlusCount + 1);
  }

  int calculateCrystalsForContent(String content) {
    int letterCount = content.replaceAll(' ', '').length;
    return letterCount * crystalsPerLetter;
  }

  Future<Word> getUniqueWord() async {
    Word word;
    do {
      word = contentService.getRandomWordForLevel1();
    } while (player.usedWords.contains(word.text));
    player.addUsedWord(word.text);
    return word;
  }

  Future<Sentence> getUniqueSentence() async {
    Sentence sentence;
    do {
      sentence = contentService.getRandomSentenceForLevel2();
    } while (player.usedSentences.contains(sentence.words.map((w) => w.text).join(' ')));
    player.addUsedSentence(sentence.words.map((w) => w.text).join(' '));
    return sentence;
  }

  void resetUsedContent() {
    player.usedWords.clear();
    player.usedSentences.clear();
  }

  String getTextForCurrentLevel() {
    switch (player.currentLevel) {
      case 1:
        return contentService.getRandomWordForLevel1().text;
      case 2:
        return contentService.getRandomSentenceForLevel2().words.map((w) => w.text).join(' ');
      case 3:
        return contentService.getRandomParagraphForLevel3().sentences.map((s) => s.words.map((w) => w.text).join(' ')).join(' ');
      case 4:
        return contentService.getRandomPageForLevel4().paragraphs.map((p) => p.sentences.map((s) => s.words.map((w) => w.text).join(' ')).join(' ')).join('\n\n');
      default:
        return "Testo non disponibile per questo livello.";
    }
  }
}