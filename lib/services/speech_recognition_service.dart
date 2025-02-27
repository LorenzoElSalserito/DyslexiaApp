// lib/services/speech_recognition_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recognition_result.dart';
import '../services/audio_service.dart';
import '../services/vosk_service.dart';
import '../utils/custom_linux_recorder.dart';

/// Stati possibili del servizio di riconoscimento vocale
enum RecognitionState {
  initializing,  // Inizializzazione in corso
  idle,          // Pronto ma non in uso
  recording,     // Registrazione attiva
  processing,    // Elaborazione audio in corso
  completed,     // Riconoscimento completato
  error          // Errore
}

/// Servizio per il riconoscimento vocale che coordina la registrazione audio
/// e il processamento tramite il modello VOSK.
class SpeechRecognitionService {
  // Servizi utilizzati
  final AudioService _audioService = AudioService();
  final VoskService _voskService = VoskService.instance;
  CustomLinuxRecorder? _linuxRecorder; // Per Linux

  // Stream controllers
  final _stateController = StreamController<RecognitionState>.broadcast();
  final _resultController = StreamController<RecognitionResult>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _volumeController = StreamController<double>.broadcast();

  // Stato corrente
  RecognitionState _currentState = RecognitionState.idle;
  String? _currentTarget;
  String? _recordingPath;
  bool _isInitialized = false;

  // Stream pubblici
  Stream<RecognitionState> get stateStream => _stateController.stream;
  Stream<RecognitionResult> get resultStream => _resultController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<double> get volumeStream => _volumeController.stream;

  // Getters
  RecognitionState get currentState => _currentState;
  AudioService get audioService => _audioService;

  /// Inizializza il servizio
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) {
      debugPrint('SpeechRecognitionService: Già inizializzato');
      return;
    }

    debugPrint('SpeechRecognitionService: Inizializzazione');
    _updateState(RecognitionState.initializing);

    try {
      // Inizializza prima l'audio service
      await _audioService.initialize();

      // Su Linux, inizializza anche il recorder personalizzato
      if (Platform.isLinux) {
        _linuxRecorder = CustomLinuxRecorder();
        await _linuxRecorder!.initialize();

        // Inoltra gli eventi di volume dal recorder Linux
        _linuxRecorder!.amplitudeStream.listen((level) {
          _volumeController.add(level);
        });
      }

      // Inizializza VOSK
      await _voskService.initialize(context: context);

      // Inoltra gli eventi di volume dall'audioService
      _audioService.volumeLevel.listen((volume) {
        _volumeController.add(volume);
      });

      _isInitialized = true;
      _updateState(RecognitionState.idle);
      debugPrint('SpeechRecognitionService: Inizializzazione completata');
    } catch (e) {
      _emitError('Errore nell\'inizializzazione: $e');
      _updateState(RecognitionState.error);
      rethrow;
    }
  }

  /// Avvia il riconoscimento per il testo target
  Future<void> startRecognition(String targetText) async {
    if (_currentState == RecognitionState.recording ||
        _currentState == RecognitionState.processing) {
      _emitError('Riconoscimento già in corso');
      return;
    }

    if (!_isInitialized) {
      _emitError('Servizio non inizializzato');
      return;
    }

    _currentTarget = targetText;
    _updateState(RecognitionState.recording);

    try {
      // Generazione di un path unico basato sul timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final appDocDir = await getApplicationDocumentsDirectory();
      final recordingDir = Directory('${appDocDir.path}/OpenDSA_recordings');
      if (!await recordingDir.exists()) {
        await recordingDir.create(recursive: true);
      }

      // Utilizziamo lo stesso percorso per tutte le piattaforme
      _recordingPath = '${recordingDir.path}/recording_$timestamp.wav';
      debugPrint('SpeechRecognitionService: Percorso di registrazione generato: $_recordingPath');

      if (Platform.isLinux && _linuxRecorder != null) {
        // Su Linux, passa il percorso generato al recorder personalizzato
        final started = await _linuxRecorder!.start(_recordingPath!);
        if (!started) {
          throw Exception('Impossibile avviare la registrazione con il recorder personalizzato');
        }
      } else {
        // Su altre piattaforme, usa AudioService con lo stesso percorso
        await _audioService.startRecording();
        if (_recordingPath == null || _recordingPath!.isEmpty) {
          throw Exception('Impossibile avviare la registrazione');
        }
      }
    } catch (e) {
      _emitError('Errore nell\'avvio della registrazione: $e');
      _updateState(RecognitionState.error);
    }
  }

  /// Ferma la registrazione e avvia l'elaborazione
  Future<void> stopRecognition() async {
    if (_currentState != RecognitionState.recording) {
      _emitError('Nessuna registrazione attiva');
      return;
    }

    _updateState(RecognitionState.processing);

    try {
      String? actualRecordingPath = null;

      if (Platform.isLinux && _linuxRecorder != null) {
        // Su Linux, usa il recorder personalizzato
        actualRecordingPath = await _linuxRecorder!.stop();
        if (actualRecordingPath == null) {
          throw Exception('Errore nello stop della registrazione Linux');
        }
        // Importante: aggiorna il percorso di registrazione con quello effettivamente usato
        _recordingPath = actualRecordingPath;
        debugPrint('SpeechRecognitionService: Percorso file aggiornato a: $_recordingPath');
      } else {
        // Su altre piattaforme, usa AudioService
        _recordingPath = await _audioService.stopRecording();
        if (_recordingPath == null || _recordingPath!.isEmpty) {
          throw Exception('Errore nel fermare la registrazione');
        }
      }

      // Verifica che il file esista prima di procedere
      final audioFile = File(_recordingPath!);
      if (!await audioFile.exists()) {
        throw Exception('File audio non trovato dopo la registrazione: $_recordingPath');
      }

      final fileSize = await audioFile.length();
      debugPrint('SpeechRecognitionService: File audio trovato, dimensione: $fileSize byte');

      await _processRecording();
    } catch (e) {
      _emitError('Errore nello stop della registrazione: $e');
      _updateState(RecognitionState.error);
    }
  }

  /// Elabora la registrazione per il riconoscimento
  Future<void> _processRecording() async {
    if (_recordingPath == null || _currentTarget == null) {
      _emitError('Dati di registrazione mancanti');
      _updateState(RecognitionState.error);
      return;
    }

    try {
      // Usa il servizio VOSK per il riconoscimento
      final result = await _voskService.startRecognition(_currentTarget!, _recordingPath!);

      // Emetti il risultato
      _resultController.add(result);
      _updateState(RecognitionState.completed);

      // Elimina il file audio dopo l'elaborazione
      await _deleteRecordingFile(_recordingPath!);
    } catch (e) {
      _emitError('Errore nel processamento dell\'audio: $e');

      // Crea un risultato fallback con similarità bassa
      final fallbackResult = RecognitionResult(
        text: 'errore nel riconoscimento',
        confidence: 0.1,
        similarity: 0.0,
        isCorrect: false,
        duration: const Duration(seconds: 1),
      );

      _resultController.add(fallbackResult);
      _updateState(RecognitionState.completed);

      // Tenta comunque di eliminare il file
      await _deleteRecordingFile(_recordingPath!);
    }
  }

  /// Elimina il file di registrazione per risparmiare spazio
  Future<void> _deleteRecordingFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('SpeechRecognitionService: File di registrazione eliminato: $filePath');
      }
    } catch (e) {
      debugPrint('SpeechRecognitionService: Errore nell\'eliminazione del file di registrazione: $e');
      // Non solleviamo l'errore per non interrompere il flusso dell'app
    }
  }

  /// Reimposta lo stato del servizio
  Future<void> reset() async {
    debugPrint('SpeechRecognitionService: Reset chiamato');

    try {
      // Ferma qualsiasi registrazione in corso
      if (_currentState == RecognitionState.recording) {
        try {
          if (Platform.isLinux && _linuxRecorder != null) {
            await _linuxRecorder!.stop();
          } else {
            await _audioService.stopRecording();
          }
        } catch (e) {
          // Ignora gli errori qui
          debugPrint('SpeechRecognitionService: Errore fermando la registrazione durante reset: $e');
        }
      }

      // Resetta l'audio service
      try {
        await _audioService.reset();
      } catch (e) {
        // Ignora gli errori qui
        debugPrint('SpeechRecognitionService: Errore nel reset dell\'audio service: $e');
      }

      _currentTarget = null;
      _recordingPath = null;
      _updateState(RecognitionState.idle);
    } catch (e) {
      _emitError('Errore nel reset: $e');
      _updateState(RecognitionState.error);
    }
  }

  /// Aggiorna lo stato e notifica gli ascoltatori
  void _updateState(RecognitionState state) {
    _currentState = state;
    _stateController.add(state);
    debugPrint('SpeechRecognitionService: Stato aggiornato a $state');
  }

  /// Emette un errore sullo stream di errori
  void _emitError(String message) {
    debugPrint('SpeechRecognitionService: ERRORE - $message');
    _errorController.add(message);
  }

  /// Rilascia le risorse del servizio
  Future<void> dispose() async {
    try {
      if (_currentState == RecognitionState.recording) {
        try {
          if (Platform.isLinux && _linuxRecorder != null) {
            await _linuxRecorder!.stop();
          } else {
            await _audioService.stopRecording();
          }
        } catch (e) {
          // Ignora errori qui
        }
      }

      if (_linuxRecorder != null) {
        _linuxRecorder!.dispose();
      }

      await _audioService.dispose();

      await _stateController.close();
      await _resultController.close();
      await _errorController.close();
      await _volumeController.close();

      _isInitialized = false;
    } catch (e) {
      debugPrint('SpeechRecognitionService: Errore nel dispose: $e');
    }
  }
}