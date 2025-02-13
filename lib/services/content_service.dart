// lib/services/content_service.dart

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/content_models.dart';
import '../models/enums.dart';
import '../config/app_config.dart';

/// Servizio responsabile per il caricamento, la gestione e la distribuzione
/// di tutti i contenuti testuali dell'applicazione (parole, frasi, paragrafi, pagine).
/// Implementa anche meccanismi di cache e tracking dell'utilizzo.
class ContentService extends ChangeNotifier {
  // Cache per i contenuti caricati
  late ContentSet _contentSet;
  final Map<String, List<String>> _cachedContent = {};

  // Tracking delle parole usate per evitare ripetizioni
  final Set<String> _usedWords = {};
  final Set<String> _usedSentences = {};
  static const int _maxUsedItems = 20;
  int _exerciseCounter = 0;

  // Gestione dello stato
  bool _isInitialized = false;
  final Random _random = Random();
  String? _lastError;

  // Statistiche di utilizzo
  final Map<String, int> _wordUsageStats = {};
  final Map<Difficulty, int> _difficultyStats = {};

  /// Inizializza il servizio caricando tutti i contenuti necessari
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Carica tutti i contenuti
      final easyWords = await _loadWords(AppConfig.wordsEasyPath);
      final mediumWords = await _loadWords(AppConfig.wordsMediumPath);
      final hardWords = await _loadWords(AppConfig.wordsHardPath);
      final sentences = await _loadSentences(AppConfig.sentencesPath);
      final paragraphs = await _loadParagraphs(AppConfig.paragraphsPath);
      final pages = await _loadPages(AppConfig.pagesPath);

      // Inizializza il ContentSet
      _contentSet = ContentSet(
        dictionary: [
          ...easyWords.map((word) => Word(word)),
          ...mediumWords.map((word) => Word(word)),
          ...hardWords.map((word) => Word(word)),
        ],
        sentences: sentences,
        paragraphs: paragraphs,
        pages: pages,
      );

      _isInitialized = true;
      _lastError = null;
      notifyListeners();
    } catch (e) {
      _lastError = 'Errore nell\'inizializzazione: $e';
      debugPrint(_lastError);
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
      _lastError = 'Errore nel caricamento del file $path: $e';
      print(_lastError);
      return '';
    }
  }

  /// Carica le parole da un file
  Future<List<String>> _loadWords(String path) async {
    try {
      final content = await loadAsset(path);
      return content.split('\n')
          .where((word) => word.trim().isNotEmpty)
          .map((word) => _normalizeWord(word))
          .toList();
    } catch (e) {
      _lastError = 'Errore nel caricamento delle parole da $path: $e';
      print(_lastError);
      return [];
    }
  }

  /// Carica le frasi da un file
  Future<List<Sentence>> _loadSentences(String path) async {
    try {
      final content = await loadAsset(path);
      return content.split('\n')
          .where((sentence) => sentence.trim().isNotEmpty)
          .map((sentence) => Sentence(
          sentence.split(' ')
              .map((word) => Word(_normalizeWord(word)))
              .toList()
      ))
          .toList();
    } catch (e) {
      debugPrint('Errore nel caricamento delle frasi da $path: $e');
      return [];
    }
  }

  /// Carica i paragrafi da un file
  Future<List<Paragraph>> _loadParagraphs(String path) async {
    try {
      final content = await loadAsset(path);
      return content.split('\n\n')
          .where((paragraph) => paragraph.trim().isNotEmpty)
          .map((paragraph) => Paragraph(
          paragraph.split('.')
              .where((s) => s.trim().isNotEmpty)
              .map((sentence) => Sentence(
              sentence.trim().split(' ')
                  .map((word) => Word(_normalizeWord(word)))
                  .toList()
          ))
              .toList()
      ))
          .toList();
    } catch (e) {
      debugPrint('Errore nel caricamento dei paragrafi da $path: $e');
      return [];
    }
  }

  /// Carica le pagine da un file
  Future<List<Page>> _loadPages(String path) async {
    try {
      final content = await loadAsset(path);
      return content.split('\n\n\n')
          .where((page) => page.trim().isNotEmpty)
          .map((page) => Page(
          page.split('\n\n')
              .where((p) => p.trim().isNotEmpty)
              .map((paragraph) => Paragraph(
              paragraph.split('.')
                  .where((s) => s.trim().isNotEmpty)
                  .map((sentence) => Sentence(
                  sentence.trim().split(' ')
                      .map((word) => Word(_normalizeWord(word)))
                      .toList()
              ))
                  .toList()
          ))
              .toList()
      ))
          .toList();
    } catch (e) {
      debugPrint('Errore nel caricamento delle pagine da $path: $e');
      return [];
    }
  }

  /// Normalizza una parola
  String _normalizeWord(String word) {
    return word.trim().toLowerCase();
  }

  /// Normalizza una frase
  String _normalizeSentence(String sentence) {
    return sentence.trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\.,!?]'), '')
        .trim();
  }

  /// Normalizza un paragrafo
  String _normalizeParagraph(String paragraph) {
    return paragraph.split('.')
        .map((sentence) => _normalizeSentence(sentence))
        .where((sentence) => sentence.isNotEmpty)
        .join('. ');
  }

  /// Normalizza una pagina
  String _normalizePage(String page) {
    return page.split('\n\n')
        .map((paragraph) => _normalizeParagraph(paragraph))
        .where((paragraph) => paragraph.isNotEmpty)
        .join('\n\n');
  }

  /// Ottiene una parola casuale appropriata per il livello e la difficoltà
  Word getRandomWordForLevel(int level, Difficulty difficulty) {
    _exerciseCounter++;

    if (_exerciseCounter >= _maxUsedItems) {
      _usedWords.clear();
      _exerciseCounter = 0;
      notifyListeners();
    }

    String path;
    switch (level) {
      case 1:
        path = AppConfig.wordsEasyPath;
        break;
      case 2:
        path = AppConfig.wordsMediumPath;
        break;
      case 3:
        path = AppConfig.wordsHardPath;
        break;
      default:
        path = AppConfig.wordsEasyPath;
    }

    List<Word> availableWords = _loadSpecificWords(path)
        .where((word) => !_usedWords.contains(word.text))
        .toList();

    if (availableWords.isEmpty) {
      _usedWords.clear();
      return getRandomWordForLevel(level, difficulty);
    }

    final word = availableWords[_random.nextInt(availableWords.length)];
    _usedWords.add(word.text);
    _updateUsageStats(word.text, difficulty);
    notifyListeners();
    return word;
  }

  /// Carica parole specifiche per un determinato path
  List<Word> _loadSpecificWords(String path) {
    try {
      if (_cachedContent.containsKey(path)) {
        return _cachedContent[path]!.map((word) => Word(word)).toList();
      }

      // Usa rootBundle per caricare il file dalle risorse
      final content = rootBundle.loadString(path);
      final words = content.then((String content) {
        _cachedContent[path] = content.split('\n')
            .where((word) => word.trim().isNotEmpty)
            .map((word) => _normalizeWord(word))
            .toList();
        return _cachedContent[path]!.map((word) => Word(word)).toList();
      });

      // In attesa del caricamento, usa la cache o un insieme vuoto
      return _cachedContent[path]?.map((word) => Word(word)).toList() ?? [];
    } catch (e) {
      debugPrint('Errore nel caricamento delle parole da $path: $e');
      return [];
    }
  }


  /// Filtra le parole in base alla difficoltà
  List<Word> _getWordsForDifficulty(Difficulty difficulty) {
    final words = _contentSet.dictionary;
    switch (difficulty) {
      case Difficulty.easy:
      // Parole brevi con sillabe semplici (2-3 sillabe, max 5 lettere)
        return words.where((word) =>
        _countSyllables(word.text) <= 2 &&
            word.text.length <= 5 &&
            !_hasComplexSyllables(word.text)
        ).toList();

      case Difficulty.medium:
      // Parole di media lunghezza (3-4 sillabe, 6-8 lettere)
        return words.where((word) =>
        _countSyllables(word.text) <= 4 &&
            word.text.length > 5 &&
            word.text.length <= 8
        ).toList();

      case Difficulty.hard:
      // Parole lunghe o complesse (4+ sillabe o 8+ lettere)
        return words.where((word) =>
        _countSyllables(word.text) > 4 ||
            word.text.length > 8 ||
            _hasComplexSyllables(word.text)
        ).toList();
    }
  }

  /// Conta le sillabe in una parola italiana
  int _countSyllables(String word) {
    final vowels = RegExp('[aeiouAEIOU]');
    final diphthongs = RegExp('(ai|au|ei|eu|oi|ou|ia|ie|io|iu|ua|ue|ui|uo)');

    int count = vowels.allMatches(word).length;
    count -= diphthongs.allMatches(word).length;
    return count > 0 ? count : 1;
  }

  /// Verifica se una parola contiene sillabe complesse
  bool _hasComplexSyllables(String word) {
    // Gruppi consonantici complessi in italiano
    final complexGroups = RegExp(
        '(str|spr|scr|spl|sbl|sgl|sbr|sfr|zz|gn|gl|gh|ch|sc[ie])'
    );
    return complexGroups.hasMatch(word);
  }

  /// Aggiorna le statistiche di utilizzo
  void _updateUsageStats(String word, Difficulty difficulty) {
    _wordUsageStats[word] = (_wordUsageStats[word] ?? 0) + 1;
    _difficultyStats[difficulty] = (_difficultyStats[difficulty] ?? 0) + 1;
  }

  /// Ottiene le statistiche di utilizzo
  Map<String, dynamic> getUsageStats() {
    return {
      'totalExercises': _exerciseCounter,
      'uniqueWordsUsed': _usedWords.length,
      'wordUsage': Map<String, int>.from(_wordUsageStats),
      'difficultyStats': Map<Difficulty, int>.from(_difficultyStats),
    };
  }

  /// Pulisce la cache dei contenuti
  void clearCache() {
    _cachedContent.clear();
    notifyListeners();
  }

  /// Resetta manualmente il contatore degli esercizi e le parole usate
  void resetExerciseCounter() {
    _exerciseCounter = 0;
    _usedWords.clear();
    notifyListeners();
  }

  // Getters pubblici
  bool get isInitialized => _isInitialized;
  ContentSet get contentSet => _contentSet;
  int get exerciseCounter => _exerciseCounter;
  Set<String> get usedWords => Set.unmodifiable(_usedWords);
  Set<String> get usedSentences => Set.unmodifiable(_usedSentences);
  String? get lastError => _lastError;
}