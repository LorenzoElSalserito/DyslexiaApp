import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'utils.dart'; // For runUsing and extensions.
import 'generated_vosk_bindings.dart';
import 'model.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

/// Define VoskRecognizer as an alias for Void.
typedef VoskRecognizer = Void;

/// Class representing a VOSK recognizer.
class Recognizer {
  Recognizer({
    required this.id,
    required this.model,
    required this.sampleRate,
    required MethodChannel channel,
    this.recognizerPointer,
    VoskLibrary? voskLibrary,
  })  : _channel = channel,
        _voskLibrary = voskLibrary;

  final int id;
  final Model model;
  final int sampleRate;
  final MethodChannel _channel;

  /// Pointer to the native recognizer.
  final Pointer<VoskRecognizer>? recognizerPointer;
  final VoskLibrary? _voskLibrary;

  Future<void> setMaxAlternatives(int maxAlternatives) {
    if (_voskLibrary != null && recognizerPointer != null) {
      _voskLibrary!.vosk_recognizer_set_max_alternatives(recognizerPointer!, maxAlternatives);
      return Future.value();
    }
    return _invokeRecognizerMethod<void>('setMaxAlternatives', {'maxAlternatives': maxAlternatives});
  }

  Future<void> setWords({required bool words}) {
    if (_voskLibrary != null && recognizerPointer != null) {
      _voskLibrary!.vosk_recognizer_set_words(recognizerPointer!, words ? 1 : 0);
      return Future.value();
    }
    return _invokeRecognizerMethod<void>('setWords', {'words': words});
  }

  Future<void> setPartialWords({required bool partialWords}) {
    if (_voskLibrary != null && recognizerPointer != null) {
      _voskLibrary!.vosk_recognizer_set_partial_words(recognizerPointer!, partialWords ? 1 : 0);
      return Future.value();
    }
    return _invokeRecognizerMethod<void>('setPartialWords', {'partialWords': partialWords});
  }

  Future<bool> acceptWaveformBytes(Uint8List bytes) {
    if (_voskLibrary != null && recognizerPointer != null) {
      final result = runUsing((arena) {
        // Convertiamo correttamente i bytes in Float per il recognizer
        final ptr = arena<Float>(bytes.length ~/ 2);  // Assumiamo PCM 16-bit
        final floatList = ptr.asTypedList(bytes.length ~/ 2);

        // Convertiamo i bytes PCM 16-bit in float32
        for (var i = 0; i < bytes.length ~/ 2; i++) {
          final pcmValue = bytes[i * 2] | (bytes[i * 2 + 1] << 8);
          floatList[i] = (pcmValue < 32768 ? pcmValue : pcmValue - 65536) / 32768.0;
        }

        return _voskLibrary!.vosk_recognizer_accept_waveform(
            recognizerPointer!,
            ptr,
            bytes.length ~/ 2
        );
      });
      return Future.value(result == 1);
    }
    return _invokeRecognizerMethod<bool>('acceptWaveForm', {'bytes': bytes}).then((value) => value!);
  }

  Future<bool> acceptWaveformFloats(Float32List floats) {
    if (_voskLibrary != null && recognizerPointer != null) {
      final result = runUsing((arena) {
        final ptr = floats.toFloatPtr(arena);
        return _voskLibrary!.vosk_recognizer_accept_waveform_f(recognizerPointer!, ptr, floats.length);
      });
      return Future.value(result == 1);
    }
    return _invokeRecognizerMethod<bool>('acceptWaveForm', {'floats': floats}).then((value) => value!);
  }

  Future<String> getResult() {
    if (_voskLibrary != null && recognizerPointer != null) {
      final result = _voskLibrary!.vosk_recognizer_result(recognizerPointer!);
      return Future.value(result.toDartString());
    }
    return _invokeRecognizerMethod<String>('getResult').then((value) => value ?? '{}');
  }

  Future<String> getPartialResult() {
    if (_voskLibrary != null && recognizerPointer != null) {
      final result = _voskLibrary!.vosk_recognizer_partial_result(recognizerPointer!);
      return Future.value(result.toDartString());
    }
    return _invokeRecognizerMethod<String>('getPartialResult').then((value) => value ?? '{}');
  }

  Future<String> getFinalResult() {
    if (_voskLibrary != null && recognizerPointer != null) {
      final result = _voskLibrary!.vosk_recognizer_final_result(recognizerPointer!);
      return Future.value(result.toDartString());
    }
    return _invokeRecognizerMethod<String>('getFinalResult').then((value) => value ?? '{}');
  }

  Future<void> setGrammar(List<String> grammar) {
    if (_voskLibrary != null && recognizerPointer != null) {
      runUsing((arena) {
        final grammarString = jsonEncode(grammar);
        final grammarUtf8 = grammarString.toNativeUtf8(allocator: arena);
        _voskLibrary!.vosk_recognizer_set_grm(recognizerPointer!, grammarUtf8);
      });
      return Future.value();
    }
    return _invokeRecognizerMethod<void>('setGrammar', {'grammar': jsonEncode(grammar)});
  }

  Future<void> reset() {
    if (_voskLibrary != null && recognizerPointer != null) {
      _voskLibrary!.vosk_recognizer_reset(recognizerPointer!);
      return Future.value();
    }
    return _invokeRecognizerMethod<void>('reset');
  }

  Future<void> dispose() {
    if (_voskLibrary != null && recognizerPointer != null) {
      _voskLibrary!.vosk_recognizer_free(recognizerPointer!);
      return Future.value();
    }
    return _invokeRecognizerMethod<void>('close');
  }

  Future<T?> _invokeRecognizerMethod<T>(String method, [Map<String, dynamic> arguments = const {}]) {
    final args = Map<String, dynamic>.from(arguments);
    args['recognizerId'] = id;
    return _channel.invokeMethod<T>('recognizer.$method', args);
  }

  @override
  String toString() {
    return 'Recognizer[id=$id, model=$model, sampleRate=$sampleRate]';
  }
}