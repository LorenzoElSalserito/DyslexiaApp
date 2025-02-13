// lib/services/vosk_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:vosk_flutter/vosk_flutter.dart';
import '../models/recognition_result.dart';
import '../utils/text_similarity.dart';
import '../config/app_config.dart';
import 'permission_service.dart';

/// VoskService gestisce l'interazione con il motore di riconoscimento vocale VOSK.
/// Implementa il pattern Singleton per garantire un'unica istanza del servizio e
/// utilizza un modello locale per il riconoscimento vocale.
class VoskService {
  // Pattern Singleton
  static VoskService? _instance;

  // Componenti VOSK
  VoskFlutterPlugin? _recognizer;
  Model? _model;
  Recognizer? _speechRecognizer;
  SpeechService? _speechService;

  // Servizi di supporto
  final PermissionService _permissionService = PermissionService();

  // Stato del servizio
  bool _isInitialized = false;
  bool _isSimulatedMode = false;
  String _modelPath = '';
  StreamSubscription? _resultSubscription;
  StreamSubscription? _partialSubscription;

  // Buffer per i log del servizio
  final List<String> _serviceLog = [];

  // Numero massimo di tentativi di inizializzazione
  static const int _maxInitAttempts = 3;

  /// Ottiene l'istanza singleton del servizio
  static VoskService get instance {
    _instance ??= VoskService._();
    return _instance!;
  }

  /// Costruttore privato per il singleton
  VoskService._() {
    _logEvent('VoskService inizializzato');
  }

  /// Registra un evento nel log del servizio con timestamp
  void _logEvent(String event) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $event';
    debugPrint('VoskService: $logEntry');
    _serviceLog.add(logEntry);

    // Mantiene solo gli ultimi 1000 log
    if (_serviceLog.length > 1000) {
      _serviceLog.removeAt(0);
    }
  }

  /// Verifica se il riconoscimento vocale VOSK è supportato sulla piattaforma
  bool _isVoskSupported() {
    _logEvent('Verifica supporto VOSK');
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Inizializza il servizio e prepara il modello di riconoscimento vocale
  Future<void> initialize({BuildContext? context}) async {
    if (_isInitialized) {
      _logEvent('Servizio già inizializzato');
      return;
    }

    int attempts = 0;
    bool success = false;

    // Se il riconoscimento vocale non è supportato, attiva la modalità simulata
    if (!_isVoskSupported()) {
      _isSimulatedMode = true;
      _isInitialized = true;
      _logEvent('Modalità simulata attivata per piattaforma non supportata');
      return;
    }

    while (!success && attempts < _maxInitAttempts) {
      try {
        attempts++;
        _logEvent('Tentativo di inizializzazione #$attempts');
        await _initializeWithRetry(context);
        success = true;
      } catch (e, stackTrace) {
        _logEvent('Errore nel tentativo #$attempts: $e');
        _logEvent('Stack trace: $stackTrace');

        if (attempts >= _maxInitAttempts) {
          _isSimulatedMode = true;
          _isInitialized = true;
          _logEvent('Fallback a modalità simulata dopo errori di inizializzazione');
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Implementa la logica di inizializzazione con retry
  Future<void> _initializeWithRetry(BuildContext? context) async {
    _logEvent('Inizio inizializzazione con retry');

    // Verifica dei permessi necessari
    bool hasPermissions;
    if (context != null) {
      _logEvent('Richiesta permessi con context');
      hasPermissions = await _permissionService.requestAllPermissions(context);
    } else {
      _logEvent('Verifica permessi senza context');
      hasPermissions = await _permissionService.checkAllPermissions();
    }

    if (!hasPermissions) {
      throw Exception('Permessi necessari non concessi');
    }

    _logEvent('Ricerca del modello VOSK locale');
    _modelPath = await _findModelPath();
    _logEvent('Modello trovato in: $_modelPath');

    if (!await _verifyModelIntegrity(_modelPath)) {
      throw Exception('Integrità del modello non verificata');
    }

    _logEvent('Inizializzazione componenti VOSK');
    if (!_isSimulatedMode) {
      _recognizer = VoskFlutterPlugin.instance();
      _model = await _recognizer!.createModel(_modelPath);
      _speechRecognizer = await _recognizer!.createRecognizer(
        model: _model!,
        sampleRate: AppConfig.sampleRate,
      );
      _speechService = await _recognizer!.initSpeechService(_speechRecognizer!);
    }

    _isInitialized = true;
    _logEvent('Inizializzazione completata con successo');
  }

  /// Trova il percorso del modello VOSK
  Future<String> _findModelPath() async {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return path.join(Directory.current.path, 'linux', 'third_party', 'vosk');
      }

      final executableDir = File(Platform.resolvedExecutable).parent;
      final modelDir = path.join(executableDir.path, 'lib', 'vosk');

      if (!await Directory(modelDir).exists()) {
        throw Exception('Modello VOSK non trovato nel percorso di installazione');
      }

      return modelDir;
    } catch (e) {
      _logEvent('Errore nella ricerca del modello: $e');
      rethrow;
    }
  }

  /// Verifica l'integrità del modello VOSK
  Future<bool> _verifyModelIntegrity(String modelDir) async {
    _logEvent('Verifica integrità modello in: $modelDir');

    try {
      final requiredFiles = ['am/final.mdl', 'conf/mfcc.conf', 'graph/HCLr.fst'];
      for (final file in requiredFiles) {
        final fullPath = path.join(modelDir, file);
        if (!await File(fullPath).exists()) {
          _logEvent('File mancante: $file');
          return false;
        }
      }
      _logEvent('Integrità modello verificata');
      return true;
    } catch (e) {
      _logEvent('Errore nella verifica integrità: $e');
      return false;
    }
  }

  /// Avvia una sessione di riconoscimento vocale
  Future<RecognitionResult> startRecognition(String targetText) async {
    _logEvent('Avvio riconoscimento vocale per target: $targetText');

    if (!_isInitialized) {
      _logEvent('Servizio non inizializzato, chiamata initialize()');
      await initialize();
    }

    final startTime = DateTime.now();
    final completer = Completer<RecognitionResult>();

    if (_isSimulatedMode) {
      _logEvent('Modalità simulata attivata: generazione risultato simulato');
      await Future.delayed(const Duration(seconds: 2));
      final result = _generateSimulatedResult(targetText);
      completer.complete(result);
      return completer.future;
    }

    try {
      if (_speechService == null) {
        throw Exception('Speech service non inizializzato');
      }

      _logEvent('Configurazione listeners per riconoscimento vocale');
      _partialSubscription = _speechService!.onPartial().listen(
            (Map<String, dynamic> partial) {
          final partialText = partial['partial'] as String? ?? '';
          _logEvent('Risultato parziale: $partialText');
        },
        onError: (error) {
          _logEvent('Errore nel risultato parziale: $error');
        },
      );

      _resultSubscription = _speechService!.onResult().listen(
            (Map<String, dynamic> result) {
          final duration = DateTime.now().difference(startTime);
          if (duration > const Duration(hours: 1)) {
            _logEvent('Durata audio ($duration) superiore a 60 minuti. Abort processing.');
            if (!completer.isCompleted) {
              completer.completeError(Exception('Audio file too long. Processing aborted.'));
            }
            return;
          }
          final recognizedText = result['text'] as String? ?? '';
          final similarity = TextSimilarity.calculateSimilarity(recognizedText, targetText);
          final recognitionResult = RecognitionResult(
            text: recognizedText,
            confidence: result['confidence'] as double? ?? 1.0,
            similarity: similarity,
            isCorrect: similarity >= AppConfig.minSimilarityScore,
            duration: DateTime.now().difference(startTime),
          );
          _logEvent('Risultato finale: ${recognitionResult.text}');
          _logEvent('Similarità: ${recognitionResult.similarity}');
          if (!completer.isCompleted) {
            completer.complete(recognitionResult);
          }
        },
        onError: (error) {
          _logEvent('Errore nel risultato: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      await _speechService!.start();
      _logEvent('Riconoscimento vocale avviato.');
    } catch (e) {
      _logEvent('Errore durante il riconoscimento: $e');
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  /// Genera un risultato simulato plausibile
  RecognitionResult _generateSimulatedResult(String targetText) {
    final random = Random();
    double similarity = random.nextDouble() * 0.7; // Similarità massima simulata pari a 0.7
    String recognizedText = targetText;
    if (similarity < 0.6) {
      if (random.nextBool()) {
        recognizedText = '';
      } else {
        final chars = recognizedText.split('');
        final numErrors = (chars.length * (1 - similarity)).round();
        for (var i = 0; i < numErrors; i++) {
          final pos = random.nextInt(chars.length);
          chars[pos] = String.fromCharCode(random.nextInt(26) + 97);
        }
        recognizedText = chars.join();
      }
    }
    return RecognitionResult(
      text: recognizedText,
      confidence: similarity,
      similarity: similarity,
      isCorrect: similarity >= AppConfig.minSimilarityScore,
      duration: Duration(seconds: 2 + random.nextInt(3)),
    );
  }

  /// Ferma il riconoscimento vocale in corso
  Future<void> stopRecognition() async {
    _logEvent('Stop riconoscimento vocale chiamato.');
    if (_isSimulatedMode) {
      _logEvent('Modalità simulata: stopRecognition senza ulteriori azioni.');
      return;
    }
    if (_isInitialized && _speechService != null) {
      await _speechService!.stop();
      await _resultSubscription?.cancel();
      await _partialSubscription?.cancel();
      _resultSubscription = null;
      _partialSubscription = null;
      _logEvent('Riconoscimento vocale fermato.');
    }
  }

  /// Rilascia le risorse utilizzate dal servizio
  Future<void> dispose() async {
    _logEvent('Dispose del servizio VoskService chiamato.');
    await stopRecognition();
    if (_isInitialized && !_isSimulatedMode) {
      _speechRecognizer?.dispose();
      _model?.dispose();
      await _speechService?.dispose();
      _speechService = null;
      _speechRecognizer = null;
      _model = null;
      _recognizer = null;
      _isInitialized = false;
      _instance = null;
      _logEvent('Risorse Vosk rilasciate.');
    }
  }

  /// Ritorna i log del servizio
  List<String> getServiceLogs() => List.unmodifiable(_serviceLog);

  // Getters pubblici
  bool get isInitialized => _isInitialized;
  String get modelPath => _modelPath;
  bool get isRecognizing => _resultSubscription != null;
  bool get isHealthy => _isInitialized && (_speechService != null || _isSimulatedMode);
  bool get isSimulated => _isSimulatedMode;
}
