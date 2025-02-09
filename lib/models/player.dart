// lib/models/player.dart

import 'package:flutter/foundation.dart';
import '../services/file_storage_service.dart';
import 'dart:convert';

class Player with ChangeNotifier {
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
  DateTime? _lastPlayDate;
  int _maxConsecutiveDays = 0;
  int _currentConsecutiveDays = 0;
  Map<String, dynamic> _gameData = {};

  static const Map<int, int> _baseLevelCrystalCosts = {
    1: 300,
    2: 1500,
    3: 5000,
    4: 10000,
  };

  // Getters e Setters con notifica
  String get id => _id;
  set id(String value) {
    _id = value;
    notifyListeners();
  }

  String get name => _name;
  set name(String value) {
    if (value.isNotEmpty && _name != value) {
      _name = value;
      notifyListeners();
    }
  }

  int get totalCrystals => _totalCrystals;
  set totalCrystals(int value) {
    if (_totalCrystals != value) {
      _totalCrystals = value;
      _gameData['crystals'] = value;
      notifyListeners();
    }
  }

  int get currentLevel => _currentLevel;
  set currentLevel(int value) {
    if (_currentLevel != value) {
      _currentLevel = value;
      _gameData['level'] = value;
      notifyListeners();
    }
  }

  int get currentStep => _currentStep;
  set currentStep(int value) {
    if (_currentStep != value) {
      _currentStep = value;
      notifyListeners();
    }
  }

  bool get isAdmin => _isAdmin;
  int get newGamePlusCount => _newGamePlusCount;
  Set<String> get usedWords => Set.unmodifiable(_usedWords);
  Set<String> get usedSentences => Set.unmodifiable(_usedSentences);
  Map<String, dynamic> get gameData => Map.unmodifiable(_gameData);

  DateTime? get lastPlayDate => _lastPlayDate;
  set lastPlayDate(DateTime? value) {
    if (_lastPlayDate != value) {
      _lastPlayDate = value;
      _gameData['lastPlayDate'] = value?.toIso8601String();
      notifyListeners();
    }
  }

  int get maxConsecutiveDays => _maxConsecutiveDays;
  set maxConsecutiveDays(int value) {
    if (_maxConsecutiveDays != value) {
      _maxConsecutiveDays = value;
      notifyListeners();
    }
  }

  int get currentConsecutiveDays => _currentConsecutiveDays;
  set currentConsecutiveDays(int value) {
    if (_currentConsecutiveDays != value) {
      _currentConsecutiveDays = value;
      notifyListeners();
    }
  }

  int get levelCrystalCost =>
      (_baseLevelCrystalCosts[currentLevel] ?? 0) * (newGamePlusCount + 1);

  Future<void> setPlayerInfo(String name) async {
    if (name.isEmpty) {
      throw Exception('Il nome non può essere vuoto');
    }

    _name = name;
    _totalCrystals = 0;
    _currentLevel = 1;
    _currentStep = 0;
    _isAdmin = (name.toLowerCase() == 'admin');
    _newGamePlusCount = 0;
    _maxConsecutiveDays = 0;
    _currentConsecutiveDays = 0;
    _lastPlayDate = DateTime.now();
    _usedWords.clear();
    _usedSentences.clear();
    _gameData.clear();

    await saveProgress();
    notifyListeners();
  }

  void updateConsecutiveDays() {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));

    if (_lastPlayDate != null) {
      if (_lastPlayDate!.year == yesterday.year &&
          _lastPlayDate!.month == yesterday.month &&
          _lastPlayDate!.day == yesterday.day) {
        currentConsecutiveDays++;
        if (currentConsecutiveDays > maxConsecutiveDays) {
          maxConsecutiveDays = currentConsecutiveDays;
        }
      } else if (_lastPlayDate!.year != now.year ||
          _lastPlayDate!.month != now.month ||
          _lastPlayDate!.day != now.day) {
        currentConsecutiveDays = 1;
      }
    } else {
      currentConsecutiveDays = 1;
    }

    _lastPlayDate = now;
    saveProgress();
  }

  void addCrystals(int amount) {
    if (amount != 0) {
      totalCrystals += amount;
      saveProgress();
    }
  }

  bool canLevelUp() => totalCrystals >= levelCrystalCost;

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

  void incrementStep() {
    currentStep++;
    updateConsecutiveDays();
    saveProgress();
  }

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
      'usedWords': _usedWords.toList(),
      'usedSentences': _usedSentences.toList(),
      'gameData': _gameData,
    };
  }

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
    _lastPlayDate = lastPlayDateStr != null && lastPlayDateStr.isNotEmpty
        ? DateTime.parse(lastPlayDateStr)
        : null;

    _usedWords = (json['usedWords'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    _usedSentences = (json['usedSentences'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    _gameData = (json['gameData'] as Map?)?.cast<String, dynamic>() ?? {};

    notifyListeners();
  }

  int _parseIntSafely(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  Future<void> saveProgress() async {
    if (_id.isNotEmpty) {
      final profileData = toJson();
      await _storageService.writeProfile(_id, profileData);
      notifyListeners();
    }
  }

  Future<bool> loadProgress() async {
    if (_id.isEmpty) return false;

    try {
      final profileData = await _storageService.readProfile(_id);
      if (profileData.isNotEmpty) {
        fromJson(profileData);
        return true;
      }
      return false;
    } catch (e) {
      print('Error loading progress: $e');
      return false;
    }
  }

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
    _usedWords.clear();
    _usedSentences.clear();
    _gameData.clear();
    notifyListeners();
  }

  Future<bool> hasProfile() async {
    if (_id.isEmpty) return false;
    return await _storageService.profileExists(_id);
  }
}