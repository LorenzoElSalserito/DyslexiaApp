// lib/screens/level_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import 'game_screen.dart';

class LevelSummaryScreen extends StatelessWidget {
  final int completedLevel;
  final int earnedCrystals;
  final bool isPurchased;
  final double accuracy;

  LevelSummaryScreen({
    required this.completedLevel,
    required this.earnedCrystals,
    this.isPurchased = false,
    this.accuracy = 0.0,
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
                _buildHeader(isPurchased, completedLevel),
                SizedBox(height: 20),
                if (!isPurchased) ...[
                  _buildAccuracyIndicator(gameService),
                  SizedBox(height: 20),
                  _buildProgressInfo(gameService),
                  SizedBox(height: 20),
                  _buildCrystalsInfo(earnedCrystals, player),
                ],
                SizedBox(height: 40),
                _buildContinueButton(context, player, gameService),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isPurchased, int level) {
    return Column(
      children: [
        Text(
          isPurchased
              ? 'Livello ${level + 1} Acquistato!'
              : 'Livello $level Completato!',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (!isPurchased)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Complimenti per il tuo progresso!',
              style: TextStyle(
                fontFamily: 'OpenDyslexic',
                fontSize: 18,
                color: Colors.black54,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAccuracyIndicator(GameService gameService) {
    final averageAccuracy = gameService.getAverageAccuracy();
    final isGoodAccuracy = averageAccuracy >= GameService.requiredAccuracy;

    return Column(
      children: [
        Text(
          'Accuratezza Media',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 10),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${(averageAccuracy * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontFamily: 'OpenDyslexic',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isGoodAccuracy ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ),
        SizedBox(height: 10),
        Text(
          isGoodAccuracy
              ? 'Ottimo lavoro!'
              : 'Continua ad esercitarti per migliorare',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            fontSize: 16,
            color: isGoodAccuracy ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressInfo(GameService gameService) {
    final daysProgress = gameService.getLevelUpProgress();
    final daysNeeded = (GameService.requiredDaysForLevelUp * (1 - daysProgress)).ceil();

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Progresso verso il prossimo livello',
            style: TextStyle(
              fontFamily: 'OpenDyslexic',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: daysProgress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.blue,
            ),
            minHeight: 8,
          ),
          SizedBox(height: 8),
          Text(
            daysNeeded > 0
                ? 'Mantieni un\'accuratezza del 75% per altri $daysNeeded giorni'
                : 'Pronto per il prossimo livello!',
            style: TextStyle(
              fontFamily: 'OpenDyslexic',
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCrystalsInfo(int earned, Player player) {
    return Column(
      children: [
        if (earned > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.diamond, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                '+$earned',
                style: TextStyle(
                  fontFamily: 'OpenDyslexic',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
        ],
        Text(
          'Totale cristalli: ${player.totalCrystals}',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton(BuildContext context, Player player, GameService gameService) {
    return ElevatedButton(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Text(
          'Continua',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            fontSize: 20,
          ),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      onPressed: () {
        if (completedLevel < 4) {
          if (!isPurchased && gameService.canAdvanceLevel()) {
            player.levelUp();
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => GameScreen()),
          );
        } else {
          // Game completed, offer New Game+
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Congratulazioni!',
                style: TextStyle(fontFamily: 'OpenDyslexic'),
              ),
              content: Text(
                'Hai completato il gioco! Vuoi iniziare un New Game+?',
                style: TextStyle(fontFamily: 'OpenDyslexic'),
              ),
              actions: [
                TextButton(
                  child: Text(
                    'Sì',
                    style: TextStyle(fontFamily: 'OpenDyslexic'),
                  ),
                  onPressed: () {
                    player.startNewGamePlus();
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => GameScreen()),
                    );
                  },
                ),
                TextButton(
                  child: Text(
                    'No',
                    style: TextStyle(fontFamily: 'OpenDyslexic'),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => GameScreen()),
                    );
                  },
                ),
              ],
            ),
          );
        }
      },
    );
  }
}