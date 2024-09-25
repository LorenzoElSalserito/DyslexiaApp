import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import 'home_screen.dart';

class LevelSummaryScreen extends StatelessWidget {
  final int completedLevel;
  final int earnedCrystals;

  LevelSummaryScreen({required this.completedLevel, required this.earnedCrystals});

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
            colors: [Colors.purple, Colors.blue],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Livello $completedLevel Completato!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 20),
                Text(
                  'Cristalli guadagnati: $earnedCrystals',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                SizedBox(height: 20),
                Text(
                  'Totale cristalli: ${player.totalCrystals}',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                SizedBox(height: 40),
                ElevatedButton(
                  child: Text('Continua'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(200, 50),
                  ),
                  onPressed: () {
                    if (completedLevel < 4) {
                      player.levelUp();
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
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
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
                              },
                            ),
                            TextButton(
                              child: Text('No'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
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