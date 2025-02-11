import 'package:flutter/foundation.dart';
import '../services/file_storage_service.dart';
import 'dart:convert';

/// Classe che rappresenta un giocatore nell'applicazione.
/// Gestisce tutti i dati del profilo, il loro salvataggio persistente,
/// e il tracking dei giorni consecutivi di gioco.
class Player with ChangeNotifier {
  /// Costruttore predefinito esplicito
  Player();

  // Service per il salvataggio dei dati
  final FileStorageService _storageService = FileStorageService();

  // Proprietà fondamentali del giocatore
  String _id = '';
  String _name = '';
  int _totalCrystals = 0;
  int _currentLevel = 1;
  int _currentStep = 0;
  bool _isAdmin = false;
  int _newGamePlusCount = 0;
  Set<String> _usedWords = {};
  Set<String> _usedSentences = {};

  // Proprietà per il tracking temporale
  DateTime? _lastPlayDate;
  DateTime? _lastLoginDate;  // Nuovo campo per tracciare l'ultimo login
  int _maxConsecutiveDays = 0;
  int _currentConsecutiveDays = 0;
  Map<String, dynamic> _gameData = {};

  // Costi dei livelli, aumentano con New Game+
  static const Map<int, int> _baseLevelCrystalCosts = {
    1: 300,
    2: 1500,
    3: 5000,
    4: 10000,
  };

  // Getters e setters
  String get id => _id;
  set id(String value) {
    if (_id != value) {
      _id = value;
      saveProgress();
      notifyListeners();
    }
  }

  String get name => _name;
  set name(String value) {
    if (value.isNotEmpty && _name != value) {
      _name = value;
      saveProgress();
      notifyListeners();
    }
  }

  int get totalCrystals => _totalCrystals;
  set totalCrystals(int value) {
    if (_totalCrystals != value) {
      _totalCrystals = value;
      _gameData['crystals'] = value;
      saveProgress();
      notifyListeners();
    }
  }

  int get currentLevel => _currentLevel;
  set currentLevel(int value) {
    if (_currentLevel != value) {
      _currentLevel = value;
      _gameData['level'] = value;
      saveProgress();
      notifyListeners();
    }
  }

  int get currentStep => _currentStep;
  set currentStep(int value) {
    if (_currentStep != value) {
      _currentStep = value;
      saveProgress();
      notifyListeners();
    }
  }

  bool get isAdmin => _isAdmin;
  int get newGamePlusCount => _newGamePlusCount;
  Set<String> get usedWords => Set.unmodifiable(_usedWords);
  Set<String> get usedSentences => Set.unmodifiable(_usedSentences);
  Map<String, dynamic> get gameData => Map<String, dynamic>.from(_gameData);

  DateTime? get lastPlayDate => _lastPlayDate;
  set lastPlayDate(DateTime? value) {
    if (_lastPlayDate != value) {
      _lastPlayDate = value;
      _gameData['lastPlayDate'] = value?.toIso8601String();
      saveProgress();
      notifyListeners();
    }
  }

  int get maxConsecutiveDays => _maxConsecutiveDays;
  set maxConsecutiveDays(int value) {
    if (_maxConsecutiveDays != value) {
      _maxConsecutiveDays = value;
      saveProgress();
      notifyListeners();
    }
  }

  int get currentConsecutiveDays => _currentConsecutiveDays;
  set currentConsecutiveDays(int value) {
    if (_currentConsecutiveDays != value) {
      _currentConsecutiveDays = value;
      saveProgress();
      notifyListeners();
    }
  }

  int get levelCrystalCost =>
      (_baseLevelCrystalCosts[currentLevel] ?? 0) * (newGamePlusCount + 1);

  /// Aggiorna i dati di gioco
  void updateGameData(Map<String, dynamic> newData) {
    _gameData = Map<String, dynamic>.from(newData);
    saveProgress();
    notifyListeners();
  }

  /// Inizializza le informazioni del giocatore
  Future<void> setPlayerInfo(String name) async {
    if (name.isEmpty) {
      throw Exception('Il nome non può essere vuoto');
    }

    bool shouldSave = false;

    if (_name != name) {
      _name = name;
      shouldSave = true;
    }

    final isNewAdmin = (name.toLowerCase() == 'admin');
    if (_isAdmin != isNewAdmin) {
      _isAdmin = isNewAdmin;
      shouldSave = true;
    }

    // Se è un nuovo profilo, resetta i dati
    if (_totalCrystals == 0 && _currentLevel == 1) {
      _totalCrystals = 0;
      _currentLevel = 1;
      _currentStep = 0;
      _newGamePlusCount = 0;
      _maxConsecutiveDays = 0;
      _currentConsecutiveDays = 0;
      _lastPlayDate = DateTime.now();
      _lastLoginDate = DateTime.now();  // Inizializza la data di login
      _usedWords.clear();
      _usedSentences.clear();
      _gameData.clear();
      shouldSave = true;
    }

    if (shouldSave) {
      await saveProgress();
      notifyListeners();
    }
  }

  /// Aggiorna i giorni consecutivi di gioco
  /// Questa funzione viene chiamata ogni volta che il giocatore effettua il login
  /// o completa un'azione significativa nel gioco
  void updateConsecutiveDays() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    // Se è il primo login, inizializza le date
    if (_lastLoginDate == null) {
      _lastLoginDate = now;
      _currentConsecutiveDays = 1;
      maxConsecutiveDays = 1;
      return;
    }

    // Verifica se è passato più di un giorno dall'ultimo login
    if (_lastLoginDate != null) {
      // Se l'ultimo login è stato ieri, incrementa i giorni consecutivi
      if (_isSameDay(_lastLoginDate!, yesterday)) {
        _currentConsecutiveDays++;
        if (_currentConsecutiveDays > _maxConsecutiveDays) {
          maxConsecutiveDays = _currentConsecutiveDays;
        }
      }
      // Se l'ultimo login non è stato ieri ma è oggi, non fare nulla
      else if (_isSameDay(_lastLoginDate!, now)) {
        return;
      }
      // Se sono passati più giorni, resetta il conteggio
      else {
        _currentConsecutiveDays = 1;
      }
    }

    // Aggiorna la data dell'ultimo login
    _lastLoginDate = now;
    _gameData['lastLoginDate'] = now.toIso8601String();

    saveProgress();
    notifyListeners();
  }

  /// Verifica se due date sono lo stesso giorno
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Aggiunge cristalli al totale
  void addCrystals(int amount) {
    if (amount != 0) {
      totalCrystals += amount;
      saveProgress();
    }
  }

  /// Verifica se il giocatore può salire di livello
  bool canLevelUp() => totalCrystals >= levelCrystalCost;

  /// Sale di livello se possibile
  void levelUp() {
    if (canLevelUp() || isAdmin) {
      if (!isAdmin) {
        totalCrystals -= levelCrystalCost;
      }
      currentLevel++;
      currentStep = 0;
      saveProgress();
    }
  }

  /// Incrementa lo step corrente
  void incrementStep() {
    currentStep++;
    updateConsecutiveDays();
    saveProgress();
  }

  /// Avvia un nuovo ciclo New Game+
  void startNewGamePlus() {
    _newGamePlusCount++;
    currentLevel = 1;
    currentStep = 0;
    _usedWords.clear();
    _usedSentences.clear();
    _gameData['newGamePlus'] = _newGamePlusCount;
    saveProgress();
    notifyListeners();
  }

  /// Converte il giocatore in formato JSON (Map)
  Map<String, dynamic> toJson() {
    return {
      'id': _id,
      'name': _name,
      'totalCrystals': _totalCrystals,
      'currentLevel': _currentLevel,
      'currentStep': _currentStep,
      'isAdmin': _isAdmin,
      'newGamePlusCount': _newGamePlusCount,
      'maxConsecutiveDays': _maxConsecutiveDays,
      'currentConsecutiveDays': _currentConsecutiveDays,
      'lastPlayDate': _lastPlayDate?.toIso8601String(),
      'lastLoginDate': _lastLoginDate?.toIso8601String(),  // Salva la data dell'ultimo login
      'usedWords': _usedWords.toList(),
      'usedSentences': _usedSentences.toList(),
      'gameData': _gameData,
    };
  }

  /// Carica il giocatore da formato JSON (Map)
  void fromJson(Map<String, dynamic> json) {
    _id = json['id']?.toString() ?? '';
    _name = json['name']?.toString() ?? '';
    _totalCrystals = _parseIntSafely(json['totalCrystals']);
    _currentLevel = _parseIntSafely(json['currentLevel'], defaultValue: 1);
    _currentStep = _parseIntSafely(json['currentStep']);
    _isAdmin = json['isAdmin'] == true;
    _newGamePlusCount = _parseIntSafely(json['newGamePlusCount']);
    _maxConsecutiveDays = _parseIntSafely(json['maxConsecutiveDays']);
    _currentConsecutiveDays = _parseIntSafely(json['currentConsecutiveDays']);

    final lastPlayDateStr = json['lastPlayDate']?.toString();
    _lastPlayDate = (lastPlayDateStr != null && lastPlayDateStr.isNotEmpty)
        ? DateTime.parse(lastPlayDateStr)
        : null;

    final lastLoginDateStr = json['lastLoginDate']?.toString();
    _lastLoginDate = (lastLoginDateStr != null && lastLoginDateStr.isNotEmpty)
        ? DateTime.parse(lastLoginDateStr)
        : null;

    _usedWords =
        (json['usedWords'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    _usedSentences =
        (json['usedSentences'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    _gameData = (json['gameData'] as Map?)?.cast<String, dynamic>() ?? {};

    notifyListeners();
  }

  /// Converte in modo sicuro un valore in intero
  int _parseIntSafely(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Salva il progresso del giocatore
  Future<void> saveProgress() async {
    if (_id.isEmpty) return;
    try {
      final profileData = toJson();
      await _storageService.writeProfile(_id, profileData);
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  /// Carica il progresso del giocatore
  Future<bool> loadProgress() async {
    if (_id.isEmpty) return false;
    try {
      final profileDataMap = await _storageService.readProfile(_id);
      if (profileDataMap.isNotEmpty) {
        fromJson(profileDataMap);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error loading progress: $e');
      return false;
    }
  }

  /// Resetta il progresso del giocatore
  Future<void> resetProgress() async {
    if (_id.isNotEmpty) {
      await _storageService.deleteProfile(_id);
    }
    _totalCrystals = 0;
    _currentLevel = 1;
    _currentStep = 0;
    _newGamePlusCount = 0;
    _maxConsecutiveDays = 0;
    _currentConsecutiveDays = 0;
    _lastPlayDate = null;
    _lastLoginDate = null;
    _usedWords.clear();
    _usedSentences.clear();
    _gameData.clear();
    await saveProgress();
    notifyListeners();
  }

  /// Verifica se esiste un profilo per questo giocatore
  Future<bool> hasProfile() async {
    if (_id.isEmpty) return false;
    return await _storageService.profileExists(_id);
  }
}