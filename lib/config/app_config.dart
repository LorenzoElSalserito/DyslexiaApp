// app_config.dart

class AppConfig {
  // Configurazioni App
  static const String appName = 'DyslexiaHelper';
  static const String appVersion = '1.0.0';

  // Configurazioni VOSK
  static const String voskModelUrl = 'https://alphacephei.com/vosk/models/vosk-model-small-it-0.22.zip';
  static const String voskModelName = 'vosk-model-small-it';
  static const String voskModelVersion = '0.22';
  static const int vadAggressiveness = 3;   // 0-3 per la riduzione del rumore
  static const double vadThreshold = 0.5;   // Soglia per il VAD
  static const bool vadEnable = true;       // Voice Activity Detection
  static const bool noiseSuppressionEnable = true;  // Soppressione rumore
  static const bool autoGainControlEnable = true;   // Controllo guadagno

  // Configurazioni Audio
  static const int sampleRate = 32000;
  static const int channels = 1;
  static const int bufferSize = 4096;
  static const double volumeThreshold = 0.1;  // Volume minimo per considerare input valido
  static const double idealVolume = 0.5;      // Volume ideale per una buona registrazione
  static const double maxVolume = 1.0;        // Volume massimo possibile

  // Configurazioni Riconoscimento
  static const double minSimilarityScore = 0.85;
  static const double perfectSimilarityScore = 0.95;
  static const int maxRecordingDuration = 3600; // secondi
  static const int minRecordingDuration = 1;  // secondi

  // Configurazioni Game
  static const int basePointsWord = 1;
  static const int basePointsSentence = 2;
  static const int basePointsParagraph = 5;
  static const int basePointsPage = 10;

  // Configurazioni Feedback
  static const bool defaultVibrationEnabled = true;
  static const bool defaultSoundEnabled = true;
  static const bool defaultVisualEnabled = true;

  // Configurazioni Cache
  static const int maxCacheSize = 200 * 1024 * 1024; // 200 MB
  static const Duration cacheExpiration = Duration(days: 30);

  // Configurazioni Learning Analytics
  static const int maxStoredSessions = 20;
  static const int minSessionDuration = 60; // secondi
  static const int maxSessionDuration = 3900; // secondi

  // Configurazioni UI
  static const Duration animationDuration = Duration(milliseconds: 500);
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
  static const String wordsEasyPath = 'lib/assets/exercises/easy_words.txt';
  static const String wordsMediumPath = 'lib/assets/exercises/medium_words.txt';
  static const String wordsHardPath = 'lib/assets/exercises/hard_words.txt';
  static const String sentencesPath = 'lib/assets/exercises/sentences.txt';
  static const String paragraphsPath = 'lib/assets/exercises/paragraphs.txt';
  static const String pagesPath = 'lib/assets/exercises/pages.txt';

}