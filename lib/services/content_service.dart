// lib/services/content_service.dart

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/content_models.dart';
import '../models/enums.dart';
import '../config/app_config.dart';

/// ContentService gestisce il caricamento e la gestione di tutto il contenuto testuale
/// dell'applicazione, inclusi parole, frasi, paragrafi e pagine.
class ContentService extends ChangeNotifier {
  late ContentSet _contentSet;
  final Random _random = Random();
  Map<String, List<String>> _cachedContent = {};
  bool _isInitialized = false;

  // Getter per verificare lo stato di inizializzazione
  bool get isInitialized => _isInitialized;

  /// Inizializza il servizio caricando tutti i contenuti necessari
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Carica i contenuti per ogni livello di difficoltà
      final easyWords = await _loadWords(AppConfig.wordsEasyPath);
      final mediumWords = await _loadWords(AppConfig.wordsMediumPath);
      final hardWords = await _loadWords(AppConfig.wordsHardPath);

      // Carica gli altri tipi di contenuto
      final sentences = await _loadSentences(AppConfig.sentencesPath);
      final paragraphs = await _loadParagraphs(AppConfig.paragraphsPath);
      final pages = await _loadPages(AppConfig.pagesPath);

      // Inizializza il ContentSet con tutti i contenuti caricati
      _contentSet = ContentSet(
        dictionary: [
          ...easyWords.map((word) => Word(word)),
          ...mediumWords.map((word) => Word(word)),
          ...hardWords.map((word) => Word(word))
        ],
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

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Errore nell\'inizializzazione di ContentService: $e');
      rethrow;
    }
  }

  /// Carica il contenuto di un file di assets
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

  /// Carica le parole da un file
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

  /// Carica le frasi da un file
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

  /// Carica i paragrafi da un file
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

  /// Carica le pagine da un file
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

  /// Ottiene una parola casuale per un dato livello e difficoltà
  Word getRandomWordForLevel(int level, Difficulty difficulty) {
    final words = _getWordsForDifficulty(difficulty);
    return words[_random.nextInt(words.length)];
  }

  /// Filtra le parole in base alla difficoltà
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

  /// Ottiene una frase casuale
  Sentence getRandomSentence() => _contentSet.getRandomSentence();

  /// Ottiene un paragrafo casuale
  Paragraph getRandomParagraph() => _contentSet.getRandomParagraph();

  /// Ottiene una pagina casuale
  Page getRandomPage() => _contentSet.getRandomPage();

  /// Ottiene un insieme di parole per un dato livello e difficoltà
  List<Word> getWordsForLevel(int count, Difficulty difficulty) {
    final words = _getWordsForDifficulty(difficulty);
    if (words.length < count) return words;

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

  /// Ottiene un insieme di frasi per un dato livello
  List<Sentence> getSentencesForLevel(int count) {
    return List.generate(count, (_) => getRandomSentence());
  }

  /// Ottiene un insieme di paragrafi per un dato livello
  List<Paragraph> getParagraphsForLevel(int count) {
    return List.generate(count, (_) => getRandomParagraph());
  }

  /// Ottiene un insieme di pagine per un dato livello
  List<Page> getPagesForLevel(int count) {
    return List.generate(count, (_) => getRandomPage());
  }

  /// Calcola il valore in cristalli per un dato contenuto
  int calculateCrystals(dynamic content) {
    if (content is Word) return content.crystalValue;
    if (content is Sentence) return content.crystalValue;
    if (content is Paragraph) return content.crystalValue;
    if (content is Page) return content.crystalValue;
    return 0;
  }

  /// Pulisce la cache dei contenuti
  void clearCache() {
    _cachedContent.clear();
    notifyListeners();
  }
}