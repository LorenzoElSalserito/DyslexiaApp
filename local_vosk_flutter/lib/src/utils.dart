import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Helper function to run a function with an Arena, then dispose it.
T runUsing<T>(T Function(Arena arena) f) {
  final arena = Arena();
  try {
    return f(arena);
  } finally {
    arena.releaseAll();  // Cambiato da dispose() a release()
  }
}

/// Extension for Float32List to convert it to a Pointer<Float>.
extension Float32ListToPointer on Float32List {
  /// Converts this Float32List into a Pointer<Float> using the provided [allocator].
  Pointer<Float> toFloatPtr(Allocator allocator) {
    final ptr = allocator<Float>(length);
    final list = ptr.asTypedList(length);
    list.setAll(0, this);
    return ptr;
  }
}

/// Extension on String to convert it to a null-terminated UTF8 pointer.
/// Questa estensione è già fornita da package:ffi, quindi la rimuoviamo
/// e usiamo quella del package.


/// Convert Int16 PCM audio samples to float values
Float32List convertPcm16ToFloat32(Uint8List pcmData) {
  if (pcmData.length % 2 != 0) {
    throw ArgumentError('PCM data length must be even');
  }

  final floatData = Float32List(pcmData.length ~/ 2);
  for (var i = 0; i < pcmData.length ~/ 2; i++) {
    final pcmValue = pcmData[i * 2] | (pcmData[i * 2 + 1] << 8);
    floatData[i] = (pcmValue < 32768 ? pcmValue : pcmValue - 65536) / 32768.0;
  }
  return floatData;
}

/// Classe di utilità per le operazioni comuni
class VoskUtils {
  /// Converte un valore PCM 16-bit in float32
  static double pcm16ToFloat32(int pcm16) {
    return (pcm16 < 32768 ? pcm16 : pcm16 - 65536) / 32768.0;
  }

  /// Converte un valore float32 in PCM 16-bit
  static int float32ToPcm16(double float32) {
    final pcm16 = (float32 * 32768).round();
    return pcm16 < -32768 ? -32768 : (pcm16 > 32767 ? 32767 : pcm16);
  }
}