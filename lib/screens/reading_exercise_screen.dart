import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/vosk_service.dart';
import '../services/audio_service.dart';
import '../services/game_notification_manager.dart';
import '../models/recognition_result.dart';
import '../services/recognition_manager.dart';
import '../services/exercise_manager.dart';
import '../widgets/voice_recognition_feedback.dart';

class ReadingExerciseScreen extends StatefulWidget {
  @override
  _ReadingExerciseScreenState createState() => _ReadingExerciseScreenState();
}

class _ReadingExerciseScreenState extends State<ReadingExerciseScreen>
    with SingleTickerProviderStateMixin {
  String text = "";
  bool isRecording = false;
  bool exerciseCompleted = false;
  String recognizedText = '';
  double similarity = 0.0;
  DateTime? exerciseStartTime;
  bool isLoading = true;
  String? errorMessage;

  late final VoskService voskService;
  late final AudioService audioService;
  late final GameNotificationManager notificationManager;
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    voskService = VoskService.instance;
    audioService = AudioService();
    notificationManager = GameNotificationManager();

    _setupAnimation();
    _initializeAll();
  }

  void _setupAnimation() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _initializeAll() async {
    try {
      // Su Linux, saltiamo il controllo dei permessi
      if (!Platform.isLinux) {
        // Controllo permessi per altre piattaforme se necessario
      }

      await _initializeServices();
      await _generateNewExercise();

      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = null;
        });
      }
    } catch (e) {
      print('Errore nell\'inizializzazione: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Errore nell\'inizializzazione: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeServices() async {
    try {
      await voskService.initialize();
      await audioService.initialize();
    } catch (e) {
      throw Exception('Errore nell\'inizializzazione dei servizi: $e');
    }
  }

  Future<void> _generateNewExercise() async {
    try {
      final exerciseManager = Provider.of<ExerciseManager>(context, listen: false);
      final exercise = await exerciseManager.generateExercise();
      if (mounted) {
        setState(() {
          text = exercise.content;
        });
      }
    } catch (e) {
      throw Exception('Errore nella generazione dell\'esercizio: $e');
    }
  }

  Future<void> _startRecording() async {
    if (isRecording) return;

    try {
      exerciseStartTime = DateTime.now();
      await audioService.startRecording();
      setState(() {
        isRecording = true;
      });
    } catch (e) {
      print('Errore nell\'avvio della registrazione: $e');
      setState(() {
        errorMessage = 'Errore nell\'avvio della registrazione: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!isRecording) return;

    try {
      final audioPath = await audioService.stopRecording();
      final duration = DateTime.now().difference(exerciseStartTime!);

      setState(() {
        isRecording = false;
      });

      if (audioPath.isNotEmpty) {
        final result = await voskService.startRecognition(text);
        _handleRecognitionResult(result);
      }
    } catch (e) {
      print('Errore nello stop della registrazione: $e');
      setState(() {
        errorMessage = 'Errore nello stop della registrazione: $e';
      });
    }
  }

  void _handleRecognitionResult(RecognitionResult result) {
    setState(() {
      recognizedText = result.text;
      similarity = result.similarity;
      exerciseCompleted = true;
    });

    if (result.isCorrect) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ottimo Lavoro!'),
        content: Text('Hai completato l\'esercizio con successo!'),
        actions: [
          TextButton(
            child: Text('Continua'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Esercizio di Lettura'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeAll,
                child: Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          if (isRecording)
            VoiceRecognitionFeedback(
              isRecording: isRecording,
              volumeLevel: 0.5,
              targetText: text,
            ),
          if (exerciseCompleted)
            VoiceRecognitionFeedback(
              isRecording: false,
              result: RecognitionResult(
                text: recognizedText,
                confidence: 1.0,
                similarity: similarity,
                isCorrect: similarity >= 0.85,
              ),
              targetText: text,
            ),
          Spacer(),
          ElevatedButton(
            onPressed: isRecording ? _stopRecording : _startRecording,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isRecording ? Colors.red : Colors.blue,
            ),
            child: Text(
              isRecording ? 'Stop Registrazione' : 'Inizia Registrazione',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    audioService.dispose();
    super.dispose();
  }
}