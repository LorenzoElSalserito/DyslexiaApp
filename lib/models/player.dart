import 'package:flutter/foundation.dart';
import '../services/file_storage_service.dart';

class Player with ChangeNotifier {
  final FileStorageService _storageService = FileStorageService();

  String name = '';
  String surname = '';
  String matricola = '';
  String corso = '';
  int totalCrystals = 0;
  int currentLevel = 1;
  int currentStep = 0;
  bool isAdmin = false;
  int newGamePlusCount = 0;
  Set<String> usedWords = {};
  Set<String> usedSentences = {};

  static const Map<int, int> levelCrystalCosts = {
    1: 300,
    2: 1500,
    3: 5000,
    4: 10000,
  };

  Player() {
    loadProgress();
  }

  Future<void> setPlayerInfo(String name, String surname, String matricola, String corso) async {
    this.name = name;
    this.surname = surname;
    this.matricola = matricola;
    this.corso = corso;
    totalCrystals = 0;
    currentLevel = 1;
    currentStep = 0;
    isAdmin = (name.toLowerCase() == 'admin');
    await saveProgress();
    notifyListeners();
  }

  void addCrystals(int amount) {
    totalCrystals += amount;
    notifyListeners();
    saveProgress();
  }

  bool canLevelUp() {
    return totalCrystals >= levelCrystalCosts[currentLevel]!;
  }

  void levelUp() {
    if (canLevelUp() || isAdmin) {
      if (!isAdmin) {
        totalCrystals -= levelCrystalCosts[currentLevel]!;
      }
      currentLevel++;
      currentStep = 0;
      notifyListeners();
      saveProgress();
    }
  }

  void incrementStep() {
    currentStep++;
    notifyListeners();
    saveProgress();
  }

  void addUsedWord(String word) {
    usedWords.add(word);
    saveProgress();
  }

  void addUsedSentence(String sentence) {
    usedSentences.add(sentence);
    saveProgress();
  }

  void startNewGamePlus() {
    newGamePlusCount++;
    currentLevel = 1;
    currentStep = 0;
    usedWords.clear();
    usedSentences.clear();
    notifyListeners();
    saveProgress();
  }

  Future<void> saveProgress() async {
    await _storageService.writeProfile({
      'name': name,
      'surname': surname,
      'matricola': matricola,
      'corso': corso,
      'totalCrystals': totalCrystals.toString(),
      'currentLevel': currentLevel.toString(),
      'currentStep': currentStep.toString(),
      'isAdmin': isAdmin.toString(),
      'newGamePlusCount': newGamePlusCount.toString(),
      'usedWords': usedWords.join(','),
      'usedSentences': usedSentences.join('|'),
    });
  }

  Future<void> loadProgress() async {
    final profileData = await _storageService.readProfile();
    if (profileData.isNotEmpty) {
      name = profileData['name'] ?? '';
      surname = profileData['surname'] ?? '';
      matricola = profileData['matricola'] ?? '';
      corso = profileData['corso'] ?? '';
      totalCrystals = int.parse(profileData['totalCrystals'] ?? '0');
      currentLevel = int.parse(profileData['currentLevel'] ?? '1');
      currentStep = int.parse(profileData['currentStep'] ?? '0');
      isAdmin = profileData['isAdmin'] == 'true';
      newGamePlusCount = int.parse(profileData['newGamePlusCount'] ?? '0');
      usedWords = Set<String>.from((profileData['usedWords'] ?? '').split(',').where((w) => w.isNotEmpty));
      usedSentences = Set<String>.from((profileData['usedSentences'] ?? '').split('|').where((s) => s.isNotEmpty));
      notifyListeners();
    }
  }

  Future<void> resetProgress() async {
    await _storageService.deleteProfile();
    name = '';
    surname = '';
    matricola = '';
    corso = '';
    totalCrystals = 0;
    currentLevel = 1;
    currentStep = 0;
    isAdmin = false;
    newGamePlusCount = 0;
    usedWords.clear();
    usedSentences.clear();
    notifyListeners();
  }

  Future<bool> hasProfile() async {
    return await _storageService.profileExists();
  }
}