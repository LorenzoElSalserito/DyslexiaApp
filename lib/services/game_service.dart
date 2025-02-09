// lib/services/game_service.dart

import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../models/level.dart';
import '../models/enums.dart';
import '../services/content_service.dart';
import '../services/exercise_manager.dart';
import '../models/recognition_result.dart';

/// GameService gestisce la logica principale del gioco, coordinando
/// l'interazione tra il Player, il sistema di livelli e gli esercizi.
class GameService extends ChangeNotifier {
  // Dipendenze fondamentali
  final Player player;
  final ContentService contentService;
  final ExerciseManager exerciseManager;

  // Stato dell'inizializzazione
  bool _isInitialized = false;

  // Costanti per il sistema di progressione
  static const int requiredDaysForLevelUp = 5; // Giorni di pratica necessari
  static const double requiredAccuracy = 0.80; // Accuratezza minima (80%)
  static const int baseLoginBonus = 10; // Bonus base per login consecutivi
  static const double bonusMultiplierIncrease = 0.5; // Incremento giornaliero del bonus

  // Stato del gioco e progressione
  final List<DateTime> _accuracyDates = []; // Date con accuratezza >= 80%
  final List<double> _accuracyHistory = []; // Storico accuratezza per data
  int _currentStreak = 0; // Streak corrente
  double _averageAccuracy = 0.0; // Accuratezza media
  DateTime? _lastExerciseDate; // Data ultimo esercizio
  int _consecutiveDaysOver80 = 0; // Giorni consecutivi con accuratezza >= 80%

  /// Costruttore del servizio
  GameService({
    required this.player,
    required this.contentService,
    required this.exerciseManager,
  });

  /// Inizializza il servizio e prepara le risorse necessarie
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Inizializza i servizi dipendenti
      if (!contentService.isInitialized) {
        await contentService.initialize();
      }

      // Carica i dati di progressione
      _loadProgressionData();

      // Verifica il bonus giornaliero
      await _checkDailyLogin();

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Errore nell\'inizializzazione di GameService: $e');
      rethrow;
    }
  }

  /// Carica i dati di progressione salvati
  void _loadProgressionData() {
    // Qui potremmo aggiungere in futuro il caricamento da SharedPreferences
    _updateConsecutiveDays();
  }

  /// Verifica se è necessario assegnare un bonus per login consecutivi
  Future<void> _checkDailyLogin() async {
    final now = DateTime.now();
    final lastLogin = player.lastPlayDate;

    if (lastLogin == null) {
      // Primo login assoluto
      await _awardLoginBonus(1);
      return;
    }

    // Verifica se è un nuovo giorno
    if (!_isSameDay(now, lastLogin)) {
      // Verifica se è un giorno consecutivo
      final yesterday = now.subtract(const Duration(days: 1));
      if (_isSameDay(lastLogin, yesterday)) {
        // Incrementa i giorni consecutivi e assegna il bonus
        player.currentConsecutiveDays++;
        await _awardLoginBonus(player.currentConsecutiveDays);
      } else {
        // Reset dei giorni consecutivi
        player.currentConsecutiveDays = 1;
        await _awardLoginBonus(1);
      }
    }
  }

  /// Controlla se due date sono nello stesso giorno
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Assegna il bonus per i login consecutivi
  Future<void> _awardLoginBonus(int consecutiveDays) async {
    final bonus = (baseLoginBonus +
        ((consecutiveDays - 1) * bonusMultiplierIncrease)).round();

    if (bonus > 0) {
      player.addCrystals(bonus);
      // Il popup verrà gestito dal GameScreen
    }
  }

  /// Processa il risultato di un esercizio
  Future<void> processExerciseResult(RecognitionResult result) async {
    // Aggiorna accuratezza e streak
    if (result.isCorrect) {
      _currentStreak++;
    } else {
      _currentStreak = 0;
    }

    // Aggiorna l'accuratezza media
    _updateAccuracy(result.similarity);

    // Controlla la progressione del livello
    _checkLevelProgression();

    // Aggiorna data ultimo esercizio
    _lastExerciseDate = DateTime.now();
    player.updateConsecutiveDays();

    notifyListeners();
  }

  /// Aggiorna l'accuratezza media e il conteggio dei giorni con buona accuratezza
  void _updateAccuracy(double accuracy) {
    final now = DateTime.now();

    // Se è un nuovo giorno o il primo risultato
    if (_accuracyHistory.isEmpty ||
        !_isSameDay(now, _lastExerciseDate ?? now)) {
      _accuracyHistory.add(accuracy);
      _accuracyDates.add(now);

      // Mantieni solo gli ultimi 30 giorni
      if (_accuracyHistory.length > 30) {
        _accuracyHistory.removeAt(0);
        _accuracyDates.removeAt(0);
      }
    } else {
      // Aggiorna l'accuratezza del giorno corrente
      final lastIndex = _accuracyHistory.length - 1;
      final currentAverage = _accuracyHistory[lastIndex];
      _accuracyHistory[lastIndex] = (currentAverage + accuracy) / 2;
    }

    // Aggiorna l'accuratezza media
    _averageAccuracy = _accuracyHistory.isNotEmpty
        ? _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length
        : 0.0;

    _updateConsecutiveDays();
  }

  /// Aggiorna il conteggio dei giorni consecutivi con accuratezza >= 80%
  void _updateConsecutiveDays() {
    _consecutiveDaysOver80 = 0;

    // Conta i giorni consecutivi partendo dal più recente
    for (int i = _accuracyHistory.length - 1; i >= 0; i--) {
      if (_accuracyHistory[i] >= requiredAccuracy) {
        _consecutiveDaysOver80++;
      } else {
        break; // Interrompe al primo giorno sotto l'80%
      }
    }
  }

  /// Controlla se è possibile avanzare di livello
  void _checkLevelProgression() {
    if (_consecutiveDaysOver80 >= requiredDaysForLevelUp) {
      if (player.currentLevel < 4 && player.canLevelUp()) {
        // L'utente ha mantenuto un'accuratezza >= 80% per 5 giorni
        player.levelUp();
        _consecutiveDaysOver80 = 0; // Reset per il nuovo livello
        notifyListeners();
      }
    }
  }

  /// Ottiene il livello corrente
  Level getCurrentLevel() {
    return Level.allLevels.firstWhere(
          (level) => level.number == player.currentLevel,
      orElse: () => Level.allLevels.first,
    );
  }

  /// Ottiene il sottolivello corrente
  SubLevel getCurrentSubLevel() {
    final level = getCurrentLevel();
    final progress = getLevelUpProgress();

    if (progress < 0.33) return level.subLevels[0];
    if (progress < 0.66) return level.subLevels[1];
    return level.subLevels[2];
  }

  /// Calcola il progresso verso il prossimo livello (0.0 - 1.0)
  double getLevelUpProgress() {
    if (_consecutiveDaysOver80 == 0) return 0.0;
    return _consecutiveDaysOver80 / requiredDaysForLevelUp;
  }

  /// Verifica se il giocatore può avanzare di livello
  bool canAdvanceLevel() {
    return _consecutiveDaysOver80 >= requiredDaysForLevelUp &&
        player.canLevelUp();
  }

  // Getters pubblici
  bool get isInitialized => _isInitialized;
  double getAverageAccuracy() => _averageAccuracy;
  int get streak => _currentStreak;
  int get currentStreak => _currentStreak;
  bool get hasActiveStreak => _currentStreak >= 3;
  int get consecutiveDaysOver80 => _consecutiveDaysOver80;
  List<DateTime> get accuracyDates => List.unmodifiable(_accuracyDates);
  List<double> get accuracyHistory => List.unmodifiable(_accuracyHistory);

  /// Calcola il progresso del livello corrente (0.0 - 1.0)
  double get levelProgress {
    if (_accuracyHistory.isEmpty) return 0.0;
    return _calculateLevelProgress();
  }

  /// Calcola il progresso effettivo del livello
  double _calculateLevelProgress() {
    // Calcola la media delle ultime accuratezze
    double averageAccuracy = _accuracyHistory.isEmpty ? 0.0 :
    _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length;

    // Se l'accuratezza media è sotto la soglia minima, il progresso è 0
    if (averageAccuracy < requiredAccuracy) return 0.0;

    // Altrimenti il progresso è basato sui giorni consecutivi
    return _consecutiveDaysOver80 / requiredDaysForLevelUp;
  }
}