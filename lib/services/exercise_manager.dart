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
    _player = newPlayer;  // Aggiorna l'istanza del player
    await _player.loadProgress(); // Carica il progresso dal file
    debugPrint('[ExerciseManager] updatePlayer: nuovo player = ${_player.toJson()}');
    notifyListeners();
  }

  /// Inizializza il manager
  Future<void> _initialize() async {
    try {
      debugPrint('[ExerciseManager] _initialize: Inizializzo l\'audioService...');
      await _audioService.initialize();
      await _player.loadProgress(); // Carica il progresso dal file
      _isInitialized = true;
      debugPrint('[ExerciseManager] _initialize: Completato.');
      notifyListeners();
    } catch (e) {
      debugPrint('[ExerciseManager] Errore nell\'inizializzazione: $e');
      rethrow;
    }
  }

  /// Inizia una nuova sessione di esercizi
  Future<void> startNewSession() async {
    debugPrint('[ExerciseManager] startNewSession: Avvio nuova sessione.');
    if (!_isInitialized) {
      await _initialize();
    }

    await cleanupSession();
    await _audioService.initialize();

    _sessionResults.clear();
    _currentSessionIndex = 0;
    _sessionCrystals = 0;
    _isSessionActive = true;
    _usedContent.clear();

    _analyticsService.startSession();
    debugPrint('[ExerciseManager] startNewSession: Sessione avviata.');
    notifyListeners();
  }

  /// Genera un nuovo esercizio
  Future<Exercise> generateExercise() async {
    debugPrint('[ExerciseManager] generateExercise: Generazione esercizio...');
    if (!_isInitialized) {
      throw Exception('ExerciseManager non inizializzato');
    }
    if (!_isSessionActive) {
      throw Exception('Sessione non attiva. Chiamare startNewSession() prima.');
    }

    // Ottiene una parola casuale dal content service
    String content = _contentService.getRandomWordForLevel(1, _currentDifficulty).text;
    int syllables = _countSyllables(content);
    int baseValue = syllables * 5;

    _currentExercise = Exercise(
      content: content,
      type: _getExerciseTypeForLevel(_player.currentLevel),
      difficulty: _currentDifficulty,
      crystalValue: baseValue,
      isBonus: _sessionResults.length >= 3 && _sessionResults.every((r) => r.isCorrect),
      metadata: {
        'sessionIndex': _currentSessionIndex,
        'difficulty': _currentDifficulty,
      },
    );
    debugPrint('[ExerciseManager] Esercizio generato: ${_currentExercise!.content}');
    notifyListeners();
    return _currentExercise!;
  }

  /// Processa il risultato di un esercizio
  Future<int> processExerciseResult(RecognitionResult result) async {
    debugPrint('[ExerciseManager] processExerciseResult: Risultato=${result.toJson()}');
    if (_currentExercise == null) return 0;

    int crystals = _calculateFinalCrystals(result);
    _sessionResults.add(result);
    _currentSessionIndex++;
    _totalCrystals += crystals;
    _sessionCrystals += crystals;
    _player.addCrystals(crystals);

    await _analyticsService.addResult(result);
    await _player.saveProgress();  // Salva il progresso dopo ogni esercizio

    if (isSessionComplete) {
      await _completeSession();
    }

    _updateDifficulty();
    debugPrint('[ExerciseManager] processExerciseResult: cristalli ottenuti = $crystals');
    notifyListeners();
    return crystals;
  }

  /// Pulisce le risorse alla fine della sessione
  Future<void> cleanupSession() async {
    debugPrint('[ExerciseManager] cleanupSession: Pulizia sessione.');
    await _audioService.dispose();
    _isSessionActive = false;
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

  /// Ottiene il tipo di esercizio appropriato per il livello
  ExerciseType _getExerciseTypeForLevel(int level) {
    return switch (level) {
      1 => ExerciseType.word,
      2 => ExerciseType.sentence,
      3 => ExerciseType.paragraph,
      4 => ExerciseType.page,
      _ => ExerciseType.word,
    };
  }

  /// Calcola i cristalli finali per un risultato
  int _calculateFinalCrystals(RecognitionResult result) {
    if (_currentExercise == null) return 0;

    double multiplier = 1.0;

    if (result.similarity >= hardDifficultyThreshold) {
      multiplier += 0.5;
    } else if (result.similarity >= mediumDifficultyThreshold) {
      multiplier += 0.3;
    } else if (result.similarity >= requiredAccuracy) {
      multiplier += 0.1;
    }

    if (_sessionResults.length >= 3 && _sessionResults.every((r) => r.isCorrect)) {
      multiplier += 0.5;
    }

    switch (_currentDifficulty) {
      case Difficulty.easy:
        multiplier *= 1.0;
      case Difficulty.medium:
        multiplier *= 1.5;
      case Difficulty.hard:
        multiplier *= 2.0;
    }

    multiplier *= (1.0 + (_player.newGamePlusCount * 0.5));

    int finalCrystals = (_currentExercise!.crystalValue * multiplier).round();
    debugPrint('[ExerciseManager] _calculateFinalCrystals: multiplier=$multiplier, finalCrystals=$finalCrystals');
    return finalCrystals;
  }

  /// Aggiorna la difficoltà in base alle performance
  void _updateDifficulty() {
    if (_sessionResults.length < 3) return;

    final recentResults = _sessionResults.reversed.take(3).toList();
    final averageAccuracy = recentResults
        .map((r) => r.similarity)
        .reduce((a, b) => a + b) / recentResults.length;

    if (averageAccuracy >= hardDifficultyThreshold && _currentDifficulty != Difficulty.hard) {
      _currentDifficulty = Difficulty.hard;
      debugPrint('[ExerciseManager] Difficoltà aggiornata a HARD');
    } else if (averageAccuracy >= mediumDifficultyThreshold && _currentDifficulty == Difficulty.easy) {
      _currentDifficulty = Difficulty.medium;
      debugPrint('[ExerciseManager] Difficoltà aggiornata a MEDIUM');
    } else if (averageAccuracy < requiredAccuracy && _currentDifficulty != Difficulty.easy) {
      _currentDifficulty = Difficulty.easy;
      debugPrint('[ExerciseManager] Difficoltà aggiornata a EASY');
    }
  }

  /// Completa la sessione corrente
  Future<void> _completeSession() async {
    debugPrint('[ExerciseManager] _completeSession: Completamento sessione');
    if (_sessionResults.isNotEmpty) {
      double sessionAccuracy = _sessionResults
          .map((r) => r.similarity)
          .reduce((a, b) => a + b) / _sessionResults.length;
      debugPrint('[ExerciseManager] Session accuracy: $sessionAccuracy');

      _sessionAccuracies.add(sessionAccuracy);
      if (_sessionAccuracies.length > 30) {
        _sessionAccuracies.removeAt(0);
      }

      _overallAccuracy = _sessionAccuracies.isEmpty
          ? 0.0
          : _sessionAccuracies.reduce((a, b) => a + b) / _sessionAccuracies.length;
      debugPrint('[ExerciseManager] Overall session accuracy: $_overallAccuracy');

      await _player.saveProgress(); // Salva il progresso alla fine della sessione
    }

    _isSessionActive = false;
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