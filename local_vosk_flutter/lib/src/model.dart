import 'dart:ffi';
import 'package:flutter/services.dart';
import 'generated_vosk_bindings.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

/// Define VoskModel as an alias for Void.
typedef VoskModel = Void;

/// Class representing a VOSK model.
class Model {
  /// Use VoskFlutterPlugin.createModel to create an instance.
  Model(this.path, this._channel, [this.modelPointer, this._voskLibrary]);

  /// The file system path to the model.
  final String path;

  /// Pointer to the native model.
  final Pointer<VoskModel>? modelPointer;

  final VoskLibrary? _voskLibrary;
  final MethodChannel _channel;

  /// Frees the model resources.
  void dispose() {
    if (_voskLibrary != null && modelPointer != null) {
      _voskLibrary!.vosk_model_free(modelPointer!);
    }
  }

  @override
  String toString() {
    return 'Model[path=$path, pointer=$modelPointer]';
  }
}
