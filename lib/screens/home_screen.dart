import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../widgets/crystal_popup.dart';
import '../widgets/progression_map.dart';
import 'main_menu_screen.dart';
import 'level_summary_screen.dart';

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
      width: 300, // Larghezza fissa per il riquadro del profilo
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
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            'Matricola: ${player.matricola}',
            style: TextStyle(color: Colors.white),
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
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButtonsColumn(BuildContext context, Player player, GameService gameService) {
    return Container(
      width: 300, // Larghezza fissa per la colonna dei bottoni
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton('Completa Step', Colors.green, () async {
            // ... (codice per completare lo step)
          }),
          SizedBox(height: 10),
          _buildButton('Compra Livello (${player.levelCrystalCost} Cristalli)',
              Colors.amber,
              gameService.canBuyLevel() ? () {
                // ... (codice per comprare il livello)
              } : null),
          if (player.isAdmin) ...[
            SizedBox(height: 10),
            _buildButton('Prossimo Step', Colors.orange, () async {
              await gameService.completeStep();
            }),
            SizedBox(height: 10),
            _buildButton('Prossimo Livello', Colors.red, () {
              player.levelUp();
            }),
          ],
          SizedBox(height: 10),
          _buildButton('Torna al Menu', Colors.white, () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainMenuScreen()));
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
          padding: EdgeInsets.symmetric(vertical: 15),
        ),
        onPressed: onPressed,
      ),
    );
  }
}