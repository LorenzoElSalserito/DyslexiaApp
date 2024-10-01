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

  static const Map<int, int> baseLevelCrystalCosts = {
    1: 300,
    2: 1500,
    3: 5000,
    4: 10000,
  };

  int get levelCrystalCost => (baseLevelCrystalCosts[currentLevel] ?? 0) * (newGamePlusCount + 1);

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
    newGamePlusCount = 0;
    usedWords.clear();
    usedSentences.clear();
    await saveProgress();
    notifyListeners();
  }

  void addCrystals(int amount) {
    totalCrystals += amount;
    notifyListeners();
    saveProgress();
  }

  bool canLevelUp() {
    return totalCrystals >= levelCrystalCost;
  }

  void levelUp() {
    if (canLevelUp() || isAdmin) {
      if (!isAdmin) {
        totalCrystals -= levelCrystalCost;
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

  Future<bool> loadProgress() async {
    try {
      final profileData = await _storageService.readProfile();
      if (profileData.isNotEmpty) {
        name = profileData['name'] as String? ?? '';
        surname = profileData['surname'] as String? ?? '';
        matricola = profileData['matricola'] as String? ?? '';
        corso = profileData['corso'] as String? ?? '';
        totalCrystals = int.tryParse(profileData['totalCrystals'] as String? ?? '0') ?? 0;
        currentLevel = int.tryParse(profileData['currentLevel'] as String? ?? '1') ?? 1;
        currentStep = int.tryParse(profileData['currentStep'] as String? ?? '0') ?? 0;
        isAdmin = (profileData['isAdmin'] as String? ?? 'false') == 'true';
        newGamePlusCount = int.tryParse(profileData['newGamePlusCount'] as String? ?? '0') ?? 0;

        final usedWordsString = profileData['usedWords'] as String? ?? '';
        usedWords = usedWordsString.split(',').where((w) => w.isNotEmpty).toSet();

        final usedSentencesString = profileData['usedSentences'] as String? ?? '';
        usedSentences = usedSentencesString.split('|').where((s) => s.isNotEmpty).toSet();

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error loading progress: $e');
      return false;
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