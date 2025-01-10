import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import 'game_screen.dart';


class LevelSummaryScreen extends StatelessWidget {
  final int completedLevel;
  final int earnedCrystals;
  final bool isPurchased;

  LevelSummaryScreen({
    required this.completedLevel,
    required this.earnedCrystals,
    this.isPurchased = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<Player>(context);
    final gameService = Provider.of<GameService>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.lightBlue.shade100, Colors.lightGreen.shade200],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isPurchased
                      ? 'Livello ${completedLevel + 1} Acquistato!'
                      : 'Livello $completedLevel Completato!',
                  style: TextStyle(
                    fontFamily: 'OpenDyslexic',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 20),
                if (!isPurchased)
                  Text(
                    'Cristalli guadagnati: $earnedCrystals',
                    style: TextStyle(
                      fontFamily: 'OpenDyslexic',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                SizedBox(height: 20),
                Text(
                  'Totale cristalli: ${player.totalCrystals}',
                  style: TextStyle(
                    fontFamily: 'OpenDyslexic',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 40),
                ElevatedButton(
                  child: Text(
                    'Continua',
                    style: TextStyle(
                      fontFamily: 'OpenDyslexic',
                      fontSize: 18,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(200, 50),
                  ),
                  onPressed: () {
                    if (completedLevel < 4) {
                      if (!isPurchased) {
                        player.levelUp();
                      }
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GameScreen()));
                    } else {
                      // Game completed, offer New Game+
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Congratulazioni!'),
                          content: Text('Hai completato il gioco! Vuoi iniziare un New Game+?'),
                          actions: [
                            TextButton(
                              child: Text('Sì'),
                              onPressed: () {
                                player.startNewGamePlus();
                                Navigator.of(context).pop();
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GameScreen()));
                              },
                            ),
                            TextButton(
                              child: Text('No'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GameScreen()));
                              },
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}