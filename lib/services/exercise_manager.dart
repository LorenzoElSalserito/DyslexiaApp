// lib/services/exercise_manager.dart

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import '../models/player.dart';
import '../models/recognition_result.dart';
import '../services/content_service.dart';
import '../services/learning_analytics_service.dart';
import '../models/enums.dart';
import '../services/audio_service.dart';

/// Gestisce la creazione, esecuzione e tracciamento degli esercizi di lettura.
/// Si occupa anche del salvataggio dei progressi e della gestione delle sessioni audio.
class ExerciseManager extends ChangeNotifier {
  // Stato interno del manager
  late Player _player;
  final ContentService _contentService;
  final LearningAnalyticsService _analyticsService;
  final AudioService _audioService = AudioService();
  final Random _random = Random();
  static const int maxLevel = 6;

  // Stato della sessione corrente
  Exercise? _currentExercise;
  List<String> _usedContent = [];
  List<RecognitionResult> _sessionResults = [];
  int _currentSessionIndex = 0;
  Difficulty _currentDifficulty = Difficulty.easy;
  bool _isSessionActive = false;
  bool _isInitialized = false;

  // Statistiche della sessione
  List<double> _sessionAccuracies = [];
  double _overallAccuracy = 0.0;
  int _totalCrystals = 0;
  int _sessionCrystals = 0;

  // Costanti
  static const int exercisesPerSession = 5;
  static const double requiredAccuracy = 0.75;
  static const double mediumDifficultyThreshold = 0.85;
  static const double hardDifficultyThreshold = 0.95;

  /// Costruttore del manager
  ExerciseManager({
    required Player player,
    required ContentService contentService,
    required LearningAnalyticsService analyticsService,
  })  : _contentService = contentService,
        _analyticsService = analyticsService {
    debugPrint('[ExerciseManager] Costruttore: Inizializzo ExerciseManager con player: ${player.toJson()}');
    _player = player; // Memorizza l'istanza del player
    _initialize();
  }

  /// Metodo per aggiornare l'istanza di Player
  void updatePlayer(Player newPlayer) async {
    debugPrint('[ExerciseManager] updatePlayer: Aggiornamento player...');
    _player = newPlayer;  // Aggiorna l'istanza del player
    await _player.loadProgress(); // Carica il progresso dal file
    debugPrint('[ExerciseManager] updatePlayer: Nuovo player = ${_player.toJson()}');
    notifyListeners();
  }

  /// Inizializza il manager
  Future<void> _initialize() async {
    debugPrint('[ExerciseManager] _initialize: Inizializzazione avviata.');
    try {
      debugPrint('[ExerciseManager] _initialize: Inizializzo AudioService...');
      await _audioService.initialize();
      debugPrint('[ExerciseManager] _initialize: Carico il progresso del giocatore...');
      await _player.loadProgress(); // Carica il progresso dal file
      _isInitialized = true;
      debugPrint('[ExerciseManager] _initialize: Inizializzazione completata.');
      notifyListeners();
    } catch (e) {
      debugPrint('[ExerciseManager] _initialize: ERRORE durante l\'inizializzazione: $e');
      rethrow;
    }
  }

  /// Inizia una nuova sessione di esercizi
  Future<void> startNewSession() async {
    debugPrint('[ExerciseManager] startNewSession: Avvio nuova sessione.');
    if (!_isInitialized) {
      debugPrint('[ExerciseManager] startNewSession: Manager non inizializzato. Chiamo _initialize()...');
      await _initialize();
    }
    debugPrint('[ExerciseManager] startNewSession: Pulizia sessione precedente.');
    await cleanupSession();
    debugPrint('[ExerciseManager] startNewSession: Reinizializzo AudioService per la nuova sessione.');
    await _audioService.initialize();

    _sessionResults.clear();
    _currentSessionIndex = 0;
    _sessionCrystals = 0;
    _totalCrystals = 0;
    _isSessionActive = true;
    _usedContent.clear();

    debugPrint('[ExerciseManager] startNewSession: Avvio sessione analytics.');
    _analyticsService.startSession();
    debugPrint('[ExerciseManager] startNewSession: Nuova sessione avviata.');
    notifyListeners();
  }

  /// Genera un nuovo esercizio
  Future<Exercise> generateExercise() async {
    debugPrint('[ExerciseManager] generateExercise: Inizio generazione esercizio.');
    if (!_isInitialized) {
      debugPrint('[ExerciseManager] generateExercise: Manager non inizializzato.');
      throw Exception('ExerciseManager non inizializzato');
    }
    if (!_isSessionActive) {
      debugPrint('[ExerciseManager] generateExercise: Sessione non attiva.');
      throw Exception('Sessione non attiva. Chiamare startNewSession() prima.');
    }

    String content;
    ExerciseType exerciseType;
    debugPrint('[ExerciseManager] generateExercise: Livello corrente del giocatore: ${_player.currentLevel}');

    switch (_player.currentLevel) {
      case 1:
        exerciseType = ExerciseType.word;
        content = _contentService.getRandomWordForLevel(1, _currentDifficulty).text;
        break;
      case 2:
        exerciseType = ExerciseType.word;
        content = _contentService.getRandomWordForLevel(2, _currentDifficulty).text;
        break;
      case 3:
        exerciseType = ExerciseType.word;
        content = _contentService.getRandomWordForLevel(3, _currentDifficulty).text;
        break;
      case 4:
        exerciseType = ExerciseType.sentence;
        final sentence = _contentService.contentSet.sentences[Random().nextInt(_contentService.contentSet.sentences.length)];
        content = sentence.words.map((w) => w.text).join(' ');
        break;
      case 5:
        exerciseType = ExerciseType.paragraph;
        final paragraph = _contentService.contentSet.paragraphs[Random().nextInt(_contentService.contentSet.paragraphs.length)];
        content = paragraph.sentences.map((s) => s.words.map((w) => w.text).join(' ')).join('. ');
        break;
      case 6:
        exerciseType = ExerciseType.page;
        final page = _contentService.contentSet.pages[Random().nextInt(_contentService.contentSet.pages.length)];
        content = page.paragraphs.map((p) => p.sentences.map((s) => s.words.map((w) => w.text).join(' ')).join('. ')).join('\n\n');
        break;
      default:
        exerciseType = ExerciseType.word;
        content = _contentService.getRandomWordForLevel(1, _currentDifficulty).text;
    }

    debugPrint('[ExerciseManager] generateExercise: Contenuto generato: "$content"');
    int syllables = _countSyllables(content);
    int baseValue = syllables * 5;
    debugPrint('[ExerciseManager] generateExercise: Sillabe: $syllables, Valore base: $baseValue');

    _currentExercise = Exercise(
      content: content,
      type: exerciseType,
      difficulty: _currentDifficulty,
      crystalValue: baseValue,
      isBonus: _sessionResults.length >= 3 && _sessionResults.every((r) => r.isCorrect),
      metadata: {
        'sessionIndex': _currentSessionIndex,
        'difficulty': _currentDifficulty,
      },
    );
    debugPrint('[ExerciseManager] generateExercise: Esercizio generato: ${_currentExercise!.content}');
    notifyListeners();
    return _currentExercise!;
  }

  /// Processa il risultato di un esercizio
  Future<int> processExerciseResult(RecognitionResult result) async {
    debugPrint('[ExerciseManager] processExerciseResult: Inizio elaborazione del risultato.');
    debugPrint('[ExerciseManager] processExerciseResult: Risultato ricevuto: ${result.toJson()}');

    if (_currentExercise == null) {
      debugPrint('[ExerciseManager] processExerciseResult: Nessun esercizio corrente. Ritorno 0.');
      return 0;
    }

    int crystals = _calculateFinalCrystals(result);
    debugPrint('[ExerciseManager] processExerciseResult: Cristalli calcolati: $crystals');
    _sessionResults.add(result);
    _currentSessionIndex++;
    _totalCrystals += crystals;
    _sessionCrystals += crystals;
    debugPrint('[ExerciseManager] processExerciseResult: Aggiornati i totali - Sessione: $_sessionCrystals, Globale: $_totalCrystals');

    await _analyticsService.addResult(result);
    debugPrint('[ExerciseManager] processExerciseResult: Risultato inviato ad Analytics.');

    await _player.saveProgress();
    debugPrint('[ExerciseManager] processExerciseResult: Progresso del giocatore salvato.');

    if (isSessionComplete) {
      debugPrint('[ExerciseManager] processExerciseResult: Numero esercizi completati ($_currentSessionIndex) >= target ($exercisesPerSession). Completamento sessione.');
      await _completeSession();
    }

    _updateDifficulty();
    debugPrint('[ExerciseManager] processExerciseResult: Difficoltà aggiornata. Cristalli ottenuti in questo esercizio: $crystals');
    notifyListeners();
    return crystals;
  }

  /// Pulisce le risorse alla fine della sessione
  Future<void> cleanupSession() async {
    debugPrint('[ExerciseManager] cleanupSession: Inizio cleanup della sessione.');
    await _audioService.dispose();
    _isSessionActive = false;
    debugPrint('[ExerciseManager] cleanupSession: Cleanup completato.');
    notifyListeners();
  }

  /// Calcola il numero di sillabe in una parola italiana
  int _countSyllables(String word) {
    final vowels = RegExp('[aeiouAEIOU]');
    final diphthongs = RegExp('(ai|au|ei|eu|oi|ou|ia|ie|io|iu|ua|ue|ui|uo)');
    int count = vowels.allMatches(word).length;
    count -= diphthongs.allMatches(word).length;
    return count > 0 ? count : 1;
  }

  /// Calcola i cristalli finali per un risultato
  int _calculateFinalCrystals(RecognitionResult result) {
    if (_currentExercise == null) return 0;

    int syllables = _countSyllables(_currentExercise!.content);
    debugPrint('[ExerciseManager] _calculateFinalCrystals: Sillabe nel contenuto: $syllables');

    // Se l'accuratezza è inferiore al 45%, esercizio fallito: 0 cristalli
    if (result.similarity < 0.45) {
      debugPrint('[ExerciseManager] _calculateFinalCrystals: Accuracy (${result.similarity}) sotto il 45%: esercizio fallito, 0 cristalli.');
      return 0;
    }

    // Calcola i cristalli: (1 * lunghezza_esercizio * bonus NG+ * bonusLivello)
    int baseCrystals = syllables; // 1 cristallo per sillaba
    int finalCrystals = _player.currentLevel * baseCrystals;
    finalCrystals = (finalCrystals * (1.0 + (_player.newGamePlusCount * 0.5))).round();
    debugPrint('[ExerciseManager] _calculateFinalCrystals: Calcolati $finalCrystals cristalli (base: $baseCrystals, livello: ${_player.currentLevel}, NG+: ${_player.newGamePlusCount}).');
    return finalCrystals;
  }

  /// Aggiorna la difficoltà in base alle performance
  void _updateDifficulty() {
    if (_sessionResults.length < 3) {
      debugPrint('[ExerciseManager] _updateDifficulty: Risultati insufficienti (${_sessionResults.length}), nessun aggiornamento.');
      return;
    }

    final recentResults = _sessionResults.reversed.take(3).toList();
    final averageAccuracy = recentResults
        .map((r) => r.similarity)
        .reduce((a, b) => a + b) / recentResults.length;
    debugPrint('[ExerciseManager] _updateDifficulty: Media accuracy degli ultimi 3 esercizi: $averageAccuracy');

    if (averageAccuracy >= hardDifficultyThreshold && _currentDifficulty != Difficulty.hard) {
      _currentDifficulty = Difficulty.hard;
      debugPrint('[ExerciseManager] _updateDifficulty: Difficoltà aggiornata a HARD');
    } else if (averageAccuracy >= mediumDifficultyThreshold && _currentDifficulty == Difficulty.easy) {
      _currentDifficulty = Difficulty.medium;
      debugPrint('[ExerciseManager] _updateDifficulty: Difficoltà aggiornata a MEDIUM');
    } else if (averageAccuracy < requiredAccuracy && _currentDifficulty != Difficulty.easy) {
      _currentDifficulty = Difficulty.easy;
      debugPrint('[ExerciseManager] _updateDifficulty: Difficoltà aggiornata a EASY');
    }
  }

  /// Completa la sessione corrente
  Future<void> _completeSession() async {
    debugPrint('[ExerciseManager] _completeSession: Completamento sessione in corso.');
    if (_sessionResults.isNotEmpty) {
      double sessionAccuracy = _sessionResults
          .map((r) => r.similarity)
          .reduce((a, b) => a + b) / _sessionResults.length;
      debugPrint('[ExerciseManager] _completeSession: Accuratezza della sessione: $sessionAccuracy');

      _sessionAccuracies.add(sessionAccuracy);
      if (_sessionAccuracies.length > 30) {
        _sessionAccuracies.removeAt(0);
      }

      _overallAccuracy = _sessionAccuracies.isEmpty
          ? 0.0
          : _sessionAccuracies.reduce((a, b) => a + b) / _sessionAccuracies.length;
      debugPrint('[ExerciseManager] _completeSession: Accuratezza complessiva della sessione: $_overallAccuracy');

      await _player.saveProgress();
      debugPrint('[ExerciseManager] _completeSession: Progresso del giocatore salvato.');
    }

    _isSessionActive = false;
    debugPrint('[ExerciseManager] _completeSession: Sessione completata.');
    notifyListeners();
  }

  // Getters pubblici
  Exercise? get currentExercise => _currentExercise;
  Difficulty get currentDifficulty => _currentDifficulty;
  int get sessionProgress => _currentSessionIndex;
  bool get isSessionComplete => _currentSessionIndex >= exercisesPerSession;
  List<RecognitionResult> get sessionResults => List.unmodifiable(_sessionResults);
  double get overallAccuracy => _overallAccuracy;
  int get totalCrystals => _totalCrystals;
  int get sessionCrystals => _sessionCrystals;
  List<double> get sessionAccuracies => List.unmodifiable(_sessionAccuracies);
  bool get isSessionActive => _isSessionActive;
  bool get isInitialized => _isInitialized;
}

/// Classe che rappresenta un singolo esercizio
class Exercise {
  final String content;
  final ExerciseType type;
  final Difficulty difficulty;
  final int crystalValue;
  final bool isBonus;
  final Map<String, dynamic>? metadata;

  Exercise({
    required this.content,
    required this.type,
    required this.difficulty,
    required this.crystalValue,
    this.isBonus = false,
    this.metadata,
  });
}
