import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../widgets/crystal_popup.dart';
import '../widgets/progression_map.dart';
import 'main_menu_screen.dart';

class HomeScreen extends StatelessWidget {
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
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '${player.name} ${player.surname}',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Matricola: ${player.matricola}',
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.diamond, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          '${player.totalCrystals}',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ProgressionMap(currentLevel: player.currentLevel, currentStep: player.currentStep),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('Completa Step'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(200, 50),
                ),
                onPressed: () async {
                  bool levelCompleted = await gameService.completeStep();
                  showDialog(
                    context: context,
                    builder: (context) => CrystalPopup(
                      crystals: player.totalCrystals,
                      level: player.currentLevel,
                      progress: gameService.levelProgress,
                    ),
                  );
                  if (levelCompleted) {
                    if (player.currentLevel == 4 && player.currentStep >= GameService.levelTargets[4]!) {
                      // Gioco completato, offri New Game+
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
                              },
                            ),
                            TextButton(
                              child: Text('No'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      );
                    } else {
                      player.levelUp();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Livello completato!')),
                      );
                    }
                  }
                },
              ),
              if (player.isAdmin) ...[
                SizedBox(height: 20),
                ElevatedButton(
                  child: Text('Prossimo Livello'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: Size(200, 50),
                  ),
                  onPressed: () {
                    player.levelUp();
                  },
                ),
              ],
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('Torna al Menu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: Size(200, 50),
                ),
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainMenuScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}