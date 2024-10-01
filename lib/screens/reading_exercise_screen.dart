import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/player.dart';
import '../services/game_service.dart';

class ReadingExerciseScreen extends StatefulWidget {
  @override
  _ReadingExerciseScreenState createState() => _ReadingExerciseScreenState();
}

class _ReadingExerciseScreenState extends State<ReadingExerciseScreen> with SingleTickerProviderStateMixin {
  late String text;
  int currentWordIndex = 0;
  bool exerciseCompleted = false;
  FlutterTts flutterTts = FlutterTts();
  bool isSpeaking = false;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    final gameService = Provider.of<GameService>(context, listen: false);
    text = gameService.getTextForCurrentLevel();
    initTts();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  void initTts() {
    flutterTts.setLanguage("it-IT");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setVolume(1.0);
    flutterTts.setPitch(1.0);
  }

  List<String> get words => text.split(' ');

  void highlightNextWord() {
    if (currentWordIndex < words.length - 1) {
      setState(() {
        currentWordIndex++;
      });
      _controller.forward(from: 0.0);
    } else {
      setState(() {
        exerciseCompleted = true;
      });
      _completeExercise();
    }
  }

  Future<void> speakText() async {
    if (isSpeaking) {
      await flutterTts.stop();
    }
    setState(() {
      isSpeaking = true;
    });

    final player = Provider.of<Player>(context, listen: false);
    if (player.isAdmin) {
      // Simula il completamento dell'esercizio per l'admin
      await Future.delayed(Duration(seconds: 2));
      setState(() {
        isSpeaking = false;
        exerciseCompleted = true;
      });
      _completeExercise();
    } else {
      if (player.currentLevel == 1) {
        await flutterTts.speak(words[currentWordIndex]);
      } else {
        await flutterTts.speak(text);
      }
      setState(() {
        isSpeaking = false;
      });
    }
  }

  void _completeExercise() async {
    final player = Provider.of<Player>(context, listen: false);
    final gameService = Provider.of<GameService>(context, listen: false);

    bool levelCompleted = await gameService.completeStep();
    if (levelCompleted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Congratulazioni!'),
            content: Text('Hai completato il livello ${player.currentLevel}!'),
            actions: <Widget>[
              TextButton(
                child: Text('Continua'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed('/home');
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<Player>(context);
    return Scaffold(
      backgroundColor: Colors.grey[300], // Sfondo argento
      appBar: AppBar(
        title: Text('Esercizio di Lettura'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: SlideTransition(
                  position: _offsetAnimation,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    color: Colors.yellow,
                    child: Text(
                      player.currentLevel == 1 ? words[currentWordIndex] : text,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: Text(exerciseCompleted ? 'Completato' : 'Parola Successiva'),
                  onPressed: exerciseCompleted ? null : highlightNextWord,
                ),
                ElevatedButton(
                  child: Text(player.isAdmin ? 'Simula Lettura' : 'Leggi Testo'),
                  onPressed: isSpeaking ? null : speakText,
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    flutterTts.stop();
    _controller.dispose();
    super.dispose();
  }
}