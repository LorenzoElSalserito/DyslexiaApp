// lib/services/vosk_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:vosk_flutter/vosk_flutter.dart';
import '../models/recognition_result.dart';
import '../config/app_config.dart';
import 'permission_service.dart';
import 'audio_service.dart';

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
  final AudioService _audioService = AudioService();

  // Stato del servizio
  bool _isInitialized = false;
  bool _isSimulatedMode = false;
  String _modelPath = '';
  StreamSubscription? _resultSubscription;
  StreamSubscription? _partialSubscription;
  StreamSubscription? _volumeSubscription;
  double _currentVolume = 0.0;

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
    _initAudioService();
  }

  void _initAudioService() {
    _audioService.initialize();
    _volumeSubscription = _audioService.volumeLevel.listen((volume) {
      _currentVolume = volume;
    });
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
  Future<void> initialize() async {
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
        await _initializeWithRetry();
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
  Future<void> _initializeWithRetry() async {
    _logEvent('Inizio inizializzazione con retry');

    bool hasPermissions = await _permissionService.checkAllPermissions();

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

      // Impostiamo le configurazioni dopo la creazione utilizzando i parametri nominati
      if (_speechRecognizer != null) {
        await _speechRecognizer!.setMaxAlternatives(0);
        await _speechRecognizer!.setPartialWords(partialWords: true);
        await _speechRecognizer!.setWords(words: true);
      }
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
          final currentDuration = DateTime.now().difference(startTime);
          if (currentDuration > const Duration(hours: 1)) {
            _logEvent('Durata audio ($currentDuration) superiore a 60 minuti. Abort processing.');
            if (!completer.isCompleted) {
              completer.completeError(Exception('Audio file too long. Processing aborted.'));
            }
            return;
          }

          // Se il volume è troppo basso o troppo alto, consideriamo come nessun input
          if (_currentVolume < AppConfig.volumeThreshold || _currentVolume > AppConfig.maxVolume) {
            final silentResult = RecognitionResult(
              text: '',
              confidence: 0.0,
              similarity: 0.0,
              isCorrect: false,
              duration: currentDuration,
            );

            if (!completer.isCompleted) {
              completer.complete(silentResult);
            }
            return;
          }

          // Continua con il normale processamento VOSK solo se c'è abbastanza volume
          final recognizedText = result['text'] as String? ?? '';
          final List<dynamic> words = result['result'] as List<dynamic>? ?? [];
          double totalConfidence = 0.0;

          if (words.isNotEmpty) {
            // Se il testo riconosciuto corrisponde esattamente al target
            if (recognizedText.trim().toLowerCase() == targetText.trim().toLowerCase()) {
              for (var word in words) {
                totalConfidence += (word['conf'] as num).toDouble();
              }
              totalConfidence /= words.length;
            } else {
              for (var word in words) {
                totalConfidence += (word['conf'] as num).toDouble();
              }
              totalConfidence /= words.length;
              totalConfidence *= 0.5; // Penalità per mancata corrispondenza esatta
            }

            if (_currentVolume < AppConfig.idealVolume) {
              totalConfidence *= (_currentVolume / AppConfig.idealVolume);
            }
          }

          final recognitionResult = RecognitionResult(
            text: recognizedText,
            confidence: totalConfidence,
            similarity: totalConfidence,
            isCorrect: totalConfidence >= AppConfig.minSimilarityScore,
            duration: currentDuration,
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
    await _volumeSubscription?.cancel();
    if (_isInitialized && !_isSimulatedMode) {
      _speechRecognizer?.dispose();
      _model?.dispose();
      await _speechService?.dispose();
      await _audioService.dispose();
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
