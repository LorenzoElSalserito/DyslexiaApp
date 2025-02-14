// lib/services/game_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/level.dart';
import '../models/enums.dart';
import '../services/content_service.dart';
import '../services/exercise_manager.dart';
import '../models/recognition_result.dart';
import '../services/game_notification_manager.dart';

class GameService extends ChangeNotifier {
  late Player _player;
  final ContentService contentService;
  final ExerciseManager exerciseManager;
  final GameNotificationManager _notificationManager;

  bool _isInitialized = false;

  // Costanti per il sistema di progressione
  static const int requiredDaysForLevelUp = 5;
  static const double requiredAccuracy = 0.75;
  static const int baseLoginBonus = 10;
  static const double bonusMultiplierIncrease = 0.5;

  // Stato del gioco e progressione
  final List<DateTime> _accuracyDates = [];
  final List<double> _accuracyHistory = [];
  int _currentStreak = 0;
  double _averageAccuracy = 0.0;
  int _consecutiveDaysOver75 = 0;
  bool _dailyBonusGiven = false;
  DateTime? _lastBonusDate;
  late SubLevel _currentSubLevel;

  GameService({
    required Player player,
    required this.contentService,
    required this.exerciseManager,
  })  : _notificationManager = GameNotificationManager(),
        _currentSubLevel = Level.allLevels[0].subLevels[0] {
    debugPrint('[GameService] Costruttore: Inizializzo i dati di gioco...');
    _player = player;
    // Avvio il caricamento dei dati di gioco; non utilizziamo il valore di ritorno perché la funzione è di tipo Future<void>
    _loadGameData();
  }

  Future<void> updatePlayer(Player newPlayer) async {
    _player = newPlayer;
    await _player.loadProgress();
    await _loadGameData();
    debugPrint('[GameService] updatePlayer: nuovo player = ${_player.toJson()}');
    notifyListeners();
  }

  Future<void> _loadGameData() async {
    debugPrint('[GameService] _loadGameData: Avvio caricamento dati di gioco...');
    try {
      final gameData = _player.gameData;
      debugPrint('[GameService] Dati letti dal profilo: $gameData');

      _averageAccuracy = (gameData['averageAccuracy'] is num)
          ? (gameData['averageAccuracy'] as num).toDouble()
          : 0.0;

      _dailyBonusGiven = gameData['dailyBonusGiven'] as bool? ?? false;

      final lastBonusDateStr = gameData['lastBonusDate'] as String?;
      if (lastBonusDateStr != null) {
        _lastBonusDate = DateTime.parse(lastBonusDateStr);
      }

      final accuracyDatesList = gameData['accuracyDates'] as List?;
      final accuracyHistoryList = gameData['accuracyHistory'] as List?;

      if (accuracyDatesList != null && accuracyHistoryList != null) {
        _accuracyDates
          ..clear()
          ..addAll(accuracyDatesList.map((date) {
            final d = DateTime.parse(date as String);
            debugPrint('[GameService] Data aggiunta: $d');
            return d;
          }));

        _accuracyHistory
          ..clear()
          ..addAll(accuracyHistoryList.map((acc) {
            final a = (acc as num).toDouble();
            debugPrint('[GameService] Accuratezza aggiunta: $a');
            return a;
          }));
      } else {
        debugPrint('[GameService] Nessun dato di accuratezza trovato.');
      }

      _currentStreak = gameData['currentStreak'] as int? ?? 0;
      debugPrint('[GameService] Current streak: $_currentStreak');

      _updateConsecutiveDays();
      _loadCurrentSubLevel();
      await _saveGameData();

      debugPrint('[GameService] _loadGameData completato.');
    } catch (e) {
      debugPrint('[GameService] Errore in _loadGameData: $e');
      _averageAccuracy = 0.0;
      _currentStreak = 0;
      _accuracyDates.clear();
      _accuracyHistory.clear();
      _dailyBonusGiven = false;
      _lastBonusDate = null;
      await _saveGameData();
    }
  }

  void _loadCurrentSubLevel() {
    final currentLevel = _player.currentLevel;
    final levelIndex = currentLevel - 1;
    if (levelIndex >= 0 && levelIndex < Level.allLevels.length) {
      final level = Level.allLevels[levelIndex];
      final subLevelIndex = (_player.currentStep ~/ 3).clamp(0, level.subLevels.length - 1);
      _currentSubLevel = level.subLevels[subLevelIndex];
      debugPrint('[GameService] Sottolivello corrente impostato: $_currentSubLevel');
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    debugPrint('[GameService] initialize: Inizializzazione in corso...');
    try {
      if (!contentService.isInitialized) {
        debugPrint('[GameService] Inizializzo contentService...');
        await contentService.initialize();
      }
      await _loadGameData();
      await _checkDailyLoginBonus();

      _isInitialized = true;
      debugPrint('[GameService] Inizializzazione completata.');
      notifyListeners();
    } catch (e) {
      debugPrint('[GameService] Errore nell\'inizializzazione: $e');
      rethrow;
    }
  }

  Future<void> _checkDailyLoginBonus() async {
    debugPrint('[GameService] _checkDailyLoginBonus: Verifica bonus giornaliero...');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_dailyBonusGiven) {
      if (_lastBonusDate != null && _isSameDay(_lastBonusDate!, today)) {
        debugPrint('[GameService] Bonus già assegnato per oggi.');
        return;
      }
    }

    final bonus = _calculateDailyBonus(_player.currentConsecutiveDays);
    debugPrint('[GameService] Bonus giornaliero calcolato: $bonus');
    _player.addCrystals(bonus);

    _dailyBonusGiven = true;
    _lastBonusDate = today;
    _player.gameData['lastBonusDate'] = today.toIso8601String();
    _player.gameData['dailyBonusGiven'] = true;

    await _player.saveProgress();
    debugPrint('[GameService] Bonus giornaliero assegnato.');
  }

  Future<void> showDailyLoginBonus(BuildContext context) async {
    if (_dailyBonusGiven && _lastBonusDate != null && _isSameDay(_lastBonusDate!, DateTime.now())) {
      return;
    }

    debugPrint('[GameService] showDailyLoginBonus: Mostro il popup bonus...');
    await _notificationManager.showDailyLoginBonus(
      context,
      _player.currentConsecutiveDays,
    );
  }

  int _calculateDailyBonus(int consecutiveDays) {
    final bonus = (baseLoginBonus + ((consecutiveDays - 1) * bonusMultiplierIncrease)).round();
    debugPrint('[GameService] _calculateDailyBonus: consecutiveDays=$consecutiveDays, bonus=$bonus');
    return bonus;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> processExerciseResult(RecognitionResult result) async {
    debugPrint('[GameService] processExerciseResult: Risultato=${result.toJson()}');
    if (result.isCorrect) {
      _currentStreak++;
    } else {
      _currentStreak = 0;
    }
    debugPrint('[GameService] Nuovo currentStreak: $_currentStreak');

    _updateAccuracy(result.similarity);
    _checkLevelProgression();
    await _saveGameData();

    notifyListeners();
  }

  void _updateAccuracy(double accuracy) {
    final now = DateTime.now();
    debugPrint('[GameService] _updateAccuracy: accuracy=$accuracy, now=$now');

    if (_accuracyHistory.isEmpty || !_isSameDay(now, _accuracyDates.last)) {
      _accuracyHistory.add(accuracy);
      _accuracyDates.add(now);
      debugPrint('[GameService] Valori aggiunti: _accuracyHistory=$_accuracyHistory');
    } else {
      final lastIndex = _accuracyHistory.length - 1;
      final currentAverage = _accuracyHistory[lastIndex];
      _accuracyHistory[lastIndex] = (currentAverage + accuracy) / 2;
      debugPrint('[GameService] Valore aggiornato: ${_accuracyHistory[lastIndex]}');
    }

    _averageAccuracy = _accuracyHistory.isEmpty
        ? 0.0
        : _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length;
    debugPrint('[GameService] Nuova media accuracy: $_averageAccuracy');

    _updateConsecutiveDays();
  }

  void _updateConsecutiveDays() {
    _consecutiveDaysOver75 = 0;
    for (int i = _accuracyHistory.length - 1; i >= 0; i--) {
      if (_accuracyHistory[i] >= requiredAccuracy) {
        _consecutiveDaysOver75++;
      } else {
        break;
      }
    }
    debugPrint('[GameService] ConsecutiveDaysOver75: $_consecutiveDaysOver75');
  }

  Future<void> _saveGameData() async {
    debugPrint('[GameService] _saveGameData: Salvataggio dati gioco...');
    final gameData = Map<String, dynamic>.from(_player.gameData);

    gameData['averageAccuracy'] = _averageAccuracy;
    gameData['accuracyDates'] =
        _accuracyDates.map((date) => date.toIso8601String()).toList();
    gameData['accuracyHistory'] = _accuracyHistory;
    gameData['currentStreak'] = _currentStreak;
    gameData['dailyBonusGiven'] = _dailyBonusGiven;
    if (_lastBonusDate != null) {
      gameData['lastBonusDate'] = _lastBonusDate!.toIso8601String();
    }

    debugPrint('[GameService] GameData aggiornato: $gameData');

    _player.updateGameData(gameData);
    await _player.saveProgress();
    debugPrint('[GameService] Dati di gioco salvati.');
  }

  void _checkLevelProgression() {
    debugPrint('[GameService] _checkLevelProgression: _consecutiveDaysOver75=$_consecutiveDaysOver75');
    if (_consecutiveDaysOver75 >= requiredDaysForLevelUp) {
      if (_player.currentLevel < 4 && canAdvanceLevel()) {
        debugPrint('[GameService] Il giocatore può salire di livello. Procedo con levelUp.');
        _player.levelUp();
        _consecutiveDaysOver75 = 0;
        _loadCurrentSubLevel();
        notifyListeners();
      }
    }
  }

  Future<void> resetDailyBonus() async {
    debugPrint('[GameService] resetDailyBonus: Reset bonus giornaliero...');
    _dailyBonusGiven = false;
    _player.gameData['dailyBonusGiven'] = false;
    await _player.saveProgress();
    debugPrint('[GameService] Bonus giornaliero resettato.');
  }

  SubLevel getCurrentSubLevel() {
    return _currentSubLevel;
  }

  double getLevelUpProgress() {
    final progress = _consecutiveDaysOver75 / requiredDaysForLevelUp;
    debugPrint('[GameService] getLevelUpProgress: $progress');
    return progress.clamp(0.0, 1.0);
  }

  bool canAdvanceLevel() {
    return _consecutiveDaysOver75 >= requiredDaysForLevelUp && _player.currentLevel < 4;
  }

  // Getters pubblici
  bool get isInitialized => _isInitialized;
  double getAverageAccuracy() => _averageAccuracy;
  int get streak => _currentStreak;
  int get currentStreak => _currentStreak;
  bool get hasActiveStreak => _currentStreak >= 3;
  int get consecutiveDaysOver75 => _consecutiveDaysOver75;
  List<DateTime> get accuracyDates => List.unmodifiable(_accuracyDates);
  List<double> get accuracyHistory => List.unmodifiable(_accuracyHistory);
  bool get isDailyBonusAvailable =>
      !_dailyBonusGiven ||
          (_lastBonusDate != null && !_isSameDay(_lastBonusDate!, DateTime.now()));

  Map<String, dynamic> exportGameData() {
    return {
      'accuracyDates': _accuracyDates.map((d) => d.toIso8601String()).toList(),
      'accuracyHistory': _accuracyHistory,
      'currentStreak': _currentStreak,
      'averageAccuracy': _averageAccuracy,
      'consecutiveDaysOver75': _consecutiveDaysOver75,
      'dailyBonusGiven': _dailyBonusGiven,
      'lastBonusDate': _lastBonusDate?.toIso8601String(),
    };
  }

  void importGameData(Map<String, dynamic> data) {
    try {
      _accuracyDates
        ..clear()
        ..addAll((data['accuracyDates'] as List?)
            ?.map((d) => DateTime.parse(d as String)) ??
            []);

      _accuracyHistory
        ..clear()
        ..addAll((data['accuracyHistory'] as List?)?.map((a) => a as double) ?? []);

      _currentStreak = data['currentStreak'] as int? ?? 0;
      _averageAccuracy = data['averageAccuracy'] as double? ?? 0.0;
      _consecutiveDaysOver75 = data['consecutiveDaysOver75'] as int? ?? 0;
      _dailyBonusGiven = data['dailyBonusGiven'] as bool? ?? false;

      final lastBonusDateStr = data['lastBonusDate'] as String?;
      _lastBonusDate = lastBonusDateStr != null ? DateTime.parse(lastBonusDateStr) : null;

      notifyListeners();
    } catch (e) {
      debugPrint('[GameService] Errore nell\'importazione dei dati: $e');
    }
  }

  Future<void> resetGameData({bool keepProgress = false}) async {
    if (!keepProgress) {
      _accuracyDates.clear();
      _accuracyHistory.clear();
      _currentStreak = 0;
      _averageAccuracy = 0.0;
      _consecutiveDaysOver75 = 0;
    }

    _dailyBonusGiven = false;
    _lastBonusDate = null;

    await _saveGameData();
    notifyListeners();
  }
}
