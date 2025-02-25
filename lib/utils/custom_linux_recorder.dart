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

    // Controlla la disponibilità di fmedia (preferito)
    _fmediaPath = await FmediaPathConfig.findFmediaPath();
    _hasFmedia = _fmediaPath.isNotEmpty;
    if (_hasFmedia) {
      debugPrint('CustomLinuxRecorder: fmedia trovato in: $_fmediaPath');
    } else {
      debugPrint('CustomLinuxRecorder: fmedia non trovato');
    }

    // Controlla arecord (parte di ALSA)
    try {
      final result = await Process.run('which', ['arecord']);
      _hasArecord = result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty;
      debugPrint('CustomLinuxRecorder: arecord disponibile: $_hasArecord');
    } catch (e) {
      debugPrint('CustomLinuxRecorder: Errore nel controllo di arecord: $e');
      _hasArecord = false;
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

    debugPrint('CustomLinuxRecorder: Inizializzazione completata');
  }

  // Avvia la registrazione usando il primo programma disponibile
  Future<bool> start(String outputPath) async {
    if (_isRecording) {
      debugPrint('CustomLinuxRecorder: Registrazione già in corso');
      return true;
    }

    try {
      final directory = path.dirname(outputPath);
      await Directory(directory).create(recursive: true);

      if (_hasFmedia) {
        await _startFmediaRecording(outputPath);
      } else if (_hasArecord) {
        await _startArecordRecording(outputPath);
      } else if (_hasSox) {
        await _startSoxRecording(outputPath);
      } else {
        debugPrint('CustomLinuxRecorder: Nessun programma di registrazione disponibile su Linux');
        throw Exception('Nessun programma di registrazione trovato su Linux');
      }

      _isRecording = true;
      _startFakeAmplitudeTimer(); // Avvia lo stream di ampiezze simulate
      debugPrint('CustomLinuxRecorder: Registrazione avviata');
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
      return 'success'; // Restituisce una stringa invece di void per compatibilità con l'interfaccia
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
    // CORRETTO: Uso del comando semplice senza opzioni di formato
    // In base ai test, fmedia funziona quando viene usato con il comando minimo
    final args = [
      '--record',
      '--out', outputPath
    ];

    debugPrint('CustomLinuxRecorder: Eseguo fmedia con args: ${args.join(' ')}');
    _recordProcess = await Process.start(_fmediaPath, args);
    _setupProcessLogging(_recordProcess!, 'fmedia');
  }

  // Avvia la registrazione con arecord
  Future<void> _startArecordRecording(String outputPath) async {
    final args = [
      '-f', 'S16_LE',
      '-r', '16000',
      '-c', '1',
      outputPath,
    ];

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