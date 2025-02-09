import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'generated_vosk_bindings.dart';
import 'model.dart';
import 'recognizer.dart';
import 'speech_service.dart';
import 'utils.dart';

/// Provides access to the Vosk speech recognition API.
class VoskFlutterPlugin {
  VoskFlutterPlugin._() {
    if (_supportsFFI()) {
      _voskLibrary = _loadVoskLibrary();
    } else if (Platform.isAndroid) {
      _channel.setMethodCallHandler(_methodCallHandler);
    } else {
      throw UnsupportedError('Platform ${Platform.operatingSystem} is not supported');
    }
  }

  late VoskLibrary _voskLibrary;

  static VoskFlutterPlugin instance() => _instance ??= VoskFlutterPlugin._();
  static const MethodChannel _channel = MethodChannel('vosk_flutter');
  static VoskFlutterPlugin? _instance;
  final Map<String, Completer<Model>> _pendingModels = {};

  Future<Model> createModel(String modelPath) {
    final completer = Completer<Model>();

    if (_supportsFFI()) {
      // Usa la funzione 'compute' per eseguire _loadModel in un isolate separato
      compute(_loadModel, modelPath).then(
            (modelPointer) => completer.complete(
          Model(modelPath, _channel, Pointer.fromAddress(modelPointer)),
        ),
        onError: completer.completeError,
      );
    } else if (Platform.isAndroid) {
      _pendingModels[modelPath] = completer;
      _channel.invokeMethod('model.create', modelPath);
    }
    return completer.future;
  }

  Future<Recognizer> createRecognizer({
    required Model model,
    required int sampleRate,
    List<String>? grammar,
  }) async {
    if (_supportsFFI()) {
      return runUsing((arena) {
        final recognizerPointer = grammar == null
            ? _voskLibrary.vosk_recognizer_new(
          model.modelPointer!,
          sampleRate.toDouble(),
        )
            : _voskLibrary.vosk_recognizer_new_grm(
          model.modelPointer!,
          sampleRate.toDouble(),
          jsonEncode(grammar).toNativeUtf8(allocator: arena),
        );
        return Recognizer(
          id: -1,
          model: model,
          sampleRate: sampleRate,
          channel: _channel,
          recognizerPointer: recognizerPointer,
          voskLibrary: _voskLibrary,
        );
      });
    }

    final args = <String, dynamic>{
      'modelPath': model.path,
      'sampleRate': sampleRate,
    };
    if (grammar != null) {
      args['grammar'] = jsonEncode(grammar);
    }
    final id = await _channel.invokeMethod('recognizer.create', args);
    return Recognizer(
      id: id as int,
      model: model,
      sampleRate: sampleRate,
      channel: _channel,
    );
  }

  Future<SpeechService> initSpeechService(Recognizer recognizer) async {
    if (await Permission.microphone.status == PermissionStatus.denied &&
        await Permission.microphone.request() == PermissionStatus.denied) {
      throw MicrophoneAccessDeniedException();
    }

    if (!_supportsFFI()) {
      await _channel.invokeMethod('speechService.init', {
        'recognizerId': recognizer.id,
        'sampleRate': recognizer.sampleRate,
      });
    }
    return SpeechService(_channel);
  }

  Future<void> _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'model.created':
        final modelPath = call.arguments as String;
        _pendingModels.remove(modelPath)?.complete(Model(modelPath, _channel));
        break;
      case 'model.error':
        final args = call.arguments as Map;
        final modelPath = args['modelPath'] as String;
        final error = args['error'] as String;
        _pendingModels.remove(modelPath)?.completeError(error);
        break;
      default:
        print('Unsupported method: ${call.method}');
    }
  }

  bool _supportsFFI() => Platform.isLinux || Platform.isWindows;

  static VoskLibrary _loadVoskLibrary() {
    String libraryPath;
    if (Platform.isLinux || Platform.isWindows) {
      libraryPath = Platform.environment['LIBVOSK_PATH'] ??
          const String.fromEnvironment('VOSK_LIB_PATH', defaultValue: '');
      if (libraryPath.isEmpty) {
        throw Exception('Library path not defined: set LIBVOSK_PATH in the environment or pass VOSK_LIB_PATH as dart define.');
      }
      if (Platform.isLinux && !libraryPath.endsWith('libvosk.so')) {
        libraryPath = '$libraryPath/libvosk.so';
      }
      if (Platform.isWindows && !libraryPath.endsWith('libvosk.dll')) {
        libraryPath = '$libraryPath\\libvosk.dll';
      }
    } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      throw UnsupportedError('VoskFlutter FFI not supported on this platform.');
    } else {
      throw UnsupportedError('Unsupported platform.');
    }
    final dylib = DynamicLibrary.open(libraryPath);
    return VoskLibrary.fromDynamicLibrary(dylib);
  }

  static int _loadModel(String modelPath) {
    final voskLib = _loadVoskLibrary();
    final modelPointer = runUsing((arena) {
      return voskLib.vosk_model_new(modelPath.toNativeUtf8(allocator: arena));
    });
    if (modelPointer == nullptr) {
      throw Exception('Failed to load model');
    }
    return modelPointer.address;
  }

  static void registerWith() {
    // Questo metodo è necessario per la registrazione del plugin
    // Non necessita di implementazione perché la registrazione
    // avviene tramite il sistema di plugin di Flutter
  }
}

/// Exception thrown when microphone access is denied.
class MicrophoneAccessDeniedException implements Exception {}