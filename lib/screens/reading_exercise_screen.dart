import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math' show min;
import '../config/app_config.dart';
import '../services/player_manager.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../services/exercise_manager.dart';
import '../services/speech_recognition_service.dart';
import '../models/recognition_result.dart';
import '../widgets/voice_recognition_feedback.dart';
import '../widgets/crystal_popup.dart';
import '../models/enums.dart';

class ReadingExerciseScreen extends StatefulWidget {
  const ReadingExerciseScreen({Key? key}) : super(key: key);

  @override
  _ReadingExerciseScreenState createState() => _ReadingExerciseScreenState();
}

class _ReadingExerciseScreenState extends State<ReadingExerciseScreen> {
  // Stato dell'esercizio
  String _currentWord = "";
  bool _isProcessing = false;
  String? _errorMessage;
  double _volumeLevel = 0.0;
  int _currentExercise = 0;
  final int _totalExercises = 5;
  int _totalCrystals = 0;
  bool _isInitialized = false;
  bool _isSessionStarted = false;

  // Variabili per lo stato di download del modello (eventuale)
  double _downloadProgressValue = 0.0;
  String _downloadStatusMessage = "";

  // Servizi
  late final ExerciseManager _exerciseManager;
  late final SpeechRecognitionService _speechService;

  // Stream subscriptions
  StreamSubscription<double>? _volumeSubscription;
  StreamSubscription? _speechStateSubscription;
  StreamSubscription<RecognitionResult>? _resultSubscription;

  @override
  void initState() {
    super.initState();
    // Recupera il manager degli esercizi (già fornito tramite Provider)
    _exerciseManager = Provider.of<ExerciseManager>(context, listen: false);
    // Istanzia il servizio unificato di riconoscimento vocale
    _speechService = SpeechRecognitionService();
    // Inizializza il servizio (richiede il BuildContext per i permessi)
    _initializeSession();
    // Ascolta lo stream del volume per aggiornare l'UI
    _volumeSubscription = _speechService.volumeStream.listen((volume) {
      if (mounted) {
        setState(() {
          _volumeLevel = volume;
        });
      }
    });
    // Ascolta lo stato del riconoscimento (utile per aggiornare il bottone)
    _speechStateSubscription = _speechService.stateStream.listen((state) {
      if (mounted) setState(() {});
    });
    // Ascolta il risultato del riconoscimento e lo gestisce
    _resultSubscription = _speechService.resultStream.listen((result) async {
      await _handleRecognitionResult(result);
    });
  }

  Future<void> _initializeSession() async {
    if (!mounted) return;
    try {
      // Inizializza il servizio di riconoscimento (che a sua volta inizializza audio e VOSK)
      await _speechService.initialize(context);
      // Avvia una nuova sessione di esercizi
      await _exerciseManager.startNewSession();
      _isSessionStarted = true;
      await _loadNewExercise();
      if (mounted) setState(() => _isInitialized = true);
      debugPrint('[ReadingExerciseScreen] Sessione inizializzata.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
        _errorMessage = 'Errore nell\'inizializzazione: $e';
      });
    }
  }

  /// Carica un nuovo esercizio tramite l'ExerciseManager
  Future<void> _loadNewExercise() async {
    if (!mounted) return;
    try {
      final exercise = await _exerciseManager.generateExercise();
      if (!mounted) return;
      setState(() {
        _currentWord = exercise.content;
        _isProcessing = false;
        _currentExercise++;
      });
      debugPrint('[ReadingExerciseScreen] Nuovo esercizio caricato: $_currentWord');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Errore nel caricamento dell\'esercizio: $e';
      });
    }
  }

  /// Gestisce l'azione del bottone: se il servizio è idle o in attesa, avvia la registrazione;
  /// se è in stato di registrazione, la ferma.
  Future<void> _onRecordButtonPressed() async {
    if (_speechService.currentState == RecognitionState.idle ||
        _speechService.currentState == RecognitionState.waiting) {
      try {
        await _speechService.startRecognition(_currentWord);
      } catch (e) {
        setState(() {
          _errorMessage = 'Errore nell\'avvio del riconoscimento: $e';
        });
      }
    } else if (_speechService.currentState == RecognitionState.recording) {
      try {
        await _speechService.stopRecognition();
      } catch (e) {
        setState(() {
          _errorMessage = 'Errore nello stop del riconoscimento: $e';
        });
      }
    }
  }

  /// Gestisce il risultato del riconoscimento vocale e aggiorna la sessione
  Future<void> _handleRecognitionResult(RecognitionResult result) async {
    if (!mounted) return;
    try {
      final playerManager = Provider.of<PlayerManager>(context, listen: false);
      final Player? player = playerManager.currentProfile;
      if (player == null) {
        throw Exception("Nessun profilo attivo.");
      }
      final gameService = Provider.of<GameService>(context, listen: false);

      // Processa il risultato tramite ExerciseManager e ottiene i cristalli guadagnati
      final crystalsEarned = await _exerciseManager.processExerciseResult(result);
      setState(() => _totalCrystals += crystalsEarned);
      debugPrint('[ReadingExerciseScreen] Risultato processato. Cristalli guadagnati: $crystalsEarned');

      // Mostra il popup di feedback
      await _showFeedbackPopup(result, crystalsEarned, player.currentLevel);

      // Se la sessione è completa, mostra il riepilogo, altrimenti carica un nuovo esercizio
      if (_currentExercise >= _totalExercises) {
        await _showSessionSummary();
      } else {
        await _loadNewExercise();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Errore nell\'elaborazione del risultato: $e';
        _isProcessing = false;
      });
    }
  }

  /// Mostra il popup di feedback dopo ogni esercizio
  Future<void> _showFeedbackPopup(RecognitionResult result, int crystalsEarned, int level) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CrystalPopup(
        earnedCrystals: crystalsEarned,
        level: level,
        progress: result.similarity,
        recognitionResult: result,
      ),
    );
  }

  /// Mostra il riepilogo della sessione e gestisce la decisione di continuare o uscire
  Future<void> _showSessionSummary() async {
    if (!mounted) return;
    try {
      final double overallAccuracy = _exerciseManager.overallAccuracy;
      final playerManager = Provider.of<PlayerManager>(context, listen: false);
      final int currentLevel = playerManager.currentProfile?.currentLevel ?? 1;

      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return CrystalPopup(
            earnedCrystals: _totalCrystals,
            level: currentLevel,
            progress: overallAccuracy,
            isSessionSummary: true,
            recognitionResult: RecognitionResult(
              text: '',
              confidence: 1.0,
              similarity: overallAccuracy,
              isCorrect: overallAccuracy >= 0.75,
              duration: const Duration(seconds: 1),
            ),
          );
        },
      );
      if (!mounted) return;
      if (shouldContinue == true) {
        setState(() {
          _currentExercise = 0;
          _totalCrystals = 0;
          _isSessionStarted = false;
        });
        await _initializeSession();
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Errore nel mostrare il riepilogo: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stato di caricamento o errore
    if (!_isInitialized || !_isSessionStarted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'OpenDSA: Reading',
            style: TextStyle(fontFamily: 'OpenDyslexic'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_downloadProgressValue > 0.0 && _downloadProgressValue < 1.0) ...[
                Text('${(_downloadProgressValue * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'OpenDyslexic',
                      color: Colors.black87,
                    )),
                const SizedBox(height: 12),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(value: _downloadProgressValue),
                ),
                const SizedBox(height: 24),
              ],
              if (_downloadStatusMessage.isNotEmpty) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    _downloadStatusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: AppConfig.title,
                      fontFamily: 'OpenDyslexic',
                      color: Colors.black87,
                    ),
                  ),
                ),
              ] else if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontFamily: 'OpenDyslexic',
                  ),
                )
              else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    // UI principale dell'esercizio
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OpenDSA: Reading',
          style: TextStyle(fontFamily: 'OpenDyslexic'),
        ),
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (_speechService.currentState == RecognitionState.recording) {
            await _speechService.stopRecognition();
            return false;
          }
          return true;
        },
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade900, Colors.blue.shade800],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 32.0,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              LinearProgressIndicator(
                                value: _currentExercise / _totalExercises,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _speechService.currentState == RecognitionState.recording
                                      ? Colors.red.shade700
                                      : Colors.green.shade500,
                                ),
                              ),
                              Text(
                                'Esercizio $_currentExercise di $_totalExercises',
                                style: const TextStyle(
                                  fontSize: AppConfig.title,
                                  fontFamily: 'OpenDyslexic',
                                  color: Colors.white,
                                ),
                              ),
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _currentWord,
                                      style: const TextStyle(
                                        fontSize: AppConfig.title,
                                        fontFamily: 'OpenDyslexic',
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_speechService.currentState == RecognitionState.recording)
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 1.0, end: 1.0 + _volumeLevel * 0.5),
                                  duration: const Duration(milliseconds: 300),
                                  builder: (context, scale, child) => Transform.scale(
                                    scale: scale,
                                    child: child,
                                  ),
                                  child: VoiceRecognitionFeedback(
                                    isRecording: true,
                                    volumeLevel: _volumeLevel,
                                    targetText: _currentWord,
                                  ),
                                ),
                              if (!_isProcessing)
                                ElevatedButton(
                                  onPressed: _onRecordButtonPressed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _speechService.currentState == RecognitionState.recording
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    textStyle: const TextStyle(fontSize: AppConfig.title),
                                  ),
                                  child: Text(
                                    _speechService.currentState == RecognitionState.recording
                                        ? 'Stop'
                                        : 'Registra',
                                    style: const TextStyle(fontFamily: 'OpenDyslexic'),
                                  ),
                                )
                              else
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.yellowAccent.shade700),
                                ),
                              if (_errorMessage != null)
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Eventuale banner overlay per lo stato del download del modello
            if (_downloadStatusMessage.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _downloadStatusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppConfig.subtitle,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _volumeSubscription?.cancel();
    _speechStateSubscription?.cancel();
    _resultSubscription?.cancel();
    // Se la registrazione è in corso, termina il riconoscimento
    if (_speechService.currentState == RecognitionState.recording) {
      _speechService.stopRecognition();
    }
    _speechService.dispose();
    super.dispose();
  }
}
