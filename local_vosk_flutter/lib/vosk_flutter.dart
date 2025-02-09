// Questo è il file principale della libreria che espone tutte le API pubbliche
library local_vosk_flutter;

// Esportiamo tutte le classi e funzioni necessarie dai moduli interni
export 'src/model.dart';
export 'src/model_loader.dart';
export 'src/recognizer.dart';
export 'src/speech_service.dart'; // Esportiamo solo la versione in src/speech_service.dart
export 'src/utils.dart';

// Esportiamo la classe principale VoskFlutterPlugin da vosk_flutter.dart
export 'src/vosk_flutter.dart' show VoskFlutterPlugin, MicrophoneAccessDeniedException;