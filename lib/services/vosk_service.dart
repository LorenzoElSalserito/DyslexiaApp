// lib/services/vosk_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import '../models/recognition_result.dart';
import '../utils/text_similarity.dart';
import '../config/app_config.dart';
import 'permission_service.dart';

/// Servizio che gestisce l'interazione con il motore di riconoscimento vocale VOSK.
/// Integra la gestione dei permessi e fornisce un sistema di logging completo.
class VoskService {
  // Singleton pattern
  static VoskService? _instance;

  // Componenti VOSK
  VoskFlutterPlugin? _recognizer;
  Model? _model;
  Recognizer? _speechRecognizer;
  SpeechService? _speechService;

  // Servizi
  final PermissionService _permissionService = PermissionService();

  // Stato del servizio
  bool _isInitialized = false;
  bool _isDownloading = false;
  String _modelPath = '';
  StreamSubscription? _resultSubscription;
  StreamSubscription? _partialSubscription;

  // Buffer per i log
  final List<String> _serviceLog = [];

  // Configurazioni del modello
  late final String _modelFileName;
  late final String _modelBaseName;

  /// Ottiene l'istanza singleton del servizio
  static VoskService get instance {
    _instance ??= VoskService._();
    return _instance!;
  }

  VoskService._() {
    _modelFileName = path.basename(AppConfig.voskModelUrl);
    _modelBaseName = _modelFileName.replaceAll('.zip', '');
    _logEvent('VoskService inizializzato');
  }

  /// Inizializza il servizio e prepara il modello
  Future<void> initialize({BuildContext? context}) async {
    if (_isInitialized) {
      _logEvent('Servizio già inizializzato');
      return;
    }

    try {
      _logEvent('Inizio inizializzazione');

      // Verifica permessi
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

      _logEvent('Permessi ottenuti, preparazione modello');
      _modelPath = await _prepareModel();
      _logEvent('Modello preparato in: $_modelPath');

      // Verifica file critici
      final requiredFiles = ['am/final.mdl', 'conf/mfcc.conf', 'graph/HCLr.fst'];
      for (final file in requiredFiles) {
        final fullPath = path.join(_modelPath, file);
        if (!await File(fullPath).exists()) {
          throw Exception('File modello mancante: $file');
        }
      }

      _logEvent('Inizializzazione componenti VOSK');

      // Inizializzazione con timeout di sicurezza
      _recognizer = VoskFlutterPlugin.instance();
      _model = await _recognizer!.createModel(_modelPath)
          .timeout(const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Timeout creazione modello'));

      _logEvent('Modello VOSK creato');

      _speechRecognizer = await _recognizer!.createRecognizer(
        model: _model!,
        sampleRate: AppConfig.sampleRate,
      ).timeout(const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Timeout creazione recognizer'));

      _logEvent('Recognizer creato');

      _speechService = await _recognizer!.initSpeechService(_speechRecognizer!)
          .timeout(const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Timeout inizializzazione speech service'));

      _logEvent('Speech service inizializzato');

      _isInitialized = true;
      _logEvent('Inizializzazione completata con successo');

    } catch (e, stackTrace) {
      _logEvent('Errore nell\'inizializzazione: $e');
      _logEvent('Stack trace: $stackTrace');
      await _cleanCorruptedModel();
      rethrow;
    }
  }

  /// Prepara il modello linguistico, scaricandolo se necessario
  Future<String> _prepareModel() async {
    _logEvent('Preparazione modello');

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(path.join(docsDir.path, 'vosk_models'));

      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
        _logEvent('Directory modelli creata');
      }

      final modelDir = path.join(modelsDir.path, _modelBaseName);
      _logEvent('Directory modello: $modelDir');

      if (!await Directory(modelDir).exists() ||
          !await _verifyModelIntegrity(modelDir)) {
        _logEvent('Download modello necessario');
        await _downloadAndExtractModel(modelDir);
      } else {
        _logEvent('Modello esistente verificato');
      }

      return modelDir;
    } catch (e) {
      _logEvent('Errore nella preparazione del modello: $e');
      rethrow;
    }
  }

  /// Verifica l'integrità dei file del modello
  Future<bool> _verifyModelIntegrity(String modelDir) async {
    _logEvent('Verifica integrità modello in: $modelDir');

    try {
      final requiredFiles = ['am/final.mdl', 'conf/mfcc.conf', 'graph/HCLr.fst'];
      for (final file in requiredFiles) {
        if (!await File(path.join(modelDir, file)).exists()) {
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

  /// Scarica e estrae il modello linguistico
  Future<void> _downloadAndExtractModel(String modelDir) async {
    if (_isDownloading) {
      _logEvent('Download già in corso');
      return;
    }

    _isDownloading = true;
    _logEvent('Inizio download modello');

    try {
      // Verifica connessione internet
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty) {
          throw Exception('Connessione internet non disponibile');
        }
      } on SocketException catch (_) {
        throw Exception('Connessione internet non disponibile');
      }

      final tempDir = await Directory.systemTemp.createTemp('vosk_download');
      final tempFile = File(path.join(tempDir.path, _modelFileName));

      _logEvent('Download del modello in corso...');
      await _downloadModel(tempFile);

      _logEvent('Estrazione modello in: $modelDir');
      await _extractModel(tempFile, modelDir);

      await tempDir.delete(recursive: true);
      _logEvent('Download e estrazione completati');

    } catch (e) {
      _logEvent('Errore nel download/estrazione: $e');
      rethrow;
    } finally {
      _isDownloading = false;
    }
  }

  /// Scarica il modello dalla rete
  Future<void> _downloadModel(File tempFile) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(AppConfig.voskModelUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Errore HTTP: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      var received = 0;

      final sink = tempFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        final progress = contentLength > 0 ?
        (received / contentLength * 100).toStringAsFixed(1) : 'Sconosciuto';
        _logEvent('Progresso download: $progress%');
      }
      await sink.close();
      _logEvent('Download completato');
    } finally {
      client.close();
    }
  }

  /// Estrae il modello dall'archivio zip
  Future<void> _extractModel(File zipFile, String modelDir) async {
    _logEvent('Inizio estrazione modello');

    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final fileName = file.name;
        final relativePath = fileName.startsWith(_modelBaseName)
            ? fileName.substring(_modelBaseName.length + 1)
            : fileName;

        final filePath = path.join(modelDir, relativePath);

        if (file.isFile) {
          final outFile = File(filePath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }
      _logEvent('Estrazione completata');
    } catch (e) {
      _logEvent('Errore nell\'estrazione: $e');
      rethrow;
    }
  }

  /// Pulisce un modello corrotto
  Future<void> _cleanCorruptedModel() async {
    _logEvent('Pulizia modello corrotto');

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory(path.join(docsDir.path, 'vosk_models', _modelBaseName));
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
        _logEvent('Modello corrotto rimosso');
      }
      _isInitialized = false;
    } catch (e) {
      _logEvent('Errore nella pulizia del modello: $e');
    }
  }

  /// Avvia una sessione di riconoscimento vocale
  Future<RecognitionResult> startRecognition(String targetText) async {
    _logEvent('Avvio riconoscimento vocale');

    if (!_isInitialized) {
      _logEvent('Inizializzazione necessaria');
      await initialize();
    }

    final startTime = DateTime.now();
    final completer = Completer<RecognitionResult>();

    try {
      if (_speechService == null) {
        throw Exception('Speech service non inizializzato');
      }

      _logEvent('Configurazione listeners');

      _partialSubscription = _speechService!.onPartial().listen(
            (result) {
          _logEvent('Risultato parziale: $result');
        },
        onError: (error) {
          _logEvent('Errore nel risultato parziale: $error');
        },
      );

      _resultSubscription = _speechService!.onResult().listen(
            (result) {
          final duration = DateTime.now().difference(startTime);
          final similarity = TextSimilarity.calculateSimilarity(result, targetText);

          final recognitionResult = RecognitionResult(
            text: result,
            confidence: 1.0,
            similarity: similarity,
            isCorrect: similarity >= 0.85,
            duration: duration,
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
        cancelOnError: true,
      );

      await _speechService!.start();
      _logEvent('Riconoscimento avviato');

    } catch (e) {
      _logEvent('Errore durante il riconoscimento: $e');
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  /// Ferma la sessione di riconoscimento
  Future<void> stopRecognition() async {
    _logEvent('Stop riconoscimento');

    if (_isInitialized && _speechService != null) {
      await _speechService!.stop();
      await _resultSubscription?.cancel();
      await _partialSubscription?.cancel();
      _resultSubscription = null;
      _partialSubscription = null;
      _logEvent('Riconoscimento fermato');
    }
  }

  /// Registra un evento nel log del servizio
  void _logEvent(String event) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $event';
    print('VoskService: $logEntry');
    _serviceLog.add(logEntry);

    // Mantiene solo gli ultimi 1000 log
    if (_serviceLog.length > 1000) {
      _serviceLog.removeAt(0);
    }
  }

  /// Ottiene i log del servizio
  List<String> getServiceLogs() {
    return List.unmodifiable(_serviceLog);
  }

  /// Rilascia tutte le risorse
  Future<void> dispose() async {
    _logEvent('Dispose del servizio');

    await stopRecognition();
    if (_isInitialized) {
      _speechRecognizer?.dispose();
      _model?.dispose();
      await _speechService?.dispose();
      _speechService = null;
      _speechRecognizer = null;
      _model = null;
      _recognizer = null;
      _isInitialized = false;
      _instance = null;
      _logEvent('Risorse rilasciate');
    }
  }

// Getters pubblici per accedere allo stato del servizio

  /// Indica se il servizio è stato correttamente inizializzato
  bool get isInitialized => _isInitialized;

  /// Indica se è in corso il download del modello
  bool get isDownloading => _isDownloading;

  /// Restituisce il percorso del modello attualmente in uso
  String get modelPath => _modelPath;

  /// Indica il nome del file modello
  String get modelFileName => _modelFileName;

  /// Indica il nome base del modello (senza estensione)
  String get modelBaseName => _modelBaseName;

  /// Restituisce lo stato corrente del servizio di riconoscimento
  bool get isRecognizing => _resultSubscription != null;

  /// Restituisce lo stato di salute complessivo del servizio
  bool get isHealthy => _isInitialized && !_isDownloading && _speechService != null;

  /// Restituisce un report sullo stato del servizio
  Map<String, dynamic> getStatusReport() {
    return {
      'isInitialized': _isInitialized,
      'isDownloading': _isDownloading,
      'modelPath': _modelPath,
      'hasRecognizer': _speechRecognizer != null,
      'hasSpeechService': _speechService != null,
      'isRecognizing': isRecognizing,
      'isHealthy': isHealthy,
      'lastLogEntry': _serviceLog.isNotEmpty ? _serviceLog.last : null,
      'totalLogEntries': _serviceLog.length,
    };
  }
}