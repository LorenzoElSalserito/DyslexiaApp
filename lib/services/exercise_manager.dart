// lib/services/exercise_manager.dart

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/recognition_result.dart';
import '../services/content_service.dart';
import '../services/learning_analytics_service.dart';
import '../models/enums.dart';
import '../services/speech_recognition_service.dart';
import '../services/audio_service.dart';

/// Gestisce la creazione, esecuzione e valutazione degli esercizi di lettura.
/// Coordina i vari servizi e mantiene lo stato della sessione di esercizi.
class ExerciseManager extends ChangeNotifier {
  // Componenti base
  late Player _player;
  final ContentService _contentService;
  final LearningAnalyticsService _analyticsService;
  final SpeechRecognitionService _speechService;
  final Random _random = Random();

  // Costanti di configurazione
  static const int maxLevel = 6;
  static const int exercisesPerSession = 5;
  static const double requiredAccuracy = 0.75;
  static const double mediumDifficultyThreshold = 0.85;
  static const double hardDifficultyThreshold = 0.95;

  // Stato dell'esercizio
  Exercise? _currentExercise;
  List<String> _usedContent = [];
  List<RecognitionResult> _sessionResults = [];
  int _currentSessionIndex = 0;
  Difficulty _currentDifficulty = Difficulty.easy;
  bool _isSessionActive = false;
  bool _isInitialized = false;
  BuildContext? _context;

  // Metriche della sessione
  List<double> _sessionAccuracies = [];
  double _overallAccuracy = 0.0;
  int _totalCrystals = 0;
  int _sessionCrystals = 0;

  // Gestione mutex per operazioni concorrenti
  bool _operationInProgress = false;
  final List<Completer<void>> _operationQueue = [];

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
  SpeechRecognitionService get speechService => _speechService;
  AudioService get audioService => _speechService.audioService;

  ExerciseManager({
    required Player player,
    required ContentService contentService,
    required LearningAnalyticsService analyticsService,
  })  : _contentService = contentService,
        _analyticsService = analyticsService,
        _speechService = SpeechRecognitionService() {
    debugPrint('[ExerciseManager] Costruttore: Inizializzo ExerciseManager con player: ${player.toJson()}');
    _player = player;
  }

  /// Imposta il BuildContext per l'inizializzazione
  void setContext(BuildContext context) {
    _context = context;
    if (!_isInitialized) {
      _initialize();
    }
  }

  void updatePlayer(Player newPlayer) async {
    await _executeExclusive(() async {
      debugPrint('[ExerciseManager] updatePlayer: Aggiornamento player...');
      _player = newPlayer;
      await _player.loadProgress();
      debugPrint('[ExerciseManager] updatePlayer: Nuovo player = ${_player.toJson()}');
      notifyListeners();
    });
  }

  Future<void> _initialize() async {
    if (_context == null) {
      throw Exception('BuildContext non impostato. Chiamare setContext prima dell\'inizializzazione.');
    }

    debugPrint('[ExerciseManager] _initialize: Inizializzazione avviata.');
    try {
      // Inizializza il servizio di riconoscimento vocale
      await _speechService.initialize(_context!);

      debugPrint('[ExerciseManager] _initialize: Carico il progresso del giocatore...');
      await _player.loadProgress();

      // Configura gli ascoltatori per gli eventi di riconoscimento
      _setupRecognitionListeners();

      _isInitialized = true;
      debugPrint('[ExerciseManager] _initialize: Inizializzazione completata.');
      notifyListeners();
    } catch (e) {
      debugPrint('[ExerciseManager] _initialize: ERRORE durante l\'inizializzazione: $e');
      rethrow;
    }
  }

  void _setupRecognitionListeners() {
    // Ascolta i risultati del riconoscimento
    _speechService.resultStream.listen((result) async {
      await processExerciseResult(result);
    });

    // Ascolta gli errori
    _speechService.errorStream.listen((error) {
      debugPrint('[ExerciseManager] Errore dal servizio di riconoscimento: $error');
    });

    // Ascolta i cambiamenti di stato
    _speechService.stateStream.listen((state) {
      debugPrint('[ExerciseManager] Cambio stato riconoscimento: $state');
    });
  }

  Future<void> startNewSession() async {
    if (_context == null) {
      throw Exception('BuildContext non impostato. Chiamare setContext prima di startNewSession.');
    }

    await _executeExclusive(() async {
      debugPrint('[ExerciseManager] startNewSession: Avvio nuova sessione.');
      if (!_isInitialized) {
        debugPrint('[ExerciseManager] startNewSession: Manager non inizializzato. Chiamo _initialize()...');
        await _initialize();
      }

      debugPrint('[ExerciseManager] startNewSession: Pulizia sessione precedente.');
      await cleanupSession();

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
    });
  }

  Future<Exercise> generateExercise() async {
    return await _executeExclusive<Exercise>(() async {
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
          final sentence = _contentService.contentSet.sentences[_random.nextInt(_contentService.contentSet.sentences.length)];
          content = sentence.words.map((w) => w.text).join(' ');
          break;
        case 5:
          exerciseType = ExerciseType.paragraph;
          final paragraph = _contentService.contentSet.paragraphs[_random.nextInt(_contentService.contentSet.paragraphs.length)];
          content = paragraph.sentences.map((s) => s.words.map((w) => w.text).join(' ')).join('. ');
          break;
        case 6:
          exerciseType = ExerciseType.page;
          final page = _contentService.contentSet.pages[_random.nextInt(_contentService.contentSet.pages.length)];
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

      // Avvia il riconoscimento per il nuovo esercizio
      await _speechService.startRecognition(content);

      debugPrint('[ExerciseManager] generateExercise: Esercizio generato: ${_currentExercise!.content}');
      notifyListeners();
      return _currentExercise!;
    });
  }

  Future<int> processExerciseResult(RecognitionResult result) async {
    return await _executeExclusive<int>(() async {
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

      _player.addCrystals(crystals);
      await _analyticsService.addResult(result);
      await _player.saveProgress();

      debugPrint('[ExerciseManager] processExerciseResult: Aggiornati i totali - Sessione: $_sessionCrystals, Globale: $_totalCrystals');

      if (isSessionComplete) {
        debugPrint('[ExerciseManager] processExerciseResult: Sessione completata.');
        await _completeSession();
      }

      _updateDifficulty();
      debugPrint('[ExerciseManager] processExerciseResult: Difficoltà aggiornata. Cristalli ottenuti: $crystals');
      notifyListeners();
      return crystals;
    });
  }

  Future<void> cleanupSession() async {
    await _executeExclusive(() async {
      debugPrint('[ExerciseManager] cleanupSession: Pulizia sessione.');
      await _speechService.reset();
      _isSessionActive = false;
      debugPrint('[ExerciseManager] cleanupSession: Cleanup completato.');
      notifyListeners();
    });
  }

  int _countSyllables(String text) {
    final vowels = RegExp('[aeiouAEIOU]');
    final diphthongs = RegExp('(ai|au|ei|eu|oi|ou|ia|ie|io|iu|ua|ue|ui|uo)');
    int count = vowels.allMatches(text).length;
    count -= diphthongs.allMatches(text).length;
    return count > 0 ? count : 1;
  }

  int _calculateFinalCrystals(RecognitionResult result) {
    if (_currentExercise == null) return 0;

    int syllables = _countSyllables(_currentExercise!.content);
    debugPrint('[ExerciseManager] _calculateFinalCrystals: Sillabe nel contenuto: $syllables');

    if (result.similarity < 0.45) {
      debugPrint('[ExerciseManager] _calculateFinalCrystals: Accuracy (${result.similarity}) sotto il 45%: esercizio fallito, 0 cristalli.');
      return 0;
    }

    // Base crystals per sillaba
    int baseCrystals = syllables;

    // Moltiplica per il livello
    int levelMultiplier = _player.currentLevel;

    // Bonus New Game+
    double ngPlusBonus = 1.0 + (_player.newGamePlusCount * 0.5);

    // Bonus difficoltà
    double difficultyBonus = switch(_currentDifficulty) {
      Difficulty.easy => 1.0,
      Difficulty.medium => 1.3,
      Difficulty.hard => 1.6,
    };

    // Bonus accuratezza
    double accuracyBonus = 1.0;
    if (result.similarity >= 0.95) accuracyBonus = 1.5;
    else if (result.similarity >= 0.85) accuracyBonus = 1.3;
    else if (result.similarity >= 0.75) accuracyBonus = 1.1;

    // Calcola il totale
    int finalCrystals = (baseCrystals *
        levelMultiplier *
        ngPlusBonus *
        difficultyBonus *
        accuracyBonus).round();

// Continua da debugPrint precedente
    debugPrint('''[ExerciseManager] _calculateFinalCrystals: 
      Base: $baseCrystals,
      Livello: $levelMultiplier,
      Bonus NG+: $ngPlusBonus,
      Bonus Difficoltà: $difficultyBonus,
      Bonus Accuratezza: $accuracyBonus,
      Totale: $finalCrystals''');

    return finalCrystals;
  }

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
      debugPrint('[ExerciseManager] _completeSession: Accuratezza complessiva: $_overallAccuracy');

      final updatedGameData = {
        ..._player.gameData,
        'averageAccuracy': _overallAccuracy,
      };
      _player.updateGameData(updatedGameData);
      await _player.saveProgress();
      debugPrint('[ExerciseManager] _completeSession: Progresso del giocatore salvato.');
    }

    _isSessionActive = false;
    debugPrint('[ExerciseManager] _completeSession: Sessione completata.');
    notifyListeners();
  }

  /// Esegue un'operazione in modo esclusivo utilizzando una coda di operazioni
  Future<T> _executeExclusive<T>(Future<T> Function() operation) async {
    final completer = Completer<T>();
    _operationQueue.add(completer as Completer<void>);

    if (_operationQueue.first == completer) {
      try {
        _operationInProgress = true;
        final result = await operation();
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      } finally {
        _operationInProgress = false;
        _operationQueue.removeAt(0);
        if (_operationQueue.isNotEmpty) {
          _executeExclusive(() => _operationQueue.first.future as Future<T>);
        }
      }
    }

    return completer.future;
  }
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