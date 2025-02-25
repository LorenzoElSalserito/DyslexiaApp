// lib/services/audio_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

// Importa il tuo enum AudioState da models/enums.dart
import '../models/enums.dart';

/// Servizio che gestisce la registrazione audio per OpenDSA: Reading.
/// Utilizza il plugin 'record' per fornire una registrazione audio di alta qualità
/// ottimizzata per il riconoscimento vocale.
class AudioService {
  // Singleton pattern
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  // Costanti di configurazione audio
  static const int _defaultSampleRate = 16000;  // 16 kHz
  static const int _defaultBitRate = 16000;     // 16 kbps
  static const int _defaultNumChannels = 1;     // Mono

  // Costanti pubbliche per la gestione delle registrazioni
  static const int _maxAttempts = 5;
  static const Duration _delayBetweenRecordings = Duration(seconds: 3);

  // Getters pubblici per le costanti
  int get maxAttempts => _maxAttempts;
  Duration get delayBetweenRecordings => _delayBetweenRecordings;

  // Stato interno
  bool _isInitialized = false;
  bool _isRecording = false;
  int _currentAttempt = 0;
  Timer? _volumeTimer;
  late String _recordingPath;

  // Stream controllers per gli eventi in tempo reale
  final _volumeController = StreamController<double>.broadcast();
  final _stateController = StreamController<AudioState>.broadcast();
  final _progressController = StreamController<int>.broadcast();

  // Istanza del recorder
  final Record _audioRecorder = Record();

  // Costruttore privato per il singleton
  AudioService._internal();

  // Getters pubblici per lo stato
  Stream<double> get volumeLevel => _volumeController.stream;
  Stream<AudioState> get audioState => _stateController.stream;
  Stream<int> get recordingProgress => _progressController.stream;
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  int get currentAttempt => _currentAttempt;
  bool get isSessionComplete => _currentAttempt >= maxAttempts;

  /// Inizializza il servizio audio e verifica i permessi necessari
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('AudioService: Inizializzazione...');

      // Verifica i permessi di registrazione (solo per Android/iOS)
      if (Platform.isAndroid || Platform.isIOS) {
        final hasPermission = await _audioRecorder.hasPermission()
            .timeout(const Duration(seconds: 3), onTimeout: () {
          debugPrint('AudioService: Timeout nella verifica dei permessi');
          return false;
        });

        if (!hasPermission) {
          throw Exception('Permessi audio non concessi');
        }
      } else {
        // Su Linux, macOS e Windows di solito non servono
        // richieste di permessi microfono con plugin mobile.
        debugPrint('AudioService: Nessuna richiesta permessi su ${Platform.operatingSystem}');
      }

      // Prepara la directory per le registrazioni
      final appDocDir = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('AudioService: Timeout nell\'ottenimento della directory');
        throw Exception('Timeout nell\'accesso al filesystem');
      });

      final recordingsDir = Directory('${appDocDir.path}/OpenDSA_recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true)
            .timeout(const Duration(seconds: 3), onTimeout: () {
          debugPrint('AudioService: Timeout nella creazione della directory');
          throw Exception('Timeout nella creazione della directory');
        });
      }

      _recordingPath = '${recordingsDir.path}/recording.wav';

      _isInitialized = true;
      _updateState(AudioState.stopped);
      debugPrint('AudioService: Inizializzazione completata');
    } catch (e) {
      debugPrint('AudioService: Errore nell\'inizializzazione: $e');
      rethrow;
    }
  }

  /// Avvia una nuova registrazione audio
  Future<String> startRecording() async {
    if (!_isInitialized) {
      try {
        await initialize().timeout(const Duration(seconds: 3), onTimeout: () {
          debugPrint('AudioService: Timeout nell\'inizializzazione');
          return;
        });
      } catch (e) {
        debugPrint('AudioService: Errore nell\'inizializzazione: $e');
        return '';
      }
    }

    if (_isRecording) {
      // Se stiamo già registrando, restituiamo semplicemente il path
      return _recordingPath;
    }

    try {
      _currentAttempt++;
      _progressController.add(_currentAttempt);

      try {
        // Verificare se la registrazione precedente è ancora attiva e fermarla
        if (await _audioRecorder.isRecording()) {
          await stopRecording();
        }
      } catch (e) {
        // Ignora gli errori qui, potrebbe non esserci una registrazione attiva
        debugPrint('AudioService: Errore durante la verifica/stop della registrazione precedente: $e');
      }

      // Configura e avvia la registrazione con timeout
      await _audioRecorder.start(
        encoder: AudioEncoder.wav,
        bitRate: _defaultBitRate,
        samplingRate: _defaultSampleRate,
        numChannels: _defaultNumChannels,
        path: _recordingPath,
      ).timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('AudioService: Timeout nell\'avvio della registrazione');
        return;
      });

      _isRecording = true;
      _updateState(AudioState.recording);
      _startVolumeMonitoring();

      debugPrint('AudioService: Registrazione avviata (attempt $_currentAttempt)');
      return _recordingPath;
    } catch (e) {
      debugPrint('AudioService: Errore nell\'avvio della registrazione: $e');
      // Ritorniamo un path vuoto per segnalare il fallimento
      return '';
    }
  }

  /// Ferma la registrazione corrente
  Future<String> stopRecording() async {
    if (!_isRecording) {
      // Non stiamo registrando
      return '';
    }

    try {
      _stopVolumeMonitoring();

      // Gestione degli errori migliorata per le piattaforme Linux
      try {
        await _audioRecorder.stop().timeout(const Duration(seconds: 3), onTimeout: () {
          debugPrint('AudioService: Timeout nello stop della registrazione');
          return null;
        });
      } catch (e) {
        // Su Linux, potrebbe esserci un problema con fmedia, ma possiamo continuare
        debugPrint('AudioService: Errore nella chiamata a stop, ma continuiamo: $e');
        // Creare un file vuoto se necessario per evitare errori successivi
        try {
          final recordingFile = File(_recordingPath);
          if (!await recordingFile.exists()) {
            await recordingFile.writeAsBytes([]);
          }
        } catch (fileError) {
          debugPrint('AudioService: Errore nella creazione del file vuoto: $fileError');
        }
      }

      _isRecording = false;
      _updateState(AudioState.stopped);

      debugPrint('AudioService: Registrazione fermata');
      return _recordingPath;
    } catch (e) {
      debugPrint('AudioService: Errore nello stop della registrazione: $e');
      _isRecording = false;
      _updateState(AudioState.stopped);
      return '';
    }
  }

  /// Monitora il volume durante la registrazione
  void _startVolumeMonitoring() {
    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
          (timer) async {
        if (!_isRecording) return;

        try {
          final amplitude = await _audioRecorder.getAmplitude();
          // Il plugin 'record' fornisce un valore in dB, di solito tra -160 e 0
          // Convertiamolo in un valore normalizzato tra 0.0 e 1.0
          final volume = (amplitude.current + 160) / 160;
          _volumeController.add(volume.clamp(0.0, 1.0));
        } catch (err) {
          // Ignora errori nel monitoraggio del volume
          _volumeController.add(0.5); // Valore predefinito se c'è un errore
        }
      },
    );
  }

  void _stopVolumeMonitoring() {
    _volumeTimer?.cancel();
    _volumeTimer = null;
  }

  /// Aggiorna lo stato dell'audio e invia l'evento sullo stream
  void _updateState(AudioState newState) {
    _stateController.add(newState);
  }

  /// Reimposta lo stato del servizio
  Future<void> reset() async {
    try {
      debugPrint('AudioService: Reset chiamato');
      if (_isRecording) {
        try {
          await stopRecording();
        } catch (e) {
          debugPrint('AudioService: Errore nello stop della registrazione durante reset: $e');
          // Continuiamo anche in caso di errore nel fermare la registrazione
          _isRecording = false;
          _updateState(AudioState.stopped);
        }
      }
      _currentAttempt = 0;
      _progressController.add(_currentAttempt);
    } catch (e) {
      debugPrint('AudioService: Errore nel reset: $e');
    }
  }

  /// Rilascia le risorse
  Future<void> dispose() async {
    if (_isRecording) {
      try {
        await stopRecording();
      } catch (e) {
        debugPrint('AudioService: Errore nello stop della registrazione durante dispose: $e');
      }
    }

    try {
      await _audioRecorder.dispose();
    } catch (e) {
      debugPrint('AudioService: Errore nel dispose del recorder: $e');
    }

    await _volumeController.close();
    await _stateController.close();
    await _progressController.close();

    _isInitialized = false;
    debugPrint('AudioService: Risorse rilasciate');
  }
}