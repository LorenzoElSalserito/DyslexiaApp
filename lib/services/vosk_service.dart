import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import '../models/recognition_result.dart';
import '../config/app_config.dart';
import '../utils/permission_handler.dart';
import 'permission_service.dart';
import 'audio_service.dart';
import '../utils/desktop_permission.dart';


/// Servizio per il riconoscimento vocale utilizzando VOSK.
/// Legge il file WAV (con header) e passa direttamente il buffer dei byte
/// al recognizer tramite acceptWaveformBytes(), per poi ottenere il risultato
/// con getFinalResult().
class VoskService {
  static final VoskService _instance = VoskService._internal();
  static VoskService get instance => _instance;

  VoskFlutterPlugin? _recognizer;
  Model? _model;
  Recognizer? _speechRecognizer;
  SpeechService? _speechService;

  final PermissionService _permissionService = PermissionService();
  final AudioService _audioService = AudioService();

  bool _isInitialized = false;
  String _modelPath = '';
  bool _isProcessing = false;

  static const List<String> _requiredFiles = [
    'am/final.mdl',
    'conf/mfcc.conf',
    'conf/model.conf',
    'graph/Gr.fst',
    'graph/HCLr.fst',
    'graph/disambig_tid.int',
    'graph/phones/word_boundary.int',
    'ivector/final.dubm',
    'ivector/final.ie',
    'ivector/final.mat',
    'ivector/global_cmvn.stats',
    'ivector/online_cmvn.conf',
    'ivector/splice.conf',
  ];

  final List<String> _serviceLog = [];
  static const int _maxInitAttempts = 3;

  // Mappa per errori comuni (usata nelle funzioni di similarità)
  static const Map<String, List<String>> _commonDyslexicConfusions = {
    'b': ['d', 'p'],
    'd': ['b', 'q'],
    'p': ['q', 'b'],
    'q': ['p', 'd'],
    'm': ['n', 'w'],
    'n': ['m'],
    'a': ['e'],
    'e': ['a'],
    's': ['z'],
    'z': ['s'],
    'f': ['v'],
    'v': ['f'],
  };

  VoskService._internal() {
    _logEvent('VoskService inizializzato');
    _initAudioService();
  }

  /// Inizializza il servizio audio.
  void _initAudioService() {
    if (!_audioService.isInitialized) {
      _audioService.initialize();
    }
  }

  /// Registra un evento con timestamp nei log.
  void _logEvent(String event) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $event';
    debugPrint('VoskService: $logEntry');
    _serviceLog.add(logEntry);
    if (_serviceLog.length > 1000) _serviceLog.removeAt(0);
  }

  /// Inizializza il servizio VOSK e prepara il modello.
  Future<void> initialize({required BuildContext context}) async {
    if (_isInitialized) {
      _logEvent('Servizio già inizializzato');
      return;
    }
    int attempts = 0;
    bool success = false;
    while (!success && attempts < _maxInitAttempts) {
      try {
        attempts++;
        _logEvent('Tentativo di inizializzazione #$attempts');
        await _initializeWithRetry(context: context);
        success = true;
      } catch (e, stackTrace) {
        _logEvent('Errore nel tentativo #$attempts: $e');
        _logEvent('Stack trace: $stackTrace');
        if (attempts >= _maxInitAttempts) {
          throw Exception('Impossibile inizializzare VOSK dopo $_maxInitAttempts tentativi');
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _initializeWithRetry({required BuildContext context}) async {
    _logEvent('Inizio inizializzazione con retry');

    // Verifica permessi su mobile o desktop
    if (Platform.isAndroid || Platform.isIOS) {
      // Prima richiedi il permesso di storage, poi quello del microfono
      bool hasStoragePermission = await PermissionsHandler.requestStoragePermission();
      if (!hasStoragePermission) {
        _logEvent('ERRORE: Permesso di storage non concesso');
        throw Exception('Permesso di storage non concesso');
      }

      bool hasMicrophonePermission = await PermissionsHandler.requestMicrophonePermission();
      if (!hasMicrophonePermission) {
        _logEvent('ERRORE: Permesso del microfono non concesso');
        throw Exception('Permesso del microfono non concesso');
      }

      _logEvent('Permessi concessi: Storage e Microfono');
    } else {
      // Su desktop
      final hasAudioAccess = await DesktopPermission.checkMicrophoneAccess();
      final hasStorageAccess = await DesktopPermission.requestStorageAccess();

      if (!hasAudioAccess) {
        _logEvent('ERRORE: Permesso audio non disponibile su Desktop');
        throw Exception('Permesso audio non disponibile su Desktop');
      }

      if (!hasStorageAccess) {
        _logEvent('ERRORE: Permesso storage non disponibile su Desktop');
        throw Exception('Permesso storage non disponibile su Desktop');
      }

      _logEvent('Permessi desktop verificati: Audio=$hasAudioAccess, Storage=$hasStorageAccess');
    }

    // Trova il percorso del modello e verifica la sua integrità.
    _modelPath = await _findModelPath();
    _logEvent('Percorso del modello impostato: $_modelPath');
    if (!await _verifyModelIntegrity(_modelPath)) {
      throw Exception('Integrità del modello non verificata in $_modelPath');
    }

    _logEvent('Inizializzazione componenti VOSK');
    _recognizer = VoskFlutterPlugin.instance();
    _model = await _recognizer!.createModel(_modelPath);
    _speechRecognizer = await _recognizer!.createRecognizer(
      model: _model!,
      sampleRate: AppConfig.sampleRate,
    );

    if (Platform.isAndroid || Platform.isIOS) {
      _logEvent('Initializing SpeechService (mobile)...');
      _speechService = await _recognizer!.initSpeechService(_speechRecognizer!);
    } else {
      _logEvent("Saltata initSpeechService su Desktop platforms.");
      _speechService = null;
    }

    if (_speechRecognizer != null) {
      await _speechRecognizer!.setMaxAlternatives(3);
      await _speechRecognizer!.setPartialWords(partialWords: true);
      await _speechRecognizer!.setWords(words: true);
    }

    _isInitialized = true;
    _logEvent('Inizializzazione completata con successo');
  }

  /// Trova il percorso del modello VOSK.
  Future<String> _findModelPath() async {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return path.join(Directory.current.path, 'assets', 'vosk');
      }
      final appDocDir = await getApplicationDocumentsDirectory();
      final modelDirPath = path.join(appDocDir.path, 'vosk');
      final modelDir = Directory(modelDirPath);
      if (!await modelDir.exists()) {
        _logEvent('Cartella modello non esistente. Creazione e copia degli asset...');
        await modelDir.create(recursive: true);
        for (final assetFile in _requiredFiles) {
          final assetPath = path.join('vosk', assetFile);
          try {
            final byteData = await rootBundle.load(assetPath);
            final targetFile = File(path.join(modelDirPath, assetFile));
            await targetFile.parent.create(recursive: true);
            await targetFile.writeAsBytes(byteData.buffer.asUint8List());
            _logEvent('Asset copiato: $assetFile');
          } catch (e) {
            _logEvent('Errore nella copia dell\'asset $assetFile: $e');
          }
        }
      } else {
        _logEvent('Cartella modello già esistente: $modelDirPath');
      }
      return modelDirPath;
    } catch (e) {
      _logEvent('Errore nella ricerca del modello: $e');
      rethrow;
    }
  }

  /// Verifica l'integrità del modello controllando la presenza di tutti i file richiesti.
  Future<bool> _verifyModelIntegrity(String modelPath) async {
    debugPrint('VoskService: Verifica integrità modello in: $modelPath');
    try {
      for (final file in _requiredFiles) {
        final fullPath = path.join(modelPath, file);
        if (!await File(fullPath).exists()) {
          debugPrint('VoskService: File mancante: $file');
          return false;
        }
        debugPrint('VoskService: File presente: $file');
      }
      debugPrint('VoskService: Verifica integrità completata con successo');
      return true;
    } catch (e) {
      debugPrint('VoskService: Errore nella verifica integrità: $e');
      return false;
    }
  }

  /// Avvia il riconoscimento vocale reale.
  /// Legge il file WAV (con header) e passa direttamente il buffer dei byte al recognizer.
  Future<RecognitionResult> startRecognition(String targetText, [String? audioPath]) async {
    _logEvent('Avvio riconoscimento vocale per target: $targetText');
    if (!_isInitialized) {
      throw Exception('VoskService non inizializzato');
    }
    if (_isProcessing) {
      throw Exception('Processo di riconoscimento già in corso');
    }
    final startTime = DateTime.now();
    _isProcessing = true;
    try {
      String pathToProcess = audioPath ?? "";
      if (pathToProcess.isEmpty) {
        // Avvia la registrazione tramite AudioService.
        pathToProcess = await _audioService.startRecording()
            .timeout(const Duration(seconds: 10), onTimeout: () {
          _logEvent('Timeout nell\'avvio della registrazione');
          throw Exception('Timeout nell\'avvio della registrazione');
        });
        if (pathToProcess.isEmpty) {
          _logEvent('Percorso registrazione vuoto');
          throw Exception('Registrazione audio fallita');
        }
        await Future.delayed(const Duration(seconds: 3))
            .timeout(const Duration(seconds: 10), onTimeout: () {
          _logEvent('Timeout nella durata della registrazione');
          throw Exception('Timeout nella durata della registrazione');
        });
        await _audioService.stopRecording()
            .timeout(const Duration(seconds: 5), onTimeout: () {
          _logEvent('Timeout nello stop della registrazione');
          throw Exception('Timeout nello stop della registrazione');
        });
      }

      _logEvent('Lettura file audio da: $pathToProcess');
      final bytes = await File(pathToProcess).readAsBytes();
      if (bytes.isEmpty) {
        _logEvent('Nessun dato audio valido');
        throw Exception('Nessun dato audio valido');
      }

      _logEvent('Invio a VOSK dei byte audio (${bytes.length} byte) in una singola chiamata');
      await _speechRecognizer!.acceptWaveformBytes(bytes)
          .timeout(const Duration(seconds: AppConfig.maxRecordingDuration), onTimeout: () {
        _logEvent('Timeout nell\'accettazione dei byte del waveform');
        throw Exception('Timeout nell\'accettazione dei byte del waveform');
      });

      // Richiede direttamente il risultato finale.
      final resultJson = await _speechRecognizer!.getFinalResult()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        _logEvent('Timeout nell\'ottenimento del risultato finale');
        throw Exception('Timeout nel risultato finale');
      });

      _logEvent('Elaborazione VOSK completata');
      _logEvent('Risultato raw da VOSK: $resultJson');

      final cleanJson = _cleanJsonFormat(resultJson);
      Map<String, dynamic> jsonResult;
      try {
        jsonResult = jsonDecode(cleanJson);
      } catch (jsonError) {
        debugPrint('VoskService: Errore nel parsing JSON: $jsonError');
        throw Exception('Errore nel parsing JSON: $jsonError');
      }

      double totalConfidence = 0.0;
      String recognizedText = '';

      // Gestione del caso in cui il JSON contiene "alternatives"
      if (jsonResult.containsKey('alternatives')) {
        final List<dynamic> alternatives = jsonResult['alternatives'];
        if (alternatives.isNotEmpty) {
          final alt = alternatives[0];
          if (alt is Map && alt.containsKey('text')) {
            recognizedText = (alt['text'] as String?)?.trim() ?? '';
          }
          if (alt is Map && alt.containsKey('confidence')) {
            try {
              var conf = alt['confidence'];
              if (conf is num) {
                totalConfidence = conf.toDouble();
              } else if (conf is String) {
                totalConfidence = double.tryParse(conf.replaceAll(',', '.')) ?? 0.0;
              }
            } catch (e) {
              totalConfidence = 0.2;
            }
          }
        }
      }
      // Se non ho ottenuto un risultato da "alternatives", controllo "result" oppure "text"
      else if (jsonResult.containsKey('result')) {
        final List<dynamic> words = jsonResult['result'];
        for (var word in words) {
          if (word is Map && word.containsKey('word')) {
            recognizedText += '${word['word']} ';
            if (word.containsKey('conf')) {
              try {
                var conf = word['conf'];
                if (conf is num) {
                  totalConfidence += conf.toDouble();
                } else if (conf is String) {
                  totalConfidence += double.tryParse(conf.replaceAll(',', '.')) ?? 0.0;
                }
              } catch (e) {
                debugPrint('VoskService: Errore nell\'estrazione della confidenza: $e');
              }
            }
          }
        }
        recognizedText = recognizedText.trim();
        totalConfidence = words.isEmpty ? 0.0 : totalConfidence / words.length;
      } else if (jsonResult.containsKey('text')) {
        recognizedText = (jsonResult['text'] as String?)?.trim() ?? '';
        totalConfidence = 0.2;
      } else {
        recognizedText = '';
        totalConfidence = 0.0;
      }

      if (totalConfidence > 1.0) {
        totalConfidence = totalConfidence / 100.0;
      }
      if (totalConfidence <= 0) {
        totalConfidence = 0.1;
      }

      if (recognizedText.isEmpty) {
        _logEvent('Nessun testo riconosciuto da VOSK');
        throw Exception('Riconoscimento fallito: nessun testo riconosciuto');
      }

      final similarity = _calculateTextSimilarity(
          recognizedText.toLowerCase(), targetText.toLowerCase());
      final isCorrect = similarity >= AppConfig.minSimilarityScore;

      return RecognitionResult(
        text: recognizedText,
        confidence: totalConfidence,
        similarity: similarity,
        isCorrect: isCorrect,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      _logEvent('Errore nel riconoscimento: $e');
      rethrow;
    } finally {
      _isProcessing = false;
    }
  }

  String _cleanJsonFormat(String jsonString) {
    var result = jsonString;
    result = result.replaceAllMapped(RegExp(r'(\d+),(\d+)'), (match) {
      final parts = match.group(0)!.split(',');
      return "${parts[0]}.${parts[1]}";
    });
    result = result.replaceAll("'", '"');
    result = result.replaceAll("NaN", "0");
    result = result.replaceAll("Infinity", "999999");
    result = result.replaceAll(RegExp(r'[\u0000-\u001F]'), '');
    return result;
  }

  double _calculateTextSimilarity(String text1, String text2) {
    if (text1 == text2) return 1.0;
    if (text1.isEmpty || text2.isEmpty) return 0.0;
    const double levenshteinWeight = 0.4;
    const double phoneticWeight = 0.3;
    const double confusionWeight = 0.3;
    double levenshteinScore = _calculateLevenshteinSimilarity(text1, text2);
    double phoneticScore = _calculatePhoneticSimilarity(text1, text2);
    double confusionScore = _calculateConfusionSimilarity(text1, text2);
    return (levenshteinScore * levenshteinWeight) +
        (phoneticScore * phoneticWeight) +
        (confusionScore * confusionWeight);
  }

  double _calculateConfusionSimilarity(String s1, String s2) {
    if (s1.length != s2.length) return 0.0;
    int matchCount = 0;
    for (int i = 0; i < s1.length; i++) {
      if (s1[i] == s2[i]) {
        matchCount++;
        continue;
      }
      if (_commonDyslexicConfusions.containsKey(s1[i]) &&
          _commonDyslexicConfusions[s1[i]]!.contains(s2[i])) {
        matchCount++;
      }
    }
    return matchCount / s1.length;
  }

  double _calculateLevenshteinSimilarity(String s1, String s2) {
    var matrix = List.generate(
      s1.length + 1,
          (i) => List.generate(s2.length + 1, (j) => j == 0 ? i : 0),
    );
    for (var j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }
    for (var i = 1; i <= s1.length; i++) {
      for (var j = 1; j <= s2.length; j++) {
        int cost = _calculateSubstitutionCost(s1[i - 1], s2[j - 1]);
        matrix[i][j] = min(
            matrix[i - 1][j] + 1,
            min(matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost));
        if (i > 1 &&
            j > 1 &&
            s1[i - 1] == s2[j - 2] &&
            s1[i - 2] == s2[j - 1]) {
          matrix[i][j] = min(matrix[i][j], matrix[i - 2][j - 2] + 1);
        }
      }
    }
    final maxLength = max(s1.length, s2.length);
    return 1.0 - (matrix[s1.length][s2.length] / maxLength);
  }

  int _calculateSubstitutionCost(String char1, String char2) {
    if (char1 == char2) return 0;
    if (_commonDyslexicConfusions.containsKey(char1) &&
        _commonDyslexicConfusions[char1]!.contains(char2)) {
      return 1;
    }
    return 2;
  }

  double _calculatePhoneticSimilarity(String s1, String s2) {
    String phonetic1 = _getPhoneticCode(s1);
    String phonetic2 = _getPhoneticCode(s2);
    return _calculateLevenshteinSimilarity(phonetic1, phonetic2);
  }

  String _getPhoneticCode(String text) {
    var result = text.toLowerCase();
    final Map<String, String> phoneticRules = {
      'chi': 'ki',
      'che': 'ke',
      'ghi': 'gi',
      'ghe': 'ge',
      'gn': 'ñ',
      'gl': 'ʎ',
      'sc': 'ʃ',
      'qu': 'k',
      'gu': 'g',
      'z': 'ts',
      'zz': 'ts',
    };
    for (var entry in phoneticRules.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    result = result.replaceAll(RegExp(r'([aeiou])\1+'), r'$1');
    return result;
  }

  List<String> getServiceLogs() => List.unmodifiable(_serviceLog);

  bool get isInitialized => _isInitialized;
  String get modelPath => _modelPath;
}
