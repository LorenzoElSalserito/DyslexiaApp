// vosk_service.dart

import 'dart:async';
import 'dart:io';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import '../models/recognition_result.dart';
import '../utils/text_similarity.dart';
import '../config/app_config.dart';

class VoskService {
  static VoskService? _instance;
  late VoskSpeechRecognizer _recognizer;
  bool _isInitialized = false;
  bool _isDownloading = false;
  String _modelPath = '';

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
      _recognizer = await VoskSpeechRecognizer.create(_modelPath);
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
      final filePath = '${Directory.systemTemp.path}/${file.name}';
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content);
      }
    }
  }

  Future<RecognitionResult> startRecognition(String targetText) async {
    if (!_isInitialized) await initialize();

    final completer = Completer<RecognitionResult>();
    var startTime = DateTime.now();

    _recognizer.setFinalResultListener((result) {
      final duration = DateTime.now().difference(startTime);
      final voskResult = RecognitionResult.fromVoskResult(
          {
            'text': result,
            'duration': duration.inMilliseconds,
            'confidence': 1.0
          },
          targetText
      );
      completer.complete(voskResult);
    });

    try {
      await _recognizer.start();
    } catch (e) {
      completer.completeError('Errore durante il riconoscimento vocale: $e');
    }

    return completer.future;
  }

  Future<void> stopRecognition() async {
    if (_isInitialized) {
      await _recognizer.stop();
    }
  }

  Future<void> dispose() async {
    await stopRecognition();
    if (_isInitialized) {
      await _recognizer.dispose();
      _isInitialized = false;
    }
  }

  bool get isInitialized => _isInitialized;
  bool get isDownloading => _isDownloading;
  String get modelPath => _modelPath;
}