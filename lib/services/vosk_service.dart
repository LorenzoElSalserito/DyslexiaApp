// lib/services/vosk_service.dart

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
import 'permission_service.dart';
import 'audio_service.dart';

/// Servizio per il riconoscimento vocale utilizzando VOSK.
/// Gestisce il caricamento del modello, la preparazione dei dati audio
/// e il processo di riconoscimento vocale.
class VoskService {
  // Singleton pattern
  static final VoskService _instance = VoskService._internal();
  static VoskService get instance => _instance;

  // Servizi e componenti VOSK
  VoskFlutterPlugin? _recognizer;
  Model? _model;
  Recognizer? _speechRecognizer;
  SpeechService? _speechService;

  // Servizi di supporto
  final PermissionService _permissionService = PermissionService();
  final AudioService _audioService = AudioService();

  // Stato del servizio
  bool _isInitialized = false;
  String _modelPath = '';
  double _currentVolume = 0.0;
  bool _isProcessing = false;

  // File richiesti dal modello VOSK
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

  // Log e tentativi
  final List<String> _serviceLog = [];
  static const int _maxInitAttempts = 3;

  // Mappa per la gestione degli errori comuni nella dislessia
  static const Map<String, List<String>> _commonDyslexicConfusions = {
    'b': ['d', 'p'],  // Confusione b/d/p
    'd': ['b', 'q'],  // Confusione d/b/q
    'p': ['q', 'b'],  // Confusione p/q/b
    'q': ['p', 'd'],  // Confusione q/p/d
    'm': ['n', 'w'],  // Confusione m/n/w
    'n': ['m'],       // Confusione n/m
    'a': ['e'],       // Confusione a/e
    'e': ['a'],       // Confusione e/a
    's': ['z'],       // Confusione s/z
    'z': ['s'],       // Confusione z/s
    'f': ['v'],       // Confusione f/v
    'v': ['f'],       // Confusione v/f
  };

  VoskService._internal() {
    _logEvent('VoskService inizializzato');
    _initAudioService();
  }

  /// Inizializza il servizio audio e imposta gli ascoltatori
  void _initAudioService() {
    if (!_audioService.isInitialized) {
      _audioService.initialize();
    }

    // Monitora il volume per la qualità dell'audio
    _audioService.volumeLevel.listen((volume) {
      _currentVolume = volume;
      _logEvent('Volume corrente: $volume');
    });
  }

  void _logEvent(String event) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $event';
    debugPrint('VoskService: $logEntry');
    _serviceLog.add(logEntry);
    if (_serviceLog.length > 1000) _serviceLog.removeAt(0);
  }

  /// Inizializza il servizio VOSK e prepara il modello
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

    // Verifica permessi
    bool hasPermissions = await _permissionService.checkAllPermissions();
    if (!hasPermissions) {
      hasPermissions = await _permissionService.requestAllPermissions(context);
      if (!hasPermissions) {
        throw Exception('Permessi necessari non concessi');
      }
    }

    // Prepara il modello
    _modelPath = await _findModelPath();
    _logEvent('Percorso del modello impostato: $_modelPath');

    if (!await _verifyModelIntegrity(_modelPath)) {
      throw Exception('Integrità del modello non verificata in $_modelPath');
    }

    // Inizializza componenti VOSK
    _logEvent('Inizializzazione componenti VOSK');
    _recognizer = VoskFlutterPlugin.instance();
    _model = await _recognizer!.createModel(_modelPath);
    _speechRecognizer = await _recognizer!.createRecognizer(
      model: _model!,
      sampleRate: AppConfig.sampleRate,
    );
    _speechService = await _recognizer!.initSpeechService(_speechRecognizer!);

    // Configura il riconoscitore
    if (_speechRecognizer != null) {
      await _speechRecognizer!.setMaxAlternatives(3);
      await _speechRecognizer!.setPartialWords(partialWords: true);
      await _speechRecognizer!.setWords(words: true);
    }

    _isInitialized = true;
    _logEvent('Inizializzazione completata con successo');
  }

  /// Trova il percorso del modello VOSK
  Future<String> _findModelPath() async {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return path.join(Directory.current.path, 'assets', 'vosk');
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final modelDirPath = path.join(appDocDir.path, 'vosk');
      final modelDir = Directory(modelDirPath);

      if (!await modelDir.exists()) {
        _logEvent('La cartella modello non esiste. Creazione e copia degli asset...');
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
            _logEvent('Errore durante la copia dell\'asset $assetFile: $e');
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

  /// Verifica l'integrità del modello VOSK
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
      debugPrint('VoskService: Verifica integrità modello completata con successo');
      return true;
    } catch (e) {
      debugPrint('VoskService: Errore nella verifica integrità: $e');
      return false;
    }
  }

  /// Preprocessa l'audio prima del riconoscimento e lo converte in Float32List
  Future<Float32List> _preprocessAudio(String audioPath) async {
    try {
      _logEvent('Preprocessamento audio da: $audioPath');
      final file = File(audioPath);

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        _logEvent('Audio caricato: ${bytes.length} byte');

        // Rimuovi l'header WAV (44 byte)
        final rawData = bytes.length > 44 ? bytes.sublist(44) : bytes;

        // Converti i dati raw in Float32List
        final int sampleCount = rawData.length ~/ 2; // 16-bit per campione
        final Float32List floatData = Float32List(sampleCount);

        // Processa i campioni come int16 e convertili in float32
        for (int i = 0; i < sampleCount; i++) {
          // Leggi due byte consecutivi (little endian)
          int low = rawData[i * 2] & 0xFF;
          int high = rawData[i * 2 + 1] & 0xFF;

          // Combina i byte in un int16
          int sample = (high << 8) | low;

          // Converti da int16 con segno (-32768 a 32767)
          if (sample >= 32768) {
            sample -= 65536;
          }

          // Normalizza in range [-1.0, 1.0]
          floatData[i] = sample / 32768.0;
        }

        // Applica riduzione del rumore se necessario
        if (AppConfig.noiseSuppressionEnable) {
          _applyNoiseReduction(floatData);
        }

        _logEvent('Audio convertito in Float32List: ${floatData.length} campioni');
        return floatData;
      } else {
        _logEvent('File audio non trovato: $audioPath');
        return Float32List(0);
      }
    } catch (e) {
      _logEvent('Errore nel preprocessamento audio: $e');
      return Float32List(0);
    }
  }

  /// Applica una semplice riduzione del rumore basata sulla soglia
  void _applyNoiseReduction(Float32List data) {
    // Soglia per il rumore di fondo (-60dB convertito in lineare)
    const double noiseThreshold = 0.001; // -60dB

    // Applica la soglia a ogni campione
    for (int i = 0; i < data.length; i++) {
      if (data[i].abs() < noiseThreshold) {
        data[i] = 0.0;
      }
    }
  }

  /// Esegue il riconoscimento vocale
  Future<RecognitionResult> startRecognition(String targetText) async {
    _logEvent('Avvio riconoscimento vocale per target: $targetText');

    if (!_isInitialized) {
      _logEvent('Servizio non inizializzato, chiamata initialize()');
      throw Exception('VoskService non inizializzato');
    }

    if (_isProcessing) {
      throw Exception('Processo di riconoscimento già in corso');
    }

    final startTime = DateTime.now();
    _isProcessing = true;

    try {
      final audioPath = await _audioService.startRecording();
      if (audioPath.isEmpty) {
        throw Exception('Percorso registrazione non valido');
      }

      // Attendi il completamento della registrazione
      await Future.delayed(const Duration(seconds: AppConfig.maxRecordingDuration));
      await _audioService.stopRecording();

      // Preprocessa l'audio
      final audioData = await _preprocessAudio(audioPath);
      if (audioData.isEmpty) {
        _logEvent('Nessun dato audio valido');
        return _createEmptyResult(startTime);
      }

      // Esegui il riconoscimento utilizzando i dati in formato float
      await _speechRecognizer!.acceptWaveformFloats(audioData);
      final resultJson = await _speechRecognizer!.getFinalResult();

      _logEvent('Elaborazione VOSK completata');
      _logEvent('Risultato raw da VOSK: $resultJson');

      final Map<String, dynamic> result = jsonDecode(resultJson);
      double totalConfidence = 0.0;
      String recognizedText = '';

      if (result.containsKey('result')) {
        final List<dynamic> words = result['result'] as List<dynamic>;
        for (var word in words) {
          recognizedText += '${word['word']} ';
          totalConfidence += (word['conf'] as num).toDouble();
        }
        recognizedText = recognizedText.trim();
        totalConfidence = words.isEmpty ? 0.0 : totalConfidence / words.length;
      } else if (result.containsKey('text')) {
        recognizedText = result['text'];
        totalConfidence = 1.0;
      } else {
        _logEvent('Nessun risultato dal riconoscimento');
        return _createEmptyResult(startTime);
      }

      return _createResult(
        recognizedText,
        targetText,
        totalConfidence,
        DateTime.now().difference(startTime),
      );

    } catch (e) {
      _logEvent('Errore nel riconoscimento: $e');
      return _createEmptyResult(startTime);
    } finally {
      _isProcessing = false;
    }
  }

  /// Crea un risultato di riconoscimento da testo e target
  RecognitionResult _createResult(
      String recognized,
      String target,
      double confidence,
      Duration duration
      ) {
    final normalizedRecognized = recognized.toLowerCase().trim();
    final normalizedTarget = target.toLowerCase().trim();
    final similarity = _calculateTextSimilarity(normalizedRecognized, normalizedTarget);
    final isCorrect = similarity >= AppConfig.minSimilarityScore;

    _logEvent('Risultato finale: "$normalizedRecognized", Similarità: $similarity');

    return RecognitionResult(
      text: normalizedRecognized,
      confidence: confidence,
      similarity: similarity,
      isCorrect: isCorrect,
      duration: duration,
    );
  }

  /// Crea un risultato vuoto
  RecognitionResult _createEmptyResult(DateTime startTime) {
    return RecognitionResult(
      text: '',
      confidence: 0.0,
      similarity: 0.0,
      isCorrect: false,
      duration: DateTime.now().difference(startTime),
    );
  }

  /// Calcola la similarità tra due testi considerando gli errori comuni della dislessia
  double _calculateTextSimilarity(String text1, String text2) {
    if (text1 == text2) return 1.0;
    if (text1.isEmpty || text2.isEmpty) return 0.0;

    // Pesi per i diversi tipi di similarità
    const double levenshteinWeight = 0.4;   // Peso per la distanza di Levenshtein
    const double phoneticWeight = 0.3;      // Peso per la similarità fonetica
    const double confusionWeight = 0.3;     // Peso per gli errori comuni

    // Calcola la similarità di Levenshtein con gestione errori dislessia
    double levenshteinScore = _calculateLevenshteinSimilarity(text1, text2);

    // Calcola la similarità fonetica
    double phoneticScore = _calculatePhoneticSimilarity(text1, text2);

    // Calcola punteggio per errori comuni
    double confusionScore = _calculateConfusionSimilarity(text1, text2);

    // Combina i punteggi pesati
    return (levenshteinScore * levenshteinWeight) +
        (phoneticScore * phoneticWeight) +
        (confusionScore * confusionWeight);
  }

  /// Calcola la similarità basata sugli errori comuni della dislessia
  double _calculateConfusionSimilarity(String s1, String s2) {
    if (s1.length != s2.length) return 0.0;

    int matchCount = 0;
    for (int i = 0; i < s1.length; i++) {
      if (s1[i] == s2[i]) {
        matchCount++;
        continue;
      }

      // Verifica se le lettere sono comunemente confuse
      if (_commonDyslexicConfusions.containsKey(s1[i]) &&
          _commonDyslexicConfusions[s1[i]]!.contains(s2[i])) {
        matchCount++;
      }
    }

    return matchCount / s1.length;
  }

  /// Calcola la similarità di Levenshtein considerando gli errori comuni della dislessia
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
            matrix[i - 1][j] + 1,          // deletion
            min(
                matrix[i][j - 1] + 1,        // insertion
                matrix[i - 1][j - 1] + cost  // substitution
            )
        );

        // Gestione trasposizioni (es: "teh" vs "the")
        if (i > 1 && j > 1 &&
            s1[i - 1] == s2[j - 2] &&
            s1[i - 2] == s2[j - 1]) {
          matrix[i][j] = min(
              matrix[i][j],
              matrix[i - 2][j - 2] + 1
          );
        }
      }
    }

    final maxLength = max(s1.length, s2.length);
    return 1.0 - (matrix[s1.length][s2.length] / maxLength);
  }

  /// Calcola il costo di sostituzione considerando gli errori comuni della dislessia
  int _calculateSubstitutionCost(String char1, String char2) {
    if (char1 == char2) return 0;

    // Verifica se le lettere sono comunemente confuse nella dislessia
    if (_commonDyslexicConfusions.containsKey(char1) &&
        _commonDyslexicConfusions[char1]!.contains(char2)) {
      return 1;  // Costo ridotto per errori comuni
    }

    return 2;  // Costo standard per altre sostituzioni
  }

  /// Calcola la similarità fonetica utilizzando una versione semplificata dell'algoritmo italiano
  double _calculatePhoneticSimilarity(String s1, String s2) {
    String phonetic1 = _getPhoneticCode(s1);
    String phonetic2 = _getPhoneticCode(s2);

    // Usa Levenshtein sui codici fonetici
    return _calculateLevenshteinSimilarity(phonetic1, phonetic2);
  }

  /// Converte il testo in una rappresentazione fonetica semplificata
  String _getPhoneticCode(String text) {
    var result = text.toLowerCase();

    // Regole fonetiche italiane
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
      'z': 'ts',  // Per z sorda
      'zz': 'ts', // Per z sorda doppia
    };

    // Applica le regole fonetiche in ordine
    for (var entry in phoneticRules.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    // Rimuovi le vocali duplicate
    result = result.replaceAll(RegExp(r'([aeiou])\1+'), r'$1');

    return result;
  }

  /// Fornisce feedback dettagliato sugli errori commessi
  String _getDetailedFeedback(String recognized, String target) {
    List<String> feedback = [];

    // Individua errori di inversione
    if (_hasLetterInversions(recognized, target)) {
      feedback.add("Attenzione alle inversioni di lettere");
    }

    // Individua confusioni comuni
    var confusions = _findCommonConfusions(recognized, target);
    if (confusions.isNotEmpty) {
      feedback.add("Fai attenzione a distinguere: ${confusions.join(', ')}");
    }

    // Se non ci sono errori specifici
    if (feedback.isEmpty) {
      feedback.add("Ottimo lavoro! Continua così!");
    }

    return feedback.join(". ");
  }

  /// Verifica se ci sono inversioni di lettere
  bool _hasLetterInversions(String s1, String s2) {
    for (int i = 0; i < s1.length - 1; i++) {
      if (i < s2.length - 1 &&
          s1[i] == s2[i + 1] &&
          s1[i + 1] == s2[i]) {
        return true;
      }
    }
    return false;
  }

  /// Trova le confusioni di lettere comuni nel testo
  Set<String> _findCommonConfusions(String s1, String s2) {
    Set<String> confusions = {};

    for (int i = 0; i < s1.length; i++) {
      if (i < s2.length &&
          _commonDyslexicConfusions.containsKey(s1[i]) &&
          _commonDyslexicConfusions[s1[i]]!.contains(s2[i])) {
        confusions.add("${s1[i]}-${s2[i]}");
      }
    }

    return confusions;
  }

  // Getters pubblici
  bool get isInitialized => _isInitialized;
  String get modelPath => _modelPath;
  List<String> getServiceLogs() => List.unmodifiable(_serviceLog);
}