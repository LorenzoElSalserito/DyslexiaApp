import 'dart:math';
import 'package:flutter/services.dart';
import '../models/content_models.dart';
import '../models/enums.dart';
import '../config/app_config.dart';

class ContentService {
  late ContentSet _contentSet;
  final Random _random = Random();
  Map<String, List<String>> _cachedContent = {};

  // Inizializza il servizio caricando i dati
  Future<void> initialize() async {
    try {
      // Carica tutti i contenuti necessari
      final easyWords = await _loadWords(AppConfig.wordsEasyPath);
      final mediumWords = await _loadWords(AppConfig.wordsMediumPath);
      final hardWords = await _loadWords(AppConfig.wordsHardPath);
      final sentences = await _loadSentences(AppConfig.sentencesPath);
      final paragraphs = await _loadParagraphs(AppConfig.paragraphsPath);
      final pages = await _loadPages(AppConfig.pagesPath);

      // Crea il ContentSet
      _contentSet = ContentSet(
        dictionary: [...easyWords.map((word) => Word(word)),
          ...mediumWords.map((word) => Word(word)),
          ...hardWords.map((word) => Word(word))],
        sentences: sentences.map((text) =>
            Sentence(text.split(' ').map((word) => Word(word)).toList())
        ).toList(),
        paragraphs: paragraphs.map((text) =>
            Paragraph(text.split('.').where((s) => s.trim().isNotEmpty)
                .map((sentence) =>
                Sentence(sentence.trim().split(' ')
                    .map((word) => Word(word)).toList())
            ).toList())
        ).toList(),
        pages: pages.map((text) =>
            Page(text.split('\n\n').where((p) => p.trim().isNotEmpty)
                .map((paragraph) =>
                Paragraph(paragraph.split('.').where((s) => s.trim().isNotEmpty)
                    .map((sentence) =>
                    Sentence(sentence.trim().split(' ')
                        .map((word) => Word(word)).toList())
                ).toList())
            ).toList())
        ).toList(),
      );
    } catch (e) {
      print('Errore nell\'inizializzazione di ContentService: $e');
      rethrow;
    }
  }

  Future<String> loadAsset(String path) async {
    try {
      if (_cachedContent.containsKey(path)) {
        return _cachedContent[path]!.join('\n');
      }

      final content = await rootBundle.loadString(path);
      _cachedContent[path] = content.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      return content;
    } catch (e) {
      print('Errore nel caricamento del file $path: $e');
      return '';
    }
  }

  Future<List<String>> _loadWords(String path) async {
    try {
      final content = await loadAsset(path);
      return content.split('\n')
          .where((word) => word.trim().isNotEmpty)
          .map((word) => word.trim())
          .toList();
    } catch (e) {
      print('Errore nel caricamento delle parole da $path: $e');
      return [];
    }
  }

  Future<List<String>> _loadSentences(String path) async {
    try {
      final content = await loadAsset(path);
      return content.split('\n')
          .where((sentence) => sentence.trim().isNotEmpty)
          .map((sentence) => sentence.trim())
          .toList();
    } catch (e) {
      print('Errore nel caricamento delle frasi da $path: $e');
      return [];
    }
  }

  Future<List<String>> _loadParagraphs(String path) async {
    try {
      final content = await loadAsset(path);
      return content.split('\n\n')
          .where((paragraph) => paragraph.trim().isNotEmpty)
          .map((paragraph) => paragraph.trim())
          .toList();
    } catch (e) {
      print('Errore nel caricamento dei paragrafi da $path: $e');
      return [];
    }
  }

  Future<List<String>> _loadPages(String path) async {
    try {
      final content = await loadAsset(path);
      return content.split('\n\n\n')
          .where((page) => page.trim().isNotEmpty)
          .map((page) => page.trim())
          .toList();
    } catch (e) {
      print('Errore nel caricamento delle pagine da $path: $e');
      return [];
    }
  }

  Word getRandomWordForLevel(int level, Difficulty difficulty) {
    final words = _getWordsForDifficulty(difficulty);
    return words[_random.nextInt(words.length)];
  }

  List<Word> _getWordsForDifficulty(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return _contentSet.dictionary.where((word) =>
        word.text.length <= 5).toList();
      case Difficulty.medium:
        return _contentSet.dictionary.where((word) =>
        word.text.length > 5 && word.text.length <= 8).toList();
      case Difficulty.hard:
        return _contentSet.dictionary.where((word) =>
        word.text.length > 8).toList();
    }
  }

  Sentence getRandomSentence() => _contentSet.getRandomSentence();
  Paragraph getRandomParagraph() => _contentSet.getRandomParagraph();
  Page getRandomPage() => _contentSet.getRandomPage();

  List<Word> getWordsForLevel(int count, Difficulty difficulty) {
    final words = _getWordsForDifficulty(difficulty);
    if (words.length < count) {
      return words;
    }

    final selectedWords = <Word>[];
    final usedIndexes = <int>{};

    while (selectedWords.length < count) {
      final index = _random.nextInt(words.length);
      if (!usedIndexes.contains(index)) {
        selectedWords.add(words[index]);
        usedIndexes.add(index);
      }
    }

    return selectedWords;
  }

  List<Sentence> getSentencesForLevel(int count) {
    return List.generate(count, (_) => getRandomSentence());
  }

  List<Paragraph> getParagraphsForLevel(int count) {
    return List.generate(count, (_) => getRandomParagraph());
  }

  List<Page> getPagesForLevel(int count) {
    return List.generate(count, (_) => getRandomPage());
  }

  int calculateCrystals(dynamic content) {
    if (content is Word) return content.crystalValue;
    if (content is Sentence) return content.crystalValue;
    if (content is Paragraph) return content.crystalValue;
    if (content is Page) return content.crystalValue;
    return 0;
  }

  void clearCache() {
    _cachedContent.clear();
  }
}