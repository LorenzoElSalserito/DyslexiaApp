/// GENERATED FILE - DO NOT MODIFY BY HAND
///
/// Questo file contiene i binding FFI per la libreria VOSK, con alcune
/// modifiche manuali per garantire un corretto funzionamento.
/// Assicurati che la libreria condivisa (libvosk.so su Linux, libvosk.dll su Windows)
/// esporti i simboli con i seguenti nomi.

import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// Binding per la funzione vosk_model_new: crea un modello VOSK da un percorso UTF8.
typedef vosk_model_new_native = Pointer<Void> Function(Pointer<Utf8> modelPath);
typedef vosk_model_new_dart = Pointer<Void> Function(Pointer<Utf8> modelPath);

/// Binding per la funzione vosk_model_free: libera le risorse associate al modello.
typedef vosk_model_free_native = Void Function(Pointer<Void> model);
typedef vosk_model_free_dart = void Function(Pointer<Void> model);

/// Binding per la funzione vosk_recognizer_new: crea un recognizer per il modello.
typedef vosk_recognizer_new_native = Pointer<Void> Function(Pointer<Void> model, Double sampleRate);
typedef vosk_recognizer_new_dart = Pointer<Void> Function(Pointer<Void> model, double sampleRate);

/// Binding per la funzione vosk_recognizer_new_grm: crea un recognizer con grammatica.
typedef vosk_recognizer_new_grm_native = Pointer<Void> Function(Pointer<Void> model, Double sampleRate, Pointer<Utf8> grammar);
typedef vosk_recognizer_new_grm_dart = Pointer<Void> Function(Pointer<Void> model, double sampleRate, Pointer<Utf8> grammar);

/// Binding per vosk_recognizer_set_max_alternatives.
typedef vosk_recognizer_set_max_alternatives_native = Void Function(Pointer<Void> recognizer, Int32 maxAlternatives);
typedef vosk_recognizer_set_max_alternatives_dart = void Function(Pointer<Void> recognizer, int maxAlternatives);

/// Binding per vosk_recognizer_set_words.
typedef vosk_recognizer_set_words_native = Void Function(Pointer<Void> recognizer, Int32 words);
typedef vosk_recognizer_set_words_dart = void Function(Pointer<Void> recognizer, int words);

/// Binding per vosk_recognizer_set_partial_words.
typedef vosk_recognizer_set_partial_words_native = Void Function(Pointer<Void> recognizer, Int32 partial);
typedef vosk_recognizer_set_partial_words_dart = void Function(Pointer<Void> recognizer, int partial);

/// Binding per vosk_recognizer_accept_waveform.
typedef vosk_recognizer_accept_waveform_native = Int32 Function(Pointer<Void> recognizer, Pointer<Float> data, Int32 length);
typedef vosk_recognizer_accept_waveform_dart = int Function(Pointer<Void> recognizer, Pointer<Float> data, int length);

/// Binding per vosk_recognizer_accept_waveform_f.
typedef vosk_recognizer_accept_waveform_f_native = Int32 Function(Pointer<Void> recognizer, Pointer<Float> data, Int32 length);
typedef vosk_recognizer_accept_waveform_f_dart = int Function(Pointer<Void> recognizer, Pointer<Float> data, int length);

/// Binding per vosk_recognizer_result.
typedef vosk_recognizer_result_native = Pointer<Utf8> Function(Pointer<Void> recognizer);
typedef vosk_recognizer_result_dart = Pointer<Utf8> Function(Pointer<Void> recognizer);

/// Binding per vosk_recognizer_partial_result.
typedef vosk_recognizer_partial_result_native = Pointer<Utf8> Function(Pointer<Void> recognizer);
typedef vosk_recognizer_partial_result_dart = Pointer<Utf8> Function(Pointer<Void> recognizer);

/// Binding per vosk_recognizer_final_result.
typedef vosk_recognizer_final_result_native = Pointer<Utf8> Function(Pointer<Void> recognizer);
typedef vosk_recognizer_final_result_dart = Pointer<Utf8> Function(Pointer<Void> recognizer);

/// Binding per vosk_recognizer_set_grm.
typedef vosk_recognizer_set_grm_native = Void Function(Pointer<Void> recognizer, Pointer<Utf8> grammar);
typedef vosk_recognizer_set_grm_dart = void Function(Pointer<Void> recognizer, Pointer<Utf8> grammar);

/// Binding per vosk_recognizer_reset.
typedef vosk_recognizer_reset_native = Void Function(Pointer<Void> recognizer);
typedef vosk_recognizer_reset_dart = void Function(Pointer<Void> recognizer);

/// Binding per vosk_recognizer_free.
typedef vosk_recognizer_free_native = Void Function(Pointer<Void> recognizer);
typedef vosk_recognizer_free_dart = void Function(Pointer<Void> recognizer);

/// La classe [VoskLibrary] fornisce l’accesso ai binding FFI per l’API VOSK.
class VoskLibrary {
  final DynamicLibrary _dylib;

  // Costruttore privato: utilizzare il factory.
  VoskLibrary._(this._dylib);

  /// Factory constructor per creare un’istanza a partire da un DynamicLibrary già aperto.
  factory VoskLibrary.fromDynamicLibrary(DynamicLibrary dylib) {
    return VoskLibrary._(dylib);
  }

  // Lookup delle funzioni VOSK.
  late final vosk_model_new = _dylib.lookupFunction<vosk_model_new_native, vosk_model_new_dart>('vosk_model_new');
  late final vosk_model_free = _dylib.lookupFunction<vosk_model_free_native, vosk_model_free_dart>('vosk_model_free');

  late final vosk_recognizer_new = _dylib.lookupFunction<vosk_recognizer_new_native, vosk_recognizer_new_dart>('vosk_recognizer_new');
  late final vosk_recognizer_new_grm = _dylib.lookupFunction<vosk_recognizer_new_grm_native, vosk_recognizer_new_grm_dart>('vosk_recognizer_new_grm');

  late final vosk_recognizer_set_max_alternatives = _dylib.lookupFunction<vosk_recognizer_set_max_alternatives_native, vosk_recognizer_set_max_alternatives_dart>('vosk_recognizer_set_max_alternatives');
  late final vosk_recognizer_set_words = _dylib.lookupFunction<vosk_recognizer_set_words_native, vosk_recognizer_set_words_dart>('vosk_recognizer_set_words');
  late final vosk_recognizer_set_partial_words = _dylib.lookupFunction<vosk_recognizer_set_partial_words_native, vosk_recognizer_set_partial_words_dart>('vosk_recognizer_set_partial_words');

  late final vosk_recognizer_accept_waveform = _dylib.lookupFunction<vosk_recognizer_accept_waveform_native, vosk_recognizer_accept_waveform_dart>('vosk_recognizer_accept_waveform');
  late final vosk_recognizer_accept_waveform_f = _dylib.lookupFunction<vosk_recognizer_accept_waveform_f_native, vosk_recognizer_accept_waveform_f_dart>('vosk_recognizer_accept_waveform_f');

  late final vosk_recognizer_result = _dylib.lookupFunction<vosk_recognizer_result_native, vosk_recognizer_result_dart>('vosk_recognizer_result');
  late final vosk_recognizer_partial_result = _dylib.lookupFunction<vosk_recognizer_partial_result_native, vosk_recognizer_partial_result_dart>('vosk_recognizer_partial_result');
  late final vosk_recognizer_final_result = _dylib.lookupFunction<vosk_recognizer_final_result_native, vosk_recognizer_final_result_dart>('vosk_recognizer_final_result');

  late final vosk_recognizer_set_grm = _dylib.lookupFunction<vosk_recognizer_set_grm_native, vosk_recognizer_set_grm_dart>('vosk_recognizer_set_grm');
  late final vosk_recognizer_reset = _dylib.lookupFunction<vosk_recognizer_reset_native, vosk_recognizer_reset_dart>('vosk_recognizer_reset');
  late final vosk_recognizer_free = _dylib.lookupFunction<vosk_recognizer_free_native, vosk_recognizer_free_dart>('vosk_recognizer_free');
}
