import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../widgets/crystal_popup.dart';
import '../widgets/progression_map.dart';
import 'level_summary_screen.dart';

class GameScreen extends StatelessWidget {
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
            colors: [Colors.lightBlue.shade100, Colors.lightBlue.shade300],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Center(child: _buildProfileCard(player)),
                        ProgressionMap(),
                        Center(child: _buildButtonsColumn(context, player, gameService)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(Player player) {
    return Container(
      width: 300,
      margin: EdgeInsets.symmetric(vertical: 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '${player.name} ${player.surname}',
            style: TextStyle(
              fontFamily: 'OpenDyslexic',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Matricola: ${player.matricola}',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontFamily: 'OpenDyslexic',
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.diamond, color: Colors.white),
              SizedBox(width: 5),
              Text(
                '${player.totalCrystals}',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButtonsColumn(BuildContext context, Player player, GameService gameService) {
    return Container(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton('Esercizio di Lettura', Colors.green, () {
            Navigator.pushNamed(context, '/reading_exercise');
          }),
          SizedBox(height: 10),
          _buildButton('Completa Step', Colors.blue, () async {
            int initialCrystals = player.totalCrystals;
            bool levelCompleted = await gameService.completeStep();
            int earnedCrystals = player.totalCrystals - initialCrystals;

            showDialog(
              context: context,
              builder: (context) => CrystalPopup(
                earnedCrystals: earnedCrystals,
                level: player.currentLevel,
                progress: gameService.levelProgress,
              ),
            );

            if (levelCompleted) {
              int completedLevel = player.currentLevel;
              player.levelUp(); // Avanziamo al livello successivo
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LevelSummaryScreen(
                    completedLevel: completedLevel,
                    earnedCrystals: earnedCrystals,
                  ),
                ),
              );
            }
          }),
          SizedBox(height: 10),
          _buildButton('Compra Livello (${player.levelCrystalCost} Cristalli)',
              Colors.amber,
              gameService.canBuyLevel() ? () async {
                bool success = await gameService.buyLevel();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Livello ${player.currentLevel} acquistato con successo!')),
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LevelSummaryScreen(
                        completedLevel: player.currentLevel - 1,
                        earnedCrystals: 0,
                        isPurchased: true,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Impossibile acquistare il livello. Cristalli insufficienti.')),
                  );
                }
              } : null),
          if (player.isAdmin) ...[
            SizedBox(height: 10),
            _buildButton('Prossimo Step', Colors.orange, () async {
              await gameService.completeStep();
            }),
            SizedBox(height: 10),
            _buildButton('Prossimo Livello', Colors.red, () {
              int currentLevel = player.currentLevel;
              player.levelUp();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LevelSummaryScreen(
                    completedLevel: currentLevel,
                    earnedCrystals: 0,
                    isPurchased: true,
                  ),
                ),
              );
            }),
          ],
          SizedBox(height: 10),
          _buildButton('Torna al Menu', Colors.white, () {
            Navigator.pushReplacementNamed(context, '/');
          }, textColor: Colors.black),
        ],
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback? onPressed, {Color textColor = Colors.white}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        child: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
      ),
    );
  }
}