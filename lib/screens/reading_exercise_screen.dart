// lib/screens/reading_exercise_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/player_manager.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../services/vosk_service.dart';
import '../services/audio_service.dart';
import '../services/exercise_manager.dart';
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
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _errorMessage;
  double _volumeLevel = 0.0;
  int _currentExercise = 0;
  final int _totalExercises = 5;
  double _sessionAccuracy = 0.0;
  int _totalCrystals = 0;
  bool _isInitialized = false;
  bool _isSessionStarted = false;

  // Servizi
  late final VoskService _voskService;
  late final AudioService _audioService;
  late final ExerciseManager _exerciseManager;

  // Stream subscriptions
  StreamSubscription? _volumeSubscription;

  @override
  void initState() {
    super.initState();
    _voskService = VoskService.instance;
    _audioService = AudioService();
    _exerciseManager = Provider.of<ExerciseManager>(context, listen: false);
    _initializeSession();
  }

  /// Inizializza la sessione e prepara tutti i servizi necessari.
  Future<void> _initializeSession() async {
    if (!mounted) return;
    try {
      await Future.wait([
        _voskService.initialize(),
        _audioService.initialize(),
      ]);
      _volumeSubscription = _audioService.volumeLevel.listen((volume) {
        if (mounted) {
          setState(() => _volumeLevel = volume);
        }
      });
      await _exerciseManager.startNewSession();
      _isSessionStarted = true;
      await _loadNewExercise();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
      debugPrint('[ReadingExerciseScreen] Sessione inizializzata.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
        _errorMessage = 'Errore nell\'inizializzazione: $e';
      });
    }
  }

  /// Carica un nuovo esercizio
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

  /// Avvia la registrazione audio
  Future<void> _startRecording() async {
    if (_isRecording || _isProcessing || !mounted) return;
    try {
      await _audioService.startRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _errorMessage = null;
      });
      debugPrint('[ReadingExerciseScreen] Registrazione avviata.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Errore nell\'avvio della registrazione: $e';
      });
    }
  }

  /// Ferma la registrazione e processa il risultato
  Future<void> _stopRecording() async {
    if (!_isRecording || !mounted) return;
    try {
      setState(() => _isProcessing = true);
      final audioPath = await _audioService.stopRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (audioPath.isNotEmpty) {
        // Utilizzo il flusso unificato per processare il risultato
        final result = await _voskService.startRecognition(_currentWord);
        await _handleRecognitionResult(result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Errore nella registrazione: $e';
        _isProcessing = false;
      });
    }
  }

  /// Gestisce il risultato del riconoscimento vocale e procede con il caricamento del prossimo esercizio
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
      await _showFeedbackPopup(result, crystalsEarned,
          player.currentLevel);

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

  /// Mostra il riepilogo della sessione
  Future<void> _showSessionSummary() async {
    if (!mounted) return;
    try {
      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final playerManager = Provider.of<PlayerManager>(context, listen: false);
          final int currentLevel = playerManager.currentProfile?.currentLevel ?? 1;
          return CrystalPopup(
            earnedCrystals: _totalCrystals,
            level: currentLevel,
            progress: _sessionAccuracy,
            isSessionSummary: true,
            recognitionResult: RecognitionResult(
              text: '',
              confidence: 1.0,
              similarity: _sessionAccuracy,
              isCorrect: _sessionAccuracy >= 0.75,
              duration: const Duration(seconds: 1),
            ),
          );
        },
      );
      if (!mounted) return;
      if (shouldContinue == true) {
        setState(() {
          _currentExercise = 0;
          _sessionAccuracy = 0.0;
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

  /// Conta le sillabe in una parola italiana
  int _countSyllables(String word) {
    final vowels = RegExp('[aeiouAEIOU]');
    final diphthongs = RegExp('(ai|au|ei|eu|oi|ou|ia|ie|io|iu|ua|ue|ui|uo)');
    int count = vowels.allMatches(word).length;
    count -= diphthongs.allMatches(word).length;
    return count > 0 ? count : 1;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || !_isSessionStarted) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'OpenDSA: Reading',
            style: TextStyle(fontFamily: 'OpenDyslexic'),
          ),
        ),
        body: Center(
          child: _errorMessage != null
              ? Text(
            _errorMessage!,
            style: TextStyle(
              color: Colors.red[700],
              fontFamily: 'OpenDyslexic',
            ),
          )
              : const CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OpenDSA: Reading',
          style: TextStyle(fontFamily: 'OpenDyslexic'),
        ),
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (_isRecording) {
            await _stopRecording();
            return false;
          }
          return true;
        },
        child: Container(
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
                debugPrint('[ReadingExerciseScreen] LayoutBuilder: constraints=$constraints');
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
                              _isRecording ? Colors.red.shade700! : Colors.green.shade500!,
                            ),
                          ),
                          Text(
                            'Esercizio $_currentExercise di $_totalExercises',
                            style: const TextStyle(
                              fontSize: 18,
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
                              child: Text(
                                _currentWord,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontFamily: 'OpenDyslexic',
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          if (_isRecording)
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                  begin: 1.0, end: 1.0 + _volumeLevel * 0.5),
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
                              onPressed: _isRecording ? _stopRecording : _startRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                _isRecording ? Colors.red.shade700 : Colors.green.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 48,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                textStyle: const TextStyle(fontSize: 20),
                              ),
                              child: Text(
                                _isRecording ? 'Stop' : 'Registra',
                                style: const TextStyle(fontFamily: 'OpenDyslexic'),
                              ),
                            )
                          else
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.yellowAccent.shade700),
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
      ),
    );
  }

  @override
  void dispose() {
    _volumeSubscription?.cancel();
    if (_isRecording) {
      _audioService.stopRecording();
    }
    _audioService.dispose();
    _voskService.dispose();
    super.dispose();
  }
}

/// Classe che rappresenta un singolo esercizio
class Exercise {
  final String content;
  final ExerciseType type;
  final Difficulty difficulty;
  final int crystalValue;
  final bool isBonus;
  final Map<String, dynamic>? metadata;

  Exercise({
    required this.content,
    required this.type,
    required this.difficulty,
    required this.crystalValue,
    this.isBonus = false,
    this.metadata,
  });
}
