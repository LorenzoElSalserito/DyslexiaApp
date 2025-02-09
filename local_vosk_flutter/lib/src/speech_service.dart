import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'recognizer.dart';

/// Speech recognition service used to process audio input from the device's
/// microphone or audio data.
class SpeechService {
  /// Create a new instance of SpeechService
  SpeechService(this._channel);

  final MethodChannel _channel;

  // Dichiariamo gli stream con il tipo corretto Map<String, dynamic>
  // che ci permetterà di gestire sia il testo che eventuali metadati aggiuntivi
  Stream<Map<String, dynamic>>? _resultStream;
  Stream<Map<String, dynamic>>? _partialResultStream;
  StreamSubscription<void>? _errorStreamSubscription;

  /// Start recognition.
  /// Use [onResult] and [onPartial] to get recognition results.
  Future<bool?> start({Function? onRecognitionError}) {
    _errorStreamSubscription ??= EventChannel(
      'error_event_channel',
      const StandardMethodCodec(),
      _channel.binaryMessenger,
    ).receiveBroadcastStream().listen(null, onError: onRecognitionError);

    return _channel.invokeMethod<bool>('speechService.start');
  }

  /// Stop recognition.
  Future<bool?> stop() {
    _errorStreamSubscription?.cancel();
    return _channel.invokeMethod<bool>('speechService.stop');
  }

  /// Pause/unpause recognition.
  Future<bool?> setPause({required bool paused}) =>
      _channel.invokeMethod<bool>('speechService.setPause', paused);

  /// Reset recognition.
  /// See [Recognizer.reset].
  Future<bool?> reset() => _channel.invokeMethod<bool>('speechService.reset');

  /// Cancel recognition.
  Future<bool?> cancel() {
    _errorStreamSubscription?.cancel();
    return _channel.invokeMethod<bool>('speechService.cancel');
  }

  /// Release service resources.
  Future<void> dispose() {
    _errorStreamSubscription?.cancel();
    return _channel.invokeMethod<void>('speechService.destroy');
  }

  /// Get stream with voice recognition results.
  /// Returns a stream of Maps containing recognition results.
  /// Each Map will have at least a 'text' key with the recognized text.
  Stream<Map<String, dynamic>> onResult() {
    return _resultStream ??= EventChannel(
      'result_event_channel',
      const StandardMethodCodec(),
      _channel.binaryMessenger,
    ).receiveBroadcastStream().map<Map<String, dynamic>>((dynamic result) {
      try {
        if (result is String) {
          // Proviamo prima a decodificare come JSON
          try {
            final decoded = jsonDecode(result);
            if (decoded is Map<String, dynamic>) {
              return decoded;
            }
            // Se non è una Map, lo trattiamo come testo semplice
            return {'text': decoded.toString()};
          } catch (e) {
            // Se il parsing JSON fallisce, trattiamo come testo semplice
            return {'text': result};
          }
        } else if (result is Map<String, dynamic>) {
          // Se è già una Map, verifichiamo che abbia la chiave 'text'
          return result.containsKey('text') ? result : {'text': result.toString()};
        }
        // Caso di fallback per altri tipi
        return {'text': result?.toString() ?? ''};
      } catch (e) {
        // Gestiamo qualsiasi errore inaspettato restituendo una mappa vuota
        return {'text': '', 'error': e.toString()};
      }
    });
  }

  /// Get stream with voice recognition partial results.
  /// Returns a stream of Maps containing partial recognition results.
  /// Each Map will have at least a 'partial' key with the partially recognized text.
  Stream<Map<String, dynamic>> onPartial() {
    return _partialResultStream ??= EventChannel(
      'partial_event_channel',
      const StandardMethodCodec(),
      _channel.binaryMessenger,
    ).receiveBroadcastStream().map<Map<String, dynamic>>((dynamic result) {
      try {
        if (result is String) {
          // Proviamo prima a decodificare come JSON
          try {
            final decoded = jsonDecode(result);
            if (decoded is Map<String, dynamic>) {
              return decoded;
            }
            // Se non è una Map, lo trattiamo come testo parziale
            return {'partial': decoded.toString()};
          } catch (e) {
            // Se il parsing JSON fallisce, trattiamo come testo parziale
            return {'partial': result};
          }
        } else if (result is Map<String, dynamic>) {
          // Se è già una Map, verifichiamo che abbia la chiave 'partial'
          return result.containsKey('partial') ? result : {'partial': result.toString()};
        }
        // Caso di fallback per altri tipi
        return {'partial': result?.toString() ?? ''};
      } catch (e) {
        // Gestiamo qualsiasi errore inaspettato restituendo una mappa vuota
        return {'partial': '', 'error': e.toString()};
      }
    });
  }
}