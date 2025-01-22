import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
import '../models/recognition_result.dart';
import '../utils/text_similarity.dart';
import '../config/app_config.dart';

class VoskService {
  static VoskService? _instance;
  VoskFlutterPlugin? _recognizer;
  Model? _model;
  Recognizer? _speechRecognizer;
  SpeechService? _speechService;
  bool _isInitialized = false;
  bool _isDownloading = false;
  String _modelPath = '';
  StreamSubscription? _resultSubscription;
  StreamSubscription? _partialSubscription;

  // Singleton pattern
  static VoskService get instance {
    _instance ??= VoskService._();
    return _instance!;
  }

  VoskService._();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _modelPath = await _prepareModel();
      _recognizer = VoskFlutterPlugin.instance();

      // Create model
      _model = await _recognizer!.createModel(_modelPath);

      // Create recognizer with sample rate
      _speechRecognizer = await _recognizer!.createRecognizer(
        model: _model!,
        sampleRate: AppConfig.sampleRate,
      );

      // Initialize speech service
      _speechService = await _recognizer!.initSpeechService(_speechRecognizer!);

      _isInitialized = true;
    } catch (e) {
      print('Errore nell\'inizializzazione di VOSK: $e');
      rethrow;
    }
  }

  Future<String> _prepareModel() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = '${appDir.path}/vosk-model-small-it';

    if (!await Directory(modelDir).exists()) {
      await _downloadAndExtractModel(modelDir);
    }

    return modelDir;
  }

  Future<void> _downloadAndExtractModel(String modelDir) async {
    if (_isDownloading) return;
    _isDownloading = true;

    try {
      final tempFile = File('${Directory.systemTemp.path}/model.zip');

      // Download del modello
      await _downloadModel(tempFile);

      // Estrazione del modello
      await _extractModel(tempFile, modelDir);

      // Pulizia
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      _isDownloading = false;
    } catch (e) {
      _isDownloading = false;
      print('Errore nel download del modello: $e');
      rethrow;
    }
  }

  Future<void> _downloadModel(File tempFile) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(AppConfig.voskModelUrl));
      final response = await client.send(request);
      final contentLength = response.contentLength ?? 0;
      var received = 0;

      final sink = tempFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
      }
      await sink.close();
    } finally {
      client.close();
    }
  }

  Future<void> _extractModel(File zipFile, String modelDir) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filePath = '$modelDir/${file.name}';
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }
  }

  Future<RecognitionResult> startRecognition(String targetText) async {
    if (!_isInitialized) await initialize();

    final startTime = DateTime.now();
    final completer = Completer<RecognitionResult>();

    try {
      if (_speechService == null) {
        throw Exception('Speech service not initialized');
      }

      // Subscribe to partial results
      _partialSubscription = _speechService!.onPartial().listen(
            (result) {
          print('Partial result: $result');
        },
      );

      // Subscribe to final results
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

          if (!completer.isCompleted) {
            completer.complete(recognitionResult);
          }
        },
      );

      await _speechService!.start(
        onRecognitionError: (error) {
          print('Recognition error: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

    } catch (e) {
      print('Errore durante il riconoscimento vocale: $e');
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  Future<void> stopRecognition() async {
    if (_isInitialized && _speechService != null) {
      await _speechService!.stop();
      await _resultSubscription?.cancel();
      await _partialSubscription?.cancel();
      _resultSubscription = null;
      _partialSubscription = null;
    }
  }

  Future<void> dispose() async {
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
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isDownloading => _isDownloading;
  String get modelPath => _modelPath;
}