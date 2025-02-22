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
        final hasPermission = await _audioRecorder.hasPermission();
        if (!hasPermission) {
          throw Exception('Permessi audio non concessi');
        }
      } else {
        // Su Linux, macOS e Windows di solito non servono
        // richieste di permessi microfono con plugin mobile.
        debugPrint('AudioService: Nessuna richiesta permessi su ${Platform.operatingSystem}');
      }

      // Prepara la directory per le registrazioni
      final appDocDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(p.join(appDocDir.path, 'OpenDSA_recordings'));
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      _recordingPath = p.join(recordingsDir.path, 'recording.wav');

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
      throw Exception('AudioService non inizializzato. Chiama initialize() prima di registrare.');
    }
    if (_isRecording) {
      // Se stiamo già registrando, restituiamo semplicemente il path
      return _recordingPath;
    }

    try {
      _currentAttempt++;
      _progressController.add(_currentAttempt);

      // Configura e avvia la registrazione
      await _audioRecorder.start(
        encoder: AudioEncoder.wav,
        bitRate: _defaultBitRate,
        samplingRate: _defaultSampleRate,
        numChannels: _defaultNumChannels,
        path: _recordingPath,
      );

      _isRecording = true;
      _updateState(AudioState.recording);
      _startVolumeMonitoring();

      debugPrint('AudioService: Registrazione avviata (attempt $_currentAttempt)');
      return _recordingPath;
    } catch (e) {
      debugPrint('AudioService: Errore nell\'avvio della registrazione: $e');
      rethrow;
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
      await _audioRecorder.stop();

      _isRecording = false;
      _updateState(AudioState.stopped);

      debugPrint('AudioService: Registrazione fermata');
      return _recordingPath;
    } catch (e) {
      debugPrint('AudioService: Errore nello stop della registrazione: $e');
      rethrow;
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
          debugPrint('AudioService: Errore nel monitoraggio del volume: $err');
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

  /// Rilascia le risorse
  Future<void> dispose() async {
    if (_isRecording) {
      await stopRecording();
    }

    await _audioRecorder.dispose();
    await _volumeController.close();
    await _stateController.close();
    await _progressController.close();

    _isInitialized = false;
    debugPrint('AudioService: Risorse rilasciate');
  }
}
