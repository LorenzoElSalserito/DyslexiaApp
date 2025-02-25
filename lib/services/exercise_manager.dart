//lib/services/exercise_manager.dart

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
import '../services/ui_error_logger.dart';

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

/// Gestisce la creazione, esecuzione e valutazione degli esercizi di lettura.
/// Coordina i vari servizi e mantiene lo stato della sessione di esercizi.
class ExerciseManager extends ChangeNotifier {
  // Componenti base
  late Player _player;
  final ContentService _contentService;
  final LearningAnalyticsService _analyticsService;
  final SpeechRecognitionService _speechService;
  final Random _random = Random();
  final UIErrorLogger _logger = UIErrorLogger();

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

  // Timeout timer
  Timer? _operationTimeoutTimer;

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
    _logger.logInfo('[ExerciseManager] Costruttore: Inizializzo ExerciseManager con player: ${player.toJson()}');
    _player = player;
  }

  /// Imposta il BuildContext per l'inizializzazione
  void setContext(BuildContext context) {
    _context = context;
    _logger.logInfo('[ExerciseManager] Context impostato');
    if (!_isInitialized) {
      _initialize();
    }
  }

  void updatePlayer(Player newPlayer) async {
    await _executeExclusive(() async {
      _logger.logInfo('[ExerciseManager] updatePlayer: Aggiornamento player...');
      _player = newPlayer;
      await _player.loadProgress();
      _logger.logInfo('[ExerciseManager] updatePlayer: Nuovo player = ${_player.toJson()}');
      notifyListeners();
    });
  }

  Future<void> _initialize() async {
    if (_context == null) {
      final error = Exception('BuildContext non impostato. Chiamare setContext prima dell\'inizializzazione.');
      _logger.logError('[ExerciseManager] Errore initialize: BuildContext non impostato', error);
      throw error;
    }

    _logger.logInfo('[ExerciseManager] _initialize: Inizializzazione avviata.');
    try {
      // Inizializza il servizio di riconoscimento vocale con timeout
      await _speechService.initialize(_context!)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        _logger.logError('[ExerciseManager] _initialize: Timeout durante l\'inizializzazione del riconoscimento vocale',
            Exception('Timeout nell\'inizializzazione del riconoscimento vocale'));
        throw Exception('Timeout nell\'inizializzazione del riconoscimento vocale');
      });

      _logger.logInfo('[ExerciseManager] _initialize: Carico il progresso del giocatore...');
      await _player.loadProgress();

      // Configura gli ascoltatori per gli eventi di riconoscimento
      _setupRecognitionListeners();

      _isInitialized = true;
      _logger.logInfo('[ExerciseManager] _initialize: Inizializzazione completata.');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.logError('[ExerciseManager] _initialize: ERRORE durante l\'inizializzazione', e, stackTrace);
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
      _logger.logWarning(error);
    });

    // Ascolta i cambiamenti di stato
    _speechService.stateStream.listen((state) {
      _logger.logInfo('[ExerciseManager] Cambio stato riconoscimento: $state');
    });
  }

  Future<void> startNewSession() async {
    if (_context == null) {
      final error = Exception('BuildContext non impostato. Chiamare setContext prima di startNewSession.');
      _logger.logError('[ExerciseManager] startNewSession: BuildContext non impostato', error);
      throw error;
    }

    await _executeExclusive(() async {
      _logger.logInfo('[ExerciseManager] startNewSession: Avvio nuova sessione.');
      if (!_isInitialized) {
        _logger.logInfo('[ExerciseManager] startNewSession: Manager non inizializzato. Chiamo _initialize()...');
        await _initialize();
      }

      _logger.logInfo('[ExerciseManager] startNewSession: Pulizia sessione precedente.');
      // Implementiamo direttamente il reset dello stato senza chiamare altre funzioni _executeExclusive

      try {
        // Reset diretto dello stato della sessione
        await _speechService.reset();
        _isSessionActive = true;
        _sessionResults.clear();
        _currentSessionIndex = 0;
        _sessionCrystals = 0;
        _totalCrystals = 0;
        _usedContent.clear();

        _logger.logInfo('[ExerciseManager] startNewSession: Avvio sessione analytics.');
        _analyticsService.startSession();
        _logger.logInfo('[ExerciseManager] startNewSession: Nuova sessione avviata.');
        notifyListeners();
      } catch (e) {
        _logger.logError('[ExerciseManager] startNewSession: Errore durante la pulizia', e);
        throw Exception('Errore nella preparazione della sessione: $e');
      }
    }, timeoutSeconds: 10); // Aggiunto timeout di 10 secondi
  }

  Future<Exercise> generateExercise() async {
    return await _executeExclusive<Exercise>(() async {
      _logger.logInfo('[ExerciseManager] generateExercise: Inizio generazione esercizio.');
      if (!_isInitialized) {
        final error = Exception('ExerciseManager non inizializzato');
        _logger.logError('[ExerciseManager] generateExercise: Manager non inizializzato', error);
        throw error;
      }
      if (!_isSessionActive) {
        final error = Exception('Sessione non attiva. Chiamare startNewSession() prima.');
        _logger.logError('[ExerciseManager] generateExercise: Sessione non attiva', error);
        throw error;
      }

      String content;
      ExerciseType exerciseType;
      _logger.logInfo('[ExerciseManager] generateExercise: Livello corrente del giocatore: ${_player.currentLevel}');

      // Aggiunta di un timeout per evitare attese infinite
      content = await Future.value(_generateContentBasedOnLevel(_player.currentLevel, _currentDifficulty))
          .timeout(const Duration(seconds: 5), onTimeout: () {
        _logger.logWarning('[ExerciseManager] generateExercise: Timeout nella generazione del contenuto. Uso contenuto di fallback.');
        return "casa";  // Parola di fallback in caso di timeout
      });

      exerciseType = _getExerciseTypeBasedOnLevel(_player.currentLevel);

      _logger.logInfo('[ExerciseManager] generateExercise: Contenuto generato: "$content"');
      int syllables = _countSyllables(content);
      int baseValue = syllables * 5;
      _logger.logInfo('[ExerciseManager] generateExercise: Sillabe: $syllables, Valore base: $baseValue');

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

      _logger.logInfo('[ExerciseManager] generateExercise: Esercizio generato: ${_currentExercise!.content}');
      notifyListeners();
      return _currentExercise!;
    }, timeoutSeconds: 5);
  }

  // Metodo helper per generare contenuto in base al livello
  String _generateContentBasedOnLevel(int level, Difficulty difficulty) {
    try {
      switch (level) {
        case 1:
          return _contentService.getRandomWordForLevel(1, difficulty).text;
        case 2:
          return _contentService.getRandomWordForLevel(2, difficulty).text;
        case 3:
          return _contentService.getRandomWordForLevel(3, difficulty).text;
        case 4:
          final sentence = _contentService.contentSet.getRandomSentence();
          return sentence.words.map((w) => w.text).join(' ');
        case 5:
          final paragraph = _contentService.contentSet.getRandomParagraph();
          return paragraph.sentences.map((s) => s.words.map((w) => w.text).join(' ')).join('. ');
        case 6:
          final page = _contentService.contentSet.getRandomPage();
          return page.paragraphs.map((p) => p.sentences.map((s) => s.words.map((w) => w.text).join(' ')).join('. ')).join('\n\n');
        default:
          return "esercizio"; // Parola di fallback
      }
    } catch (e) {
      _logger.logError('[ExerciseManager] _generateContentBasedOnLevel: Errore', e);
      return "errore"; // Parola di fallback in caso di errore
    }
  }

  // Metodo helper per determinare il tipo di esercizio in base al livello
  ExerciseType _getExerciseTypeBasedOnLevel(int level) {
    switch (level) {
      case 1:
      case 2:
      case 3:
        return ExerciseType.word;
      case 4:
        return ExerciseType.sentence;
      case 5:
        return ExerciseType.paragraph;
      case 6:
        return ExerciseType.page;
      default:
        return ExerciseType.word;
    }
  }

  Future<int> processExerciseResult(RecognitionResult result) async {
    return await _executeExclusive<int>(() async {
      _logger.logInfo('[ExerciseManager] processExerciseResult: Inizio elaborazione del risultato.');
      _logger.logInfo('[ExerciseManager] processExerciseResult: Risultato ricevuto: ${result.toJson()}');

      if (_currentExercise == null) {
        _logger.logWarning('[ExerciseManager] processExerciseResult: Nessun esercizio corrente. Ritorno 0.');
        return 0;
      }

      int crystals = _calculateFinalCrystals(result);
      _logger.logInfo('[ExerciseManager] processExerciseResult: Cristalli calcolati: $crystals');

      _sessionResults.add(result);
      _currentSessionIndex++;
      _totalCrystals += crystals;
      _sessionCrystals += crystals;

      _player.addCrystals(crystals);
      await _analyticsService.addResult(result);
      await _player.saveProgress();

      _logger.logInfo('[ExerciseManager] processExerciseResult: Aggiornati i totali - Sessione: $_sessionCrystals, Globale: $_totalCrystals');

      if (isSessionComplete) {
        _logger.logInfo('[ExerciseManager] processExerciseResult: Sessione completata.');
        await _completeSession();
      }

      _updateDifficulty();
      _logger.logInfo('[ExerciseManager] processExerciseResult: Difficoltà aggiornata. Cristalli ottenuti: $crystals');
      notifyListeners();
      return crystals;
    }, timeoutSeconds: 5);
  }

  Future<void> cleanupSession() async {
    // Questo metodo viene chiamato da startNewSession che già usa _executeExclusive
    _logger.logInfo('[ExerciseManager] cleanupSession: Pulizia sessione.');
    try {
      await _speechService.reset();
      _isSessionActive = false;
      _logger.logInfo('[ExerciseManager] cleanupSession: Cleanup completato.');
      notifyListeners();
    } catch (e) {
      _logger.logError('[ExerciseManager] cleanupSession: Errore durante la pulizia', e);
      throw Exception('Errore durante la pulizia: $e');
    }
  }

  // Questa versione è sicura da chiamare direttamente (non in _executeExclusive)
  Future<void> safeCleanupSession() async {
    return _executeExclusive(() async {
      await cleanupSession();
    }, timeoutSeconds: 5);
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
    _logger.logInfo('[ExerciseManager] _calculateFinalCrystals: Sillabe nel contenuto: $syllables');

    if (result.similarity < 0.45) {
      _logger.logInfo('[ExerciseManager] _calculateFinalCrystals: Accuracy (${result.similarity}) sotto il 45%: esercizio fallito, 0 cristalli.');
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

    _logger.logInfo('''[ExerciseManager] _calculateFinalCrystals: 
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
      _logger.logInfo('[ExerciseManager] _updateDifficulty: Risultati insufficienti (${_sessionResults.length}), nessun aggiornamento.');
      return;
    }

    final recentResults = _sessionResults.reversed.take(3).toList();
    final averageAccuracy = recentResults
        .map((r) => r.similarity)
        .reduce((a, b) => a + b) / recentResults.length;
    _logger.logInfo('[ExerciseManager] _updateDifficulty: Media accuracy degli ultimi 3 esercizi: $averageAccuracy');

    if (averageAccuracy >= hardDifficultyThreshold && _currentDifficulty != Difficulty.hard) {
      _currentDifficulty = Difficulty.hard;
      _logger.logInfo('[ExerciseManager] _updateDifficulty: Difficoltà aggiornata a HARD');
    } else if (averageAccuracy >= mediumDifficultyThreshold && _currentDifficulty == Difficulty.easy) {
      _currentDifficulty = Difficulty.medium;
      _logger.logInfo('[ExerciseManager] _updateDifficulty: Difficoltà aggiornata a MEDIUM');
    } else if (averageAccuracy < requiredAccuracy && _currentDifficulty != Difficulty.easy) {
      _currentDifficulty = Difficulty.easy;
      _logger.logInfo('[ExerciseManager] _updateDifficulty: Difficoltà aggiornata a EASY');
    }
  }

  Future<void> _completeSession() async {
    _logger.logInfo('[ExerciseManager] _completeSession: Completamento sessione in corso.');
    if (_sessionResults.isNotEmpty) {
      double sessionAccuracy = _sessionResults
          .map((r) => r.similarity)
          .reduce((a, b) => a + b) / _sessionResults.length;
      _logger.logInfo('[ExerciseManager] _completeSession: Accuratezza della sessione: $sessionAccuracy');

      _sessionAccuracies.add(sessionAccuracy);
      if (_sessionAccuracies.length > 30) {
        _sessionAccuracies.removeAt(0);
      }

      _overallAccuracy = _sessionAccuracies.isEmpty
          ? 0.0
          : _sessionAccuracies.reduce((a, b) => a + b) / _sessionAccuracies.length;
      _logger.logInfo('[ExerciseManager] _completeSession: Accuratezza complessiva: $_overallAccuracy');

      final updatedGameData = {
        ..._player.gameData,
        'averageAccuracy': _overallAccuracy,
      };
      _player.updateGameData(updatedGameData);
      await _player.saveProgress();
      _logger.logInfo('[ExerciseManager] _completeSession: Progresso del giocatore salvato.');
    }

    _isSessionActive = false;
    _logger.logInfo('[ExerciseManager] _completeSession: Sessione completata.');
    notifyListeners();
  }

  /// Esegue un'operazione in modo esclusivo utilizzando una coda di operazioni
  Future<T> _executeExclusive<T>(Future<T> Function() operation, {int timeoutSeconds = 30}) async {
    final completer = Completer<T>();
    _operationQueue.add(completer as Completer<void>);

    if (_operationQueue.first == completer) {
      try {
        _operationInProgress = true;

        // Setup del timer di timeout
        _operationTimeoutTimer?.cancel();
        _operationTimeoutTimer = Timer(Duration(seconds: timeoutSeconds), () {
          if (!completer.isCompleted) {
            _logger.logError('[ExerciseManager] Timeout nell\'operazione esclusiva',
                Exception('Operazione esclusiva non completata in $timeoutSeconds secondi'));
            completer.completeError(
                Exception('Operazione non completata in tempo (timeout: ${timeoutSeconds}s)'));
          }
        });

        final result = await operation();

        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e, stackTrace) {
        _logger.logError('[ExerciseManager] Errore in operazione esclusiva', e, stackTrace);
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      } finally {
        _operationTimeoutTimer?.cancel();
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