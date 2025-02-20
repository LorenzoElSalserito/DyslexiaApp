// lib/services/vosk_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../models/recognition_result.dart';
import 'permission_service.dart';
import 'audio_service.dart';

class VoskService {
  static VoskService? _instance;
  static VoskService get instance => _instance ??= VoskService._internal();

  VoskFlutterPlugin? _recognizer;
  Model? _model;
  Recognizer? _speechRecognizer;

  // Stream controllers per i risultati
  final _resultController = StreamController<String>.broadcast();
  final _partialController = StreamController<String>.broadcast();

  String _lastResult = '';
  String _lastPartial = '';

  // Gestione del riconoscimento corrente
  Completer<String>? _recognitionCompleter;
  bool _isRecognizing = false;

  final PermissionService _permissionService = PermissionService();
  final AudioService _audioService = AudioService();

  bool _isInitialized = false;
  String _modelPath = '';
  StreamSubscription? _volumeSubscription;
  double _currentVolume = 0.0;

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

  VoskService._internal() {
    _logEvent('VoskService inizializzato');
    _initAudioService();
  }

  void _initAudioService() {
    _audioService.initialize();
    _volumeSubscription = _audioService.volumeLevel.listen((volume) {
      _currentVolume = volume;
      _logEvent('Volume corrente: $volume');
    });
  }

  void _logEvent(String msg) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] $msg';
    debugPrint('VoskService: $entry');
    _serviceLog.add(entry);
    if (_serviceLog.length > 1000) _serviceLog.removeAt(0);
  }

  Future<void> initialize() async {
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
        await _initializeWithRetry();
        success = true;
      } catch (e, st) {
        _logEvent('Errore nell\'inizializzazione #$attempts: $e\n$st');
        if (attempts >= _maxInitAttempts) {
          throw Exception('Impossibile inizializzare VOSK dopo $attempts tentativi');
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _initializeWithRetry() async {
    _logEvent('Avvio inizializzazione con retry');

    // Verifichiamo i permessi
    bool hasPermissions = await _permissionService.checkAllPermissions();
    if (!hasPermissions) {
      // Invece di richiedere i permessi qui, lanciamo un'eccezione
      throw Exception('Permessi necessari non concessi. Richiedi i permessi prima di inizializzare VOSK');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final voskDir = Directory(p.join(appDir.path, 'vosk'));
    if (!await voskDir.exists()) {
      await voskDir.create(recursive: true);
    }
    _modelPath = voskDir.path;

    await _copyModelFromAssets(_modelPath);

    if (!await _verifyModelIntegrity(_modelPath)) {
      throw Exception('Integrità del modello non verificata in $_modelPath');
    }

    _recognizer = VoskFlutterPlugin.instance();
    _model = await _recognizer!.createModel(_modelPath);
    _speechRecognizer = await _recognizer!.createRecognizer(
      model: _model!,
      sampleRate: AppConfig.sampleRate,
    );

    _isInitialized = true;
    _logEvent('Inizializzazione completata con successo');
  }


  Future<void> _copyModelFromAssets(String modelPath) async {
    _logEvent('Copia del modello dagli assets in: $modelPath');

    for (final file in _requiredFiles) {
      final assetPath = 'assets/vosk/$file';
      final targetFile = File(p.join(modelPath, file));

      if (!await targetFile.exists()) {
        try {
          await targetFile.parent.create(recursive: true);
          final data = await rootBundle.load(assetPath);
          await targetFile.writeAsBytes(data.buffer.asUint8List());
          _logEvent('Copiato file: $file');
        } catch (e) {
          _logEvent('Errore nel copiare $file: $e');
          throw Exception('Impossibile copiare il file modello $file');
        }
      }
    }
  }

  Future<bool> _verifyModelIntegrity(String modelPath) async {
    _logEvent('Verifica integrità modello in: $modelPath');
    try {
      for (final file in _requiredFiles) {
        final fullPath = p.join(modelPath, file);
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

  Future<RecognitionResult> startRecognition(String targetText) async {
    _logEvent('Avvio riconoscimento vocale per target: "$targetText"');
    if (!_isInitialized) {
      _logEvent('Servizio non inizializzato, chiamata initialize()');
      await initialize();
    }

    final startTime = DateTime.now();

    try {
      // Aggiungiamo un controllo preliminare del modello
      if (_model == null || _speechRecognizer == null) {
        throw Exception('Modello VOSK o riconoscitore non inizializzati');
      }

      // Registrazione audio con timeout più lungo
      const timeout = Duration(seconds: 30); // Aumentato da 10 a 30 secondi

      final audioResult = await Future.any([
        _performRecognition(targetText, startTime),
        Future.delayed(timeout, () {
          _logEvent('Timeout nel riconoscimento vocale dopo ${timeout.inSeconds} secondi');
          return _createEmptyResult(startTime);
        }),
      ]);

      // Aggiungiamo log dettagliati del risultato
      _logEvent('Risultato riconoscimento: ${audioResult.text}');
      _logEvent('Confidenza: ${audioResult.confidence}');
      _logEvent('Similarità: ${audioResult.similarity}');

      return audioResult;

    } catch (e, stack) {
      _logEvent('Errore nel riconoscimento: $e\nStack: $stack');
      // Aggiungiamo più dettagli all'errore
      final errorResult = _createEmptyResult(startTime);
      _logEvent('Creato risultato vuoto con durata: ${errorResult.duration.inMilliseconds}ms');
      return errorResult;
    }
  }

  /// Registra l'audio e restituisce i byte pre-processati.
  /// Se _useAlternativeRecorder è true, usa il registratore alternativo (flutter_sound);
  /// altrimenti usa il registratore nativo fornito da AudioService.
  /// Metodo ausiliario per l'acquisizione audio tramite AudioService
  Future<List<int>> _preprocessAudio() async {
    try {
      String recordingPath = await _audioService.startRecording();
      _logEvent('Avviata registrazione audio: $recordingPath');

      await Future.delayed(AppConfig.maxRecordingDuration as Duration);

      String recordedFile = await _audioService.stopRecording();
      _logEvent('Registrazione fermata, file: $recordedFile');

      final file = File(recordedFile);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        _logEvent('Audio registrato: ${bytes.length} byte');
        // Rimuoviamo l'header WAV se presente (44 bytes)
        final rawData = bytes.length > 44 ? bytes.sublist(44) : bytes;
        return rawData;
      } else {
        _logEvent('File audio non trovato: $recordedFile');
        return [];
      }
    } catch (e) {
      _logEvent('Errore nel pre-processing audio: $e');
      return [];
    }
  }

  Future<RecognitionResult> _performRecognition(String targetText, DateTime startTime) async {
    try {
      _logEvent('Avvio pre-processing audio');
      final audioData = await _preprocessAudio();

      if (audioData.isEmpty) {
        _logEvent('Nessun dato audio valido');
        return _createEmptyResult(startTime);
      }

      // Aggiungiamo log della dimensione dei dati audio
      _logEvent('Dimensione dati audio: ${audioData.length} bytes');

      // Inviamo i dati al riconoscitore in chunks più piccoli
      const int chunkSize = 4096;
      for (int i = 0; i < audioData.length; i += chunkSize) {
        final end = (i + chunkSize < audioData.length) ? i + chunkSize : audioData.length;
        final chunk = audioData.sublist(i, end);

        // Convertiamo i bytes in Float32List per VOSK
        final buffer = Float32List(chunk.length ~/ 2);
        for (var j = 0; j < chunk.length; j += 2) {
          final sample = (chunk[j + 1] << 8) | chunk[j];
          buffer[j ~/ 2] = (sample < 32768 ? sample : sample - 65536) / 32768.0;
        }

        await _speechRecognizer?.acceptWaveformFloats(buffer);

        // Otteniamo i risultati parziali per debug
        final partial = await _speechRecognizer?.getPartialResult();
        if (partial != null && partial.isNotEmpty) {
          _logEvent('Risultato parziale: $partial');
        }
      }

      // Otteniamo il risultato finale
      final result = await _speechRecognizer?.getFinalResult() ?? '{}';
      _logEvent('Risultato finale JSON: $result');

      final resultMap = jsonDecode(result) as Map<String, dynamic>;
      final recognizedText = (resultMap['text'] ?? '').toString().trim();

      _logEvent('Testo riconosciuto: $recognizedText');

      final similarity = _calculateTextSimilarity(recognizedText, targetText);
      _logEvent('Similarità calcolata: $similarity');

      return RecognitionResult(
        text: recognizedText,
        confidence: similarity,
        similarity: similarity,
        isCorrect: similarity >= AppConfig.minSimilarityScore,
        duration: DateTime.now().difference(startTime),
      );

    } catch (e, stack) {
      _logEvent('Errore nel riconoscimento: $e\nStack: $stack');
      return _createEmptyResult(startTime);
    }
  }

  double _calculateTextSimilarity(String text1, String text2) {
    text1 = text1.trim().toLowerCase();
    text2 = text2.trim().toLowerCase();

    if (text1 == text2) return 1.0;
    if (text1.isEmpty || text2.isEmpty) return 0.0;

    int matches = 0;
    final words1 = text1.split(' ');
    final words2 = text2.split(' ');

    for (final word in words1) {
      if (words2.contains(word)) matches++;
    }

    return matches / ((words1.length + words2.length) / 2);
  }

  RecognitionResult _createEmptyResult(DateTime startTime) {
    return RecognitionResult(
      text: '',
      confidence: 0.0,
      similarity: 0.0,
      isCorrect: false,
      duration: DateTime.now().difference(startTime),
    );
  }

  Future<void> dispose() async {
    _logEvent('Dispose chiamato');
    _isRecognizing = false;
    await _volumeSubscription?.cancel();

    await _resultController.close();
    await _partialController.close();

    if (_isInitialized) {
      await _speechRecognizer?.dispose();
      _model?.dispose();
      await _audioService.dispose();

      _speechRecognizer = null;
      _model = null;
      _recognizer = null;
      _isInitialized = false;
      _instance = null;

      _logEvent('Risorse rilasciate');
    }
  }

  bool get isInitialized => _isInitialized;
  String get modelPath => _modelPath;
  List<String> getServiceLogs() => List.unmodifiable(_serviceLog);

  // Stream per ascoltare i risultati
  Stream<String> get resultStream => _resultController.stream;
  Stream<String> get partialStream => _partialController.stream;
}