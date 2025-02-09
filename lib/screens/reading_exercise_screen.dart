// lib/screens/reading_exercise_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../services/vosk_service.dart';
import '../services/audio_service.dart';
import '../services/exercise_manager.dart';
import '../models/recognition_result.dart';
import '../widgets/voice_recognition_feedback.dart';
import '../widgets/crystal_popup.dart';

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

  // Servizi
  late final VoskService _voskService;
  late final AudioService _audioService;
  late final ExerciseManager _exerciseManager;

  @override
  void initState() {
    super.initState();
    _voskService = VoskService.instance;
    _audioService = AudioService();
    _exerciseManager = Provider.of<ExerciseManager>(context, listen: false);
    _initializeServices();
  }

  /// Inizializza i servizi necessari e genera il primo esercizio
  Future<void> _initializeServices() async {
    try {
      await Future.wait([
        _voskService.initialize(),
        _audioService.initialize(),
      ]);

      // Configura listener per il volume
      _audioService.volumeLevel.listen((volume) {
        setState(() => _volumeLevel = volume);
      });

      await _loadNewExercise();
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nell\'inizializzazione: $e';
      });
    }
  }

  /// Carica un nuovo esercizio
  Future<void> _loadNewExercise() async {
    try {
      final exercise = await _exerciseManager.generateExercise();
      setState(() {
        _currentWord = exercise.content;
        _isProcessing = false;
        _currentExercise++;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nel caricamento dell\'esercizio: $e';
      });
    }
  }

  /// Avvia la registrazione audio
  Future<void> _startRecording() async {
    if (_isRecording || _isProcessing) return;

    try {
      await _audioService.startRecording();
      setState(() {
        _isRecording = true;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nell\'avvio della registrazione: $e';
      });
    }
  }

  /// Ferma la registrazione e processa il risultato
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    setState(() => _isProcessing = true);

    try {
      final audioPath = await _audioService.stopRecording();
      setState(() => _isRecording = false);

      if (audioPath.isNotEmpty) {
        final result = await _voskService.startRecognition(_currentWord);
        await _handleRecognitionResult(result);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Errore nella registrazione: $e';
        _isProcessing = false;
      });
    }
  }

  /// Gestisce il risultato del riconoscimento vocale
  Future<void> _handleRecognitionResult(RecognitionResult result) async {
    final player = Provider.of<Player>(context, listen: false);
    final gameService = Provider.of<GameService>(context, listen: false);

    // Calcola i cristalli (5 per sillaba)
    final syllables = _countSyllables(_currentWord);
    final crystalsEarned = syllables * 5;
    _totalCrystals += crystalsEarned;

    // Aggiorna accuracy media
    _sessionAccuracy = ((_sessionAccuracy * (_currentExercise - 1)) + result.similarity) / _currentExercise;

    // Mostra il popup con il feedback
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CrystalPopup(
        earnedCrystals: crystalsEarned,
        level: player.currentLevel,
        progress: result.similarity,
        recognitionResult: result,
      ),
    );

    // Aggiorna i servizi
    await _exerciseManager.processExerciseResult(result);
    await gameService.processExerciseResult(result);

    // Verifica se la sessione è completa
    if (_currentExercise >= _totalExercises) {
      _showSessionSummary();
    } else {
      await _loadNewExercise();
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

  /// Mostra il riepilogo della sessione
  Future<void> _showSessionSummary() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CrystalPopup(
        earnedCrystals: _totalCrystals,
        level: Provider.of<Player>(context, listen: false).currentLevel,
        progress: _sessionAccuracy,
        isSessionSummary: true,
        recognitionResult: RecognitionResult(
          text: '',
          confidence: 1.0,
          similarity: _sessionAccuracy,
          isCorrect: _sessionAccuracy >= 0.85,
          duration: const Duration(seconds: 1),
        ),
      ),
    );

    if (shouldContinue == true) {
      // Resetta per una nuova sessione
      setState(() {
        _currentExercise = 0;
        _sessionAccuracy = 0.0;
        _totalCrystals = 0;
      });
      await _loadNewExercise();
    } else {
      // Torna alla game screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OpenDSA: Reading',
          style: TextStyle(fontFamily: 'OpenDyslexic'),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade100, Colors.blue.shade50],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicatore di progresso
                LinearProgressIndicator(
                  value: _currentExercise / _totalExercises,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isRecording ? Colors.red[700]! : Colors.blue[700]!,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Esercizio $_currentExercise di $_totalExercises',
                  style: const TextStyle(
                    fontSize: 18,
                    fontFamily: 'OpenDyslexic',
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 32),

                // Parola da leggere
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
                const SizedBox(height: 32),

                // Feedback del riconoscimento vocale
                if (_isRecording)
                  VoiceRecognitionFeedback(
                    isRecording: true,
                    volumeLevel: _volumeLevel,
                    targetText: _currentWord,
                  ),

                const SizedBox(height: 32),

                // Pulsante di registrazione
                if (!_isProcessing)
                  ElevatedButton(
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red[700] : Colors.green[700],
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                  ),

                const SizedBox(height: 32),

                // Messaggio di errore
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}