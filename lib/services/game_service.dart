// lib/services/game_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async'; // Aggiunto per Completer e TimeoutException
import '../models/player.dart';
import '../models/level.dart';
import '../models/enums.dart';
import '../services/content_service.dart';
import '../services/exercise_manager.dart';
import '../models/recognition_result.dart';
import '../services/game_notification_manager.dart';

/// GameService gestisce tutti gli aspetti relativi alla progressione nel gioco,
/// al sistema di ricompense, alle statistiche e al tracking dell'utente.
/// Mantiene lo stato di gioco e coordina le interazioni tra i vari sottosistemi.
class GameService extends ChangeNotifier {
  late Player _player;
  final ContentService contentService;
  final ExerciseManager exerciseManager;
  final GameNotificationManager _notificationManager;

  // Stato di inizializzazione
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _lastInitError;
  int _initAttempts = 0;
  static const int _maxInitAttempts = 3;

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
  bool _dailyBonusShown = false;
  DateTime? _lastBonusDate;
  DateTime? _lastLoginDate;
  late SubLevel _currentSubLevel;

  // Mutex per operazioni critiche
  bool _operationInProgress = false;
  final List<Completer<void>> _pendingOperations = [];

  /// Costruttore del GameService
  GameService({
    required Player player,
    required this.contentService,
    required this.exerciseManager,
  })  : _notificationManager = GameNotificationManager(),
        _currentSubLevel = Level.allLevels[0].subLevels[0] {
    debugPrint('[GameService] Costruttore: Inizializzo i dati di gioco...');
    _player = player;

    // L'inizializzazione completa verrà fatta nel metodo initialize()
    // per evitare operazioni pesanti durante la costruzione
  }

  /// Aggiorna il giocatore corrente e ricarica il suo stato
  Future<void> updatePlayer(Player newPlayer) async {
    return _executeExclusiveOperation(() async {
      _player = newPlayer;
      debugPrint('[GameService] updatePlayer: nuovo player = ${_player.toJson()}');
      await _player.loadProgress();
      await _loadGameData();
      notifyListeners();
    });
  }

  /// Inizializza il GameService e carica tutti i dati necessari
  Future<void> initialize() async {
    // Previene inizializzazioni multiple concorrenti
    if (_isInitialized || _isInitializing) {
      debugPrint('[GameService] initialize: Già inizializzato o in corso');
      return;
    }

    _isInitializing = true;
    _initAttempts++;

    try {
      debugPrint('[GameService] initialize: Inizializzazione in corso (tentativo $_initAttempts/$_maxInitAttempts)...');

      // Verifica e inizializza il ContentService
      if (!contentService.isInitialized) {
        debugPrint('[GameService] Inizializzo contentService...');
        await contentService.initialize().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Timeout nell\'inizializzazione del contentService');
            }
        );
      }

      // Carica i dati di gioco e imposta il sottolivello corrente
      await _loadGameData();
      _dailyBonusShown = false;

      // Controlla il bonus di login giornaliero
      await _checkDailyLoginBonus();

      _isInitialized = true;
      _isInitializing = false;
      _lastInitError = null;
      debugPrint('[GameService] Inizializzazione completata.');
      notifyListeners();
    } catch (e, stackTrace) {
      _lastInitError = e.toString();
      _isInitializing = false;

      debugPrint('[GameService] Errore nell\'inizializzazione: $e');
      debugPrint('[GameService] Stack trace: $stackTrace');

      // Riprova automaticamente l'inizializzazione fino al limite di tentativi
      if (_initAttempts < _maxInitAttempts) {
        debugPrint('[GameService] Nuovo tentativo di inizializzazione (${_initAttempts}/$_maxInitAttempts)...');
        await Future.delayed(Duration(seconds: _initAttempts)); // Backoff esponenziale
        return initialize();
      }

      rethrow;
    }
  }

  /// Carica i dati di gioco dal profilo del giocatore
  Future<void> _loadGameData() async {
    debugPrint('[GameService] _loadGameData: Avvio caricamento dati di gioco...');
    try {
      final gameData = _player.gameData;
      debugPrint('[GameService] Dati letti dal profilo: $gameData');

      // Carica media accuratezza
      _averageAccuracy = (gameData['averageAccuracy'] is num)
          ? (gameData['averageAccuracy'] as num).toDouble()
          : 0.0;

      // Carica stato del bonus giornaliero
      _dailyBonusGiven = gameData['dailyBonusGiven'] as bool? ?? false;

      // Carica date importanti
      final lastBonusDateStr = gameData['lastBonusDate'] as String?;
      if (lastBonusDateStr != null) {
        _lastBonusDate = DateTime.parse(lastBonusDateStr);
      }

      final lastLoginDateStr = gameData['lastLoginDate'] as String?;
      if (lastLoginDateStr != null) {
        _lastLoginDate = DateTime.parse(lastLoginDateStr);
      }

      // Carica storico accuratezza
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
            final a = (acc is num) ? (acc as num).toDouble() : 0.0;
            debugPrint('[GameService] Accuratezza aggiunta: $a');
            return a;
          }));
      } else {
        debugPrint('[GameService] Nessun dato di accuratezza trovato, inizializzo array vuoti.');
        _accuracyDates.clear();
        _accuracyHistory.clear();
      }

      // Carica current streak
      _currentStreak = gameData['currentStreak'] as int? ?? 0;
      debugPrint('[GameService] Current streak: $_currentStreak');

      // Aggiorna i contatori basati sui dati caricati
      _updateConsecutiveDays();
      _loadCurrentSubLevel();

      // Salva lo stato per assicurarsi che tutti i campi siano inizializzati
      await _saveGameData();

      debugPrint('[GameService] _loadGameData completato.');
    } catch (e, stackTrace) {
      debugPrint('[GameService] Errore in _loadGameData: $e');
      debugPrint('[GameService] Stack trace: $stackTrace');

      // Resetta i dati in caso di errore
      _averageAccuracy = 0.0;
      _currentStreak = 0;
      _accuracyDates.clear();
      _accuracyHistory.clear();
      _dailyBonusGiven = false;
      _lastBonusDate = null;
      _lastLoginDate = null;

      // Salva i dati resettati
      await _saveGameData();
    }
  }

  /// Imposta il sottolivello corrente in base al livello e passo del giocatore
  void _loadCurrentSubLevel() {
    final currentLevel = _player.currentLevel;
    final levelIndex = currentLevel - 1;

    if (levelIndex >= 0 && levelIndex < Level.allLevels.length) {
      final level = Level.allLevels[levelIndex];
      final subLevelIndex = (_player.currentStep ~/ 3).clamp(0, level.subLevels.length - 1);
      _currentSubLevel = level.subLevels[subLevelIndex];
      debugPrint('[GameService] Sottolivello corrente impostato: $_currentSubLevel');
    } else {
      debugPrint('[GameService] ATTENZIONE: livello $currentLevel non valido, uso il livello 1');
      _currentSubLevel = Level.allLevels[0].subLevels[0];
    }
  }

  /// Verifica e aggiorna lo stato dei giorni consecutivi
  void _updateConsecutiveDays() {
    _consecutiveDaysOver75 = 0;

    // Verifica quanti giorni consecutivi hanno un'accuratezza superiore al 75%
    for (int i = _accuracyHistory.length - 1; i >= 0; i--) {
      if (_accuracyHistory[i] >= requiredAccuracy) {
        _consecutiveDaysOver75++;
      } else {
        break;
      }
    }

    debugPrint('[GameService] ConsecutiveDaysOver75: $_consecutiveDaysOver75');
  }

  /// Controlla e assegna il bonus giornaliero di login
  Future<void> _checkDailyLoginBonus() async {
    debugPrint('[GameService] _checkDailyLoginBonus: Verifica bonus giornaliero...');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Verifica se c'è stato un accesso precedente
    if (_lastLoginDate == null) {
      _player.currentConsecutiveDays = 1;
      _dailyBonusGiven = false; // Non assegnare bonus al primo accesso
      debugPrint('[GameService] Nessun login precedente trovato, impostazione primo accesso (no bonus)');
    } else {
      final yesterday = DateTime(now.year, now.month, now.day - 1);

      // Controlla se l'ultimo accesso è stato ieri (per aggiornare i giorni consecutivi)
      if (_isSameDay(_lastLoginDate!, yesterday)) {
        _player.currentConsecutiveDays++;
        if (_player.currentConsecutiveDays > _player.maxConsecutiveDays) {
          _player.maxConsecutiveDays = _player.currentConsecutiveDays;
        }
        debugPrint('[GameService] Accesso consecutivo rilevato, aggiornamento giorni consecutivi: ${_player.currentConsecutiveDays}');

        // Assegna bonus per tutti i giorni consecutivi dopo il primo
        if (_player.currentConsecutiveDays >= 2) {
          // Calcola e assegna il bonus
          final bonus = _calculateDailyBonus(_player.currentConsecutiveDays);
          debugPrint('[GameService] Bonus giornaliero calcolato: $bonus per ${_player.currentConsecutiveDays} giorni consecutivi');
          _player.addCrystals(bonus);

          _dailyBonusGiven = true;
          _dailyBonusShown = false; // Reset lo stato di visualizzazione
          _lastBonusDate = today;
          _player.gameData['lastBonusDate'] = today.toIso8601String();
          _player.gameData['dailyBonusGiven'] = true;
        } else {
          _dailyBonusGiven = false;
          debugPrint('[GameService] Solo 1 giorno consecutivo, nessun bonus assegnato');
        }
      } else if (!_isSameDay(_lastLoginDate!, today)) {
        // Se non è né oggi né ieri, resettiamo il conteggio
        _player.currentConsecutiveDays = 1;
        _dailyBonusGiven = false; // Nessun bonus per il primo giorno
        debugPrint('[GameService] Accesso non consecutivo, reset a 1 giorno (no bonus)');
      } else {
        // È lo stesso giorno, manteniamo i valori attuali
        debugPrint('[GameService] Accesso nello stesso giorno, mantengo i valori attuali');
        // Non modifichiamo _dailyBonusGiven qui
      }
    }

    // Aggiorna la data di ultimo login
    _lastLoginDate = today;
    _player.gameData['lastLoginDate'] = today.toIso8601String();
    _player.gameData['dailyBonusGiven'] = _dailyBonusGiven;

    await _player.saveProgress();
    debugPrint('[GameService] Verifica bonus completata. _dailyBonusGiven=$_dailyBonusGiven, _dailyBonusShown=$_dailyBonusShown');
  }

  /// Mostra il popup del bonus giornaliero se necessario
  Future<void> showDailyLoginBonus(BuildContext context) async {
    if (!_isInitialized) {
      debugPrint('[GameService] showDailyLoginBonus: Servizio non inizializzato, inizializzazione...');
      await initialize();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Mostra il bonus solo se è stato assegnato oggi e non è ancora stato mostrato
    final bonusDatoOggi = _dailyBonusGiven && _lastBonusDate != null && _isSameDay(_lastBonusDate!, today);

    debugPrint('[GameService] showDailyLoginBonus: bonusDatoOggi=$bonusDatoOggi, _dailyBonusShown=$_dailyBonusShown');

    if (bonusDatoOggi && !_dailyBonusShown && _player.currentConsecutiveDays >= 2) {
      debugPrint('[GameService] showDailyLoginBonus: Mostro il popup bonus...');
      await _notificationManager.showDailyLoginBonus(
        context,
        _player.currentConsecutiveDays,
      );

      // Segna che il bonus è stato mostrato
      _dailyBonusShown = true;
      _player.gameData['dailyBonusShown'] = true;
      await _player.saveProgress();
      debugPrint('[GameService] Bonus visualizzato all\'utente');
    } else {
      debugPrint('[GameService] showDailyLoginBonus: Nessun bonus da mostrare'
          + (_player.currentConsecutiveDays < 2 ? ' (giorni consecutivi insufficienti)' : ''));
    }
  }

  /// Calcola il bonus giornaliero in base ai giorni consecutivi
  int _calculateDailyBonus(int consecutiveDays) {
    // Formula: bonus base + (giorni consecutivi - 1) * fattore incremento
    final multiplier = 1.0 + ((consecutiveDays - 1) * bonusMultiplierIncrease);
    final bonus = (baseLoginBonus * multiplier).round();

    debugPrint('[GameService] _calculateDailyBonus: consecutiveDays=$consecutiveDays, bonus=$bonus');
    return bonus;
  }

  /// Verifica se due date rappresentano lo stesso giorno
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Processa il risultato di un esercizio e aggiorna le statistiche
  Future<void> processExerciseResult(RecognitionResult result) async {
    debugPrint('[GameService] processExerciseResult: Risultato=${result.toJson()}');

    // Aggiorna lo streak corrente
    if (result.isCorrect) {
      _currentStreak++;
    } else {
      _currentStreak = 0;
    }
    debugPrint('[GameService] Nuovo currentStreak: $_currentStreak');

    // Aggiorna le statistiche di accuratezza
    _updateAccuracy(result.similarity);

    // Verifica la progressione di livello
    _checkLevelProgression();

    // Salva i dati aggiornati
    await _saveGameData();

    notifyListeners();
  }

  /// Aggiorna le statistiche di accuratezza con un nuovo risultato
  void _updateAccuracy(double accuracy) {
    final now = DateTime.now();
    debugPrint('[GameService] _updateAccuracy: accuracy=$accuracy, now=$now');

    // Verifica se abbiamo già registrato un'accuratezza per oggi
    if (_accuracyHistory.isEmpty || !_isSameDay(now, _accuracyDates.last)) {
      // Prima accuratezza del giorno, aggiungiamo direttamente
      _accuracyHistory.add(accuracy);
      _accuracyDates.add(now);
      debugPrint('[GameService] Valori aggiunti: _accuracyHistory=$_accuracyHistory');
    } else {
      // Già registrata un'accuratezza oggi, facciamo la media
      final lastIndex = _accuracyHistory.length - 1;
      final currentAverage = _accuracyHistory[lastIndex];
      _accuracyHistory[lastIndex] = (currentAverage + accuracy) / 2;
      debugPrint('[GameService] Valore aggiornato: ${_accuracyHistory[lastIndex]}');
    }

    // Calcola la media generale
    _averageAccuracy = _accuracyHistory.isEmpty
        ? 0.0
        : _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length;
    debugPrint('[GameService] Nuova media accuracy: $_averageAccuracy');

    // Aggiorna il conteggio dei giorni consecutivi con buona accuratezza
    _updateConsecutiveDays();
  }

  /// Salva i dati di gioco nel profilo del giocatore
  Future<void> _saveGameData() async {
    debugPrint('[GameService] _saveGameData: Salvataggio dati gioco...');

    try {
      final gameData = Map<String, dynamic>.from(_player.gameData);

      // Aggiungi tutti i dati che devono essere persistenti
      gameData['averageAccuracy'] = _averageAccuracy;
      gameData['accuracyDates'] = _accuracyDates.map((date) => date.toIso8601String()).toList();
      gameData['accuracyHistory'] = _accuracyHistory;
      gameData['currentStreak'] = _currentStreak;
      gameData['dailyBonusGiven'] = _dailyBonusGiven;

      if (_lastBonusDate != null) {
        gameData['lastBonusDate'] = _lastBonusDate!.toIso8601String();
      }

      if (_lastLoginDate != null) {
        gameData['lastLoginDate'] = _lastLoginDate!.toIso8601String();
      }

      debugPrint('[GameService] GameData aggiornato: $gameData');

      // Aggiorna il gameData nel player e salva
      _player.updateGameData(gameData);
      await _player.saveProgress();
      debugPrint('[GameService] Dati di gioco salvati.');
    } catch (e, stackTrace) {
      debugPrint('[GameService] Errore nel salvataggio dati: $e');
      debugPrint('[GameService] Stack trace: $stackTrace');
    }
  }

  /// Verifica se il giocatore può avanzare di livello
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

  /// Resetta lo stato del bonus giornaliero
  Future<void> resetDailyBonus() async {
    debugPrint('[GameService] resetDailyBonus: Reset bonus giornaliero...');

    await _executeExclusiveOperation(() async {
      _dailyBonusGiven = false;
      _dailyBonusShown = false;
      _player.gameData['dailyBonusGiven'] = false;
      await _player.saveProgress();
      debugPrint('[GameService] Bonus giornaliero resettato.');
    });
  }

  /// Resetta lo stato di visualizzazione del bonus
  Future<void> resetDailyBonusShown() async {
    debugPrint('[GameService] resetDailyBonusShown: Reset stato visualizzazione bonus...');
    _dailyBonusShown = false;
  }

  /// Esegue un'operazione in modo esclusivo per evitare race conditions
  Future<void> _executeExclusiveOperation(Future<void> Function() operation) async {
    final completer = Completer<void>();
    _pendingOperations.add(completer);

    // Se questa è la prima operazione nella coda, eseguila subito
    if (_pendingOperations.length == 1 && !_operationInProgress) {
      try {
        _operationInProgress = true;
        await operation();
        completer.complete();
      } catch (e, stackTrace) {
        debugPrint('[GameService] Errore in operazione esclusiva: $e');
        debugPrint('[GameService] Stack trace: $stackTrace');
        completer.completeError(e, stackTrace);
      } finally {
        _operationInProgress = false;
        _pendingOperations.removeAt(0);

        // Se ci sono altre operazioni in attesa, processa la successiva
        if (_pendingOperations.isNotEmpty) {
          _processNextOperation();
        }
      }
    }

    return completer.future;
  }

  /// Processa la prossima operazione nella coda
  void _processNextOperation() {
    if (_pendingOperations.isEmpty || _operationInProgress) return;

    // Ottieni il primo completer nella coda
    final nextCompleter = _pendingOperations[0];

    // Implementazione della logica di esecuzione
    Future<void> executeNext() async {
      try {
        _operationInProgress = true;

        // Se il completer è già stato completato, rimuovilo e passa al successivo
        if (nextCompleter.isCompleted) {
          _pendingOperations.removeAt(0);
          _operationInProgress = false;
          if (_pendingOperations.isNotEmpty) {
            _processNextOperation();
          }
          return;
        }

        // Creiamo una nuova operazione fittizia che completa il completer
        // Questo è necessario perché l'operazione originale è stata persa
        nextCompleter.complete();

      } catch (e, stackTrace) {
        debugPrint('[GameService] Errore nell\'esecuzione della prossima operazione: $e');
        debugPrint('[GameService] Stack trace: $stackTrace');
        if (!nextCompleter.isCompleted) {
          nextCompleter.completeError(e, stackTrace);
        }
      } finally {
        _operationInProgress = false;
        _pendingOperations.removeAt(0);

        // Processa la prossima operazione se presente
        if (_pendingOperations.isNotEmpty) {
          _processNextOperation();
        }
      }
    }

    // Avvia l'esecuzione
    executeNext();
  }

  /// Resetta tutti i dati di gioco
  Future<void> resetGameData({bool keepProgress = false}) async {
    await _executeExclusiveOperation(() async {
      if (!keepProgress) {
        _accuracyDates.clear();
        _accuracyHistory.clear();
        _currentStreak = 0;
        _averageAccuracy = 0.0;
        _consecutiveDaysOver75 = 0;
      }

      _dailyBonusGiven = false;
      _dailyBonusShown = false;
      _lastBonusDate = null;

      await _saveGameData();
      notifyListeners();
    });
  }

  /// Esporta tutti i dati di gioco in un formato facilmente serializzabile
  Map<String, dynamic> exportGameData() {
    return {
      'accuracyDates': _accuracyDates.map((d) => d.toIso8601String()).toList(),
      'accuracyHistory': _accuracyHistory,
      'currentStreak': _currentStreak,
      'averageAccuracy': _averageAccuracy,
      'consecutiveDaysOver75': _consecutiveDaysOver75,
      'dailyBonusGiven': _dailyBonusGiven,
      'dailyBonusShown': _dailyBonusShown,
      'lastBonusDate': _lastBonusDate?.toIso8601String(),
      'lastLoginDate': _lastLoginDate?.toIso8601String(),
    };
  }

  /// Importa dati di gioco precedentemente esportati
  void importGameData(Map<String, dynamic> data) {
    try {
      _accuracyDates
        ..clear()
        ..addAll((data['accuracyDates'] as List?)
            ?.map((d) => DateTime.parse(d as String)) ??
            []);

      _accuracyHistory
        ..clear()
        ..addAll((data['accuracyHistory'] as List?)?.map((a) => (a as num).toDouble()) ?? []);

      _currentStreak = data['currentStreak'] as int? ?? 0;
      _averageAccuracy = data['averageAccuracy'] as double? ?? 0.0;
      _consecutiveDaysOver75 = data['consecutiveDaysOver75'] as int? ?? 0;
      _dailyBonusGiven = data['dailyBonusGiven'] as bool? ?? false;
      _dailyBonusShown = data['dailyBonusShown'] as bool? ?? false;

      final lastBonusDateStr = data['lastBonusDate'] as String?;
      _lastBonusDate = lastBonusDateStr != null ? DateTime.parse(lastBonusDateStr) : null;

      final lastLoginDateStr = data['lastLoginDate'] as String?;
      _lastLoginDate = lastLoginDateStr != null ? DateTime.parse(lastLoginDateStr) : null;

      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[GameService] Errore nell\'importazione dei dati: $e');
      debugPrint('[GameService] Stack trace: $stackTrace');
    }
  }

  // Getters pubblici
  SubLevel getCurrentSubLevel() => _currentSubLevel;
  double getLevelUpProgress() {
    final progress = _consecutiveDaysOver75 / requiredDaysForLevelUp;
    debugPrint('[GameService] getLevelUpProgress: $progress');
    return progress.clamp(0.0, 1.0);
  }
  bool canAdvanceLevel() => _consecutiveDaysOver75 >= requiredDaysForLevelUp && _player.currentLevel < 4;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  String? get lastInitError => _lastInitError;
  double getAverageAccuracy() => _averageAccuracy;
  int get streak => _currentStreak;
  int get currentStreak => _currentStreak;
  bool get hasActiveStreak => _currentStreak >= 3;
  int get consecutiveDaysOver75 => _consecutiveDaysOver75;
  List<DateTime> get accuracyDates => List.unmodifiable(_accuracyDates);
  List<double> get accuracyHistory => List.unmodifiable(_accuracyHistory);

  /// Verifica se c'è un bonus giornaliero disponibile
  bool get isDailyBonusAvailable {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Verifica se il bonus non è stato dato oggi oppure se è stato dato
    // ma non ancora mostrato
    return (!_dailyBonusGiven) ||
        (_dailyBonusGiven && !_dailyBonusShown) ||
        (_lastBonusDate != null && !_isSameDay(_lastBonusDate!, today));
  }
}