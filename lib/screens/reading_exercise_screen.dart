// reading_exercise_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../services/vosk_service.dart';
import '../services/audio_service.dart';
import '../services/game_notification_manager.dart';
import '../models/recognition_result.dart';
import '../utils/text_similarity.dart';
import 'package:permission_handler/permission_handler.dart';

class ReadingExerciseScreen extends StatefulWidget {
  @override
  _ReadingExerciseScreenState createState() => _ReadingExerciseScreenState();
}

class _ReadingExerciseScreenState extends State<ReadingExerciseScreen>
    with SingleTickerProviderStateMixin {
  late String text;
  bool isRecording = false;
  bool exerciseCompleted = false;
  String recognizedText = '';
  double similarity = 0.0;
  DateTime? exerciseStartTime;

  late VoskService voskService;
  late AudioService audioService;
  late GameNotificationManager notificationManager;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    final gameService = Provider.of<GameService>(context, listen: false);
    text = gameService.getTextForCurrentLevel();

    // Inizializzazione dei servizi
    voskService = VoskService.instance;
    audioService = AudioService();
    notificationManager = GameNotificationManager();

    _setupAnimation();
    _initializeServices();
  }

  // ... [Mantieni il resto dei metodi esistenti fino a _handleCorrectRecognition]

  void _handleCorrectRecognition(RecognitionResult result) async {
    final gameService = Provider.of<GameService>(context, listen: false);

    bool levelCompleted = await gameService.processRecognitionResult(result);

    // Mostra notifica streak se applicabile
    if (gameService.currentStreak >= 2) {
      notificationManager.showStreakNotification(
        context,
        gameService.currentStreak,
        gameService.getCurrentStreakMultiplier(),
      );
    }

    if (levelCompleted) {
      notificationManager.showLevelUp(
        context,
        gameService.player.currentLevel + 1,
      );
    }

    // Mostra feedback positivo
    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    final gameService = Provider.of<GameService>(context, listen: false);
    final currentSubLevel = gameService.getCurrentSubLevel();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ottimo Lavoro!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hai completato l\'esercizio con successo!'),
            SizedBox(height: 8),
            Text(
              'Livello: ${currentSubLevel.name}',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            if (gameService.currentStreak > 0)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      'Streak: ${gameService.currentStreak}',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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

  // ... [Mantieni il resto dei metodi esistenti]

  @override
  void dispose() {
    audioService.dispose();
    _controller.dispose();
    notificationManager.dispose();
    super.dispose();
  }
}