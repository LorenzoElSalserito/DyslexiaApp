// lib/utils/custom_linux_recorder.dart

import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'fmedia_path_config.dart';

/// Custom recorder per Linux che supporta diverse librerie di registrazione.
class CustomLinuxRecorder {
  Process? _recordProcess;
  bool _isRecording = false;
  late String _fmediaPath;
  bool _hasFmedia = false;
  bool _hasArecord = false;
  bool _hasSox = false;
  String _currentRecordingPath = '';

  // Stream controller per il livello di ampiezza audio
  final _amplitudeController = StreamController<double>.broadcast();
  Timer? _fakeAmplitudeTimer;
  final Random _random = Random();

  // Getter per lo stream di ampiezza audio
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  // Inizializza il recorder cercando i programmi disponibili
  Future<void> initialize() async {
    if (!Platform.isLinux) {
      debugPrint('CustomLinuxRecorder: Non è una piattaforma Linux, niente da fare');
      return;
    }

    // Controlla prima la disponibilità di arecord (preferito)
    try {
      final result = await Process.run('which', ['arecord']);
      _hasArecord = result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty;
      debugPrint('CustomLinuxRecorder: arecord disponibile: $_hasArecord');
    } catch (e) {
      debugPrint('CustomLinuxRecorder: Errore nel controllo di arecord: $e');
      _hasArecord = false;
    }

    // Controlla la disponibilità di fmedia (backup)
    _fmediaPath = await FmediaPathConfig.findFmediaPath();
    _hasFmedia = _fmediaPath.isNotEmpty;
    if (_hasFmedia) {
      debugPrint('CustomLinuxRecorder: fmedia trovato in: $_fmediaPath');
    } else {
      debugPrint('CustomLinuxRecorder: fmedia non trovato');
    }

    // Controlla sox (Sound eXchange)
    try {
      final result = await Process.run('which', ['sox']);
      _hasSox = result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty;
      debugPrint('CustomLinuxRecorder: sox disponibile: $_hasSox');
    } catch (e) {
      debugPrint('CustomLinuxRecorder: Errore nel controllo di sox: $e');
      _hasSox = false;
    }

    debugPrint('CustomLinuxRecorder: Inizializzazione completata. Preferenze: arecord > fmedia > sox');
  }

  // Modifica il metodo start per usare arecord per primo quando disponibile
  Future<bool> start(String outputPath) async {
    if (_isRecording) {
      debugPrint('CustomLinuxRecorder: Registrazione già in corso');
      return true;
    }

    try {
      // Memorizza il percorso di output per uso futuro
      _currentRecordingPath = outputPath;

      final directory = path.dirname(outputPath);
      await Directory(directory).create(recursive: true);

      // Assicuriamoci che il percorso sia assoluto
      final absolutePath = path.absolute(outputPath);
      debugPrint('CustomLinuxRecorder: Path assoluto per la registrazione: $absolutePath');

      // Privilegia arecord quando disponibile
      if (_hasArecord) {
        await _startArecordRecording(absolutePath);
      } else if (_hasFmedia) {
        await _startFmediaRecording(absolutePath);
      } else if (_hasSox) {
        await _startSoxRecording(absolutePath);
      } else {
        debugPrint('CustomLinuxRecorder: Nessun programma di registrazione disponibile su Linux');
        throw Exception('Nessun programma di registrazione trovato su Linux');
      }

      _isRecording = true;
      _startFakeAmplitudeTimer();
      debugPrint('CustomLinuxRecorder: Registrazione avviata in $absolutePath');
      return true;
    } catch (e) {
      debugPrint('CustomLinuxRecorder: Errore nell\'avvio della registrazione: $e');
      return false;
    }
  }

  // Ferma la registrazione corrente
  Future<String?> stop() async {
    if (!_isRecording || _recordProcess == null) {
      debugPrint('CustomLinuxRecorder: Nessuna registrazione in corso');
      return null;
    }

    try {
      // Ferma la generazione di ampiezze simulate
      _stopFakeAmplitudeTimer();

      // Invia segnale SIGTERM al processo
      _recordProcess!.kill();

      // Attendi che il processo termini
      await _recordProcess!.exitCode.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('CustomLinuxRecorder: Timeout nell\'arresto del processo, forzo la chiusura');
            _recordProcess!.kill(ProcessSignal.sigkill);
            return -1;
          }
      );

      _recordProcess = null;
      _isRecording = false;
      debugPrint('CustomLinuxRecorder: Registrazione fermata');

      // Verifica che il file esista
      final recordingFile = File(_currentRecordingPath);
      if (await recordingFile.exists()) {
        final fileSize = await recordingFile.length();
        debugPrint('CustomLinuxRecorder: File registrato con successo: $_currentRecordingPath (${fileSize} byte)');

        // IMPORTANTE: Restituisci il percorso del file e non la stringa "success"
        return _currentRecordingPath;
      } else {
        debugPrint('CustomLinuxRecorder: File non trovato dopo la registrazione: $_currentRecordingPath');
        return null;
      }
    } catch (e) {
      debugPrint('CustomLinuxRecorder: Errore nell\'arresto della registrazione: $e');
      _recordProcess = null;
      _isRecording = false;
      return null;
    }
  }

  // Avvia un timer che genera livelli di ampiezza simulati
  void _startFakeAmplitudeTimer() {
    _fakeAmplitudeTimer?.cancel();
    _fakeAmplitudeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
          (_) {
        // Genera un valore di ampiezza simulato tra 0.2 e 0.8
        final amplitude = 0.2 + (_random.nextDouble() * 0.6);
        _amplitudeController.add(amplitude);
      },
    );
  }

  // Ferma il timer delle ampiezze simulate
  void _stopFakeAmplitudeTimer() {
    _fakeAmplitudeTimer?.cancel();
    _fakeAmplitudeTimer = null;
  }

  // Avvia la registrazione con fmedia
  Future<void> _startFmediaRecording(String outputPath) async {
    // Configurazione ottimizzata per una buona registrazione
    final args = [
      '--record',
      '--out', outputPath,
      '--format=int16',         // Formato PCM 16-bit (compatibile con VOSK)
      '--rate=16000',           // Sample rate ottimo per il riconoscimento vocale
      '--channels=1',           // Mono (VOSK lavora meglio con audio mono)
      '--volume=125',           // Volume massimo consentito (0-125%)
      '--notui',                // Disattiva l'interfaccia testuale
      '--capture-buffer=500'    // Buffer di cattura di 500ms (riduce latenza)
    ];

    debugPrint('CustomLinuxRecorder: Eseguo fmedia con args: ${args.join(' ')}');

    // Prima di avviare, assicuriamoci che il percorso esista
    final directory = Directory(path.dirname(outputPath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Stampa il percorso di output per debug
    debugPrint('CustomLinuxRecorder: Path di output: $outputPath');

    // Avvia fmedia in un nuovo processo
    _recordProcess = await Process.start(_fmediaPath, args);
    _setupProcessLogging(_recordProcess!, 'fmedia');
  }

  // Avvia la registrazione con arecord
  Future<void> _startArecordRecording(String outputPath) async {
    // Configurazioni ottimali per arecord
    final args = [
      '-f', 'S16_LE',        // Formato PCM 16-bit little-endian
      '-r', '16000',         // Sample rate 16kHz
      '-c', '1',             // 1 canale (mono)
      '-D', 'default',       // Usa il dispositivo di input predefinito
      '--buffer-size=4096',  // Buffer size più grande per evitare overflow
      outputPath
    ];

    debugPrint('CustomLinuxRecorder: Eseguo arecord con args: ${args.join(' ')}');

    // Prima di avviare, assicuriamoci che il percorso esista
    final directory = Directory(path.dirname(outputPath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Stampa il percorso di output per debug
    debugPrint('CustomLinuxRecorder: Path di output per arecord: $outputPath');

    _recordProcess = await Process.start('arecord', args);
    _setupProcessLogging(_recordProcess!, 'arecord');
  }

  // Avvia la registrazione con sox
  Future<void> _startSoxRecording(String outputPath) async {
    final args = [
      '-d',  // Input dal dispositivo audio predefinito
      outputPath,
      'rate', '16000',
      'channels', '1',
    ];

    _recordProcess = await Process.start('sox', args);
    _setupProcessLogging(_recordProcess!, 'sox');
  }

  // Configura il logging dei messaggi di stdout e stderr del processo
  void _setupProcessLogging(Process process, String programName) {
    process.stdout.transform(const SystemEncoding().decoder).listen(
          (data) => debugPrint('$programName stdout: $data'),
    );
    process.stderr.transform(const SystemEncoding().decoder).listen(
          (data) => debugPrint('$programName stderr: $data'),
    );
  }

  // Rilascia le risorse
  void dispose() {
    if (_isRecording) {
      stop();
    }
    _stopFakeAmplitudeTimer();
    _amplitudeController.close();
  }

  // Getters pubblici
  bool get isRecording => _isRecording;
  bool get hasFmedia => _hasFmedia;
  bool get hasArecord => _hasArecord;
  bool get hasSox => _hasSox;
  bool get hasAnyRecorder => _hasFmedia || _hasArecord || _hasSox;
}