import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import '../config/app_config.dart';

enum AudioState { stopped, recording, paused }

class AudioService {
  // Gestione del registratore audio
  late FlutterSoundRecorder _recorder;
  bool _isInitialized = false;
  AudioState _state = AudioState.stopped;
  late String _recordingPath;

  // Gestione degli stream per il feedback in tempo reale
  StreamSubscription? _recorderSubscription;
  final _volumeLevelController = StreamController<double>.broadcast();
  final _stateController = StreamController<AudioState>.broadcast();

  // Costruttore che inizializza il registratore di base
  AudioService() {
    _recorder = FlutterSoundRecorder();
  }

  // Getters pubblici per accedere agli stream e allo stato
  Stream<double> get volumeLevel => _volumeLevelController.stream;
  Stream<AudioState> get audioState => _stateController.stream;
  AudioState get currentState => _state;

  // Inizializzazione del servizio audio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Su Linux non serve il controllo dei permessi
      await _recorder.openRecorder();

      // Configurazione del registratore con un intervallo di aggiornamento di 100ms
      // per avere un feedback fluido del livello del volume
      await _recorder.setSubscriptionDuration(
          const Duration(milliseconds: 100)
      );

      // Preparazione del percorso di registrazione nella directory temporanea
      final tempDir = await _getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/temp_recording.wav';

      _isInitialized = true;
      _updateState(AudioState.stopped);
    } catch (e) {
      print('Errore nell\'inizializzazione dell\'AudioService: $e');
      rethrow;
    }
  }

  // Ottiene la directory temporanea per salvare le registrazioni
  Future<Directory> _getTemporaryDirectory() async {
    final tempDir = await Directory.systemTemp.createTemp();
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    return tempDir;
  }

  // Avvia la registrazione audio con i parametri configurati in AppConfig
  Future<void> startRecording() async {
    if (!_isInitialized) await initialize();
    if (_state == AudioState.recording) return;

    try {
      // Configurazione e avvio della registrazione con parametri ottimizzati
      // per il riconoscimento vocale
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,        // Formato WAV non compresso per migliore qualità
        sampleRate: AppConfig.sampleRate,  // Frequenza di campionamento configurabile
        numChannels: AppConfig.channels,   // Mono per riconoscimento vocale
      );

      // Monitoraggio del livello del volume in tempo reale
      _recorderSubscription = _recorder.onProgress!.listen((event) {
        if (event.decibels != null) {
          // Normalizzazione dei decibel in un valore tra 0 e 1
          // La formula considera che i decibel tipicamente variano tra -160 e 0
          final normalizedLevel = (event.decibels! + 160) / 160;
          _volumeLevelController.add(normalizedLevel.clamp(0.0, 1.0));
        }
      });

      _updateState(AudioState.recording);
    } catch (e) {
      print('Errore nell\'avvio della registrazione: $e');
      _updateState(AudioState.stopped);
      rethrow;
    }
  }

  // Ferma la registrazione audio e restituisce il percorso del file registrato
  Future<String> stopRecording() async {
    if (!_isInitialized || _state != AudioState.recording) return '';

    try {
      // Pulizia della sottoscrizione agli eventi di progresso
      await _recorderSubscription?.cancel();
      _recorderSubscription = null;

      // Stop della registrazione e recupero del percorso del file
      final recordingResult = await _recorder.stopRecorder();
      _updateState(AudioState.stopped);

      return recordingResult ?? '';
    } catch (e) {
      print('Errore nello stop della registrazione: $e');
      _updateState(AudioState.stopped);
      rethrow;
    }
  }

  // Aggiorna lo stato interno e notifica tutti gli ascoltatori del cambiamento
  void _updateState(AudioState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  // Rilascio delle risorse quando il servizio viene distrutto
  Future<void> dispose() async {
    try {
      // Ferma qualsiasi registrazione in corso
      await stopRecording();

      // Cancella tutte le sottoscrizioni e gli stream
      await _recorderSubscription?.cancel();
      await _recorder.closeRecorder();
      await _volumeLevelController.close();
      await _stateController.close();

      // Resetta lo stato del servizio
      _isInitialized = false;
      _state = AudioState.stopped;
    } catch (e) {
      print('Errore nella dispose dell\'AudioService: $e');
    }
  }
}