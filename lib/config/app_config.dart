// app_config.dart

class AppConfig {
  // Configurazioni App
  static const String appName = 'DyslexiaHelper';
  static const String appVersion = '1.0.0';

  // Configurazioni VOSK
  static const String voskModelUrl = 'https://alphacephei.com/vosk/models/vosk-model-small-it-0.22.zip';
  static const String voskModelName = 'vosk-model-small-it';
  static const String voskModelVersion = '0.22';

  // Configurazioni Audio
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bufferSize = 4096;

  // Configurazioni Riconoscimento
  static const double minSimilarityScore = 0.85;
  static const double perfectSimilarityScore = 0.95;
  static const int maxRecordingDuration = 30; // secondi
  static const int minRecordingDuration = 1;  // secondi

  // Configurazioni Game
  static const int basePointsWord = 10;
  static const int basePointsSentence = 30;
  static const int basePointsParagraph = 100;
  static const int basePointsPage = 200;

  // Configurazioni Feedback
  static const bool defaultVibrationEnabled = true;
  static const bool defaultSoundEnabled = true;
  static const bool defaultVisualEnabled = true;
  static const double volumeThreshold = 0.1;
  static const double maxVolume = 1.0;

  // Configurazioni Cache
  static const int maxCacheSize = 100 * 1024 * 1024; // 100 MB
  static const Duration cacheExpiration = Duration(days: 30);

  // Configurazioni Learning Analytics
  static const int maxStoredSessions = 50;
  static const int minSessionDuration = 60; // secondi
  static const int maxSessionDuration = 3600; // secondi

  // Configurazioni UI
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const double defaultFontSize = 18.0;
  static const double headerFontSize = 24.0;
  static const double buttonHeight = 48.0;
  static const double cardElevation = 4.0;

  // Supporto per New Game+
  static const Map<int, double> newGamePlusMultipliers = {
    1: 1.5,
    2: 2.0,
    3: 2.5,
    4: 3.0,
  };

  // Path delle risorse
  static const String wordsPath = 'lib/assets/words.txt';
  static const String sentencesPath = 'lib/assets/sentences.txt';
  static const String paragraphsPath = 'lib/assets/paragraphs.txt';
  static const String pagesPath = 'lib/assets/pages.txt';

  // Configurazioni Crystal
  static const Map<int, int> baseLevelCrystalCosts = {
    1: 300,
    2: 1500,
    3: 5000,
    4: 10000,
  };
}