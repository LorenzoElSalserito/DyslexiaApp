// lib/screens/game_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:thesis_project/models/enums.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../services/store_service.dart';
import '../services/challenge_service.dart';
import '../models/challenge.dart';
import '../widgets/progression_map.dart';
import 'store_screen.dart';
import 'options_screen.dart';
import 'challenges_screen.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<Player, GameService>(
      builder: (context, player, gameService, _) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.lightBlue.shade900, Colors.lightBlue.shade700],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildTopSection(context, player),
                    const SizedBox(height: 50),
                    _buildProgressionSection(context, player, gameService),
                    const SizedBox(height: 50),
                    _buildActiveChallenges(context),
                    const SizedBox(height: 50),
                    _buildButtonsSection(context, player),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopSection(BuildContext context, Player player) {
    final store = Provider.of<StoreService>(context);
    final currentTitle = store.currentTitle;

    // Debug: stampa il valore del player.name nel terminale
    print('DEBUG: player.name = ${player.name}');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${currentTitle ?? 'Novizio'} ${player.name}',
                  style: const TextStyle(
                    fontFamily: 'OpenDyslexic',
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.diamond, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      player.totalCrystals.toString(),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${player.currentConsecutiveDays} giorni',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.track_changes, color: Colors.green, size: 20),
                  const SizedBox(width: 4),
                  Consumer<GameService>(
                    builder: (context, gameService, _) => Text(
                      '${(gameService.getAverageAccuracy() * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionSection(BuildContext context, Player player, GameService gameService) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: const ProgressionMap(),
    );
  }

  Widget _buildActiveChallenges(BuildContext context) {
    return Consumer<ChallengeService>(
      builder: (context, challengeService, _) {
        final activeChallenges = challengeService.activeChallenges
            .where((c) => !c.isCompleted)
            .take(2)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sfide Attive',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChallengesScreen()),
                  ),
                  child: const Text(
                    'Vedi tutte',
                    style: TextStyle(
                      color: Colors.amber,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ),
              ],
            ),
            if (activeChallenges.isEmpty)
              const Text(
                'Nessuna sfida attiva',
                style: TextStyle(
                  color: Colors.white70,
                  fontFamily: 'OpenDyslexic',
                ),
              )
            else
              ...activeChallenges.map((challenge) => _buildChallengeCard(challenge)),
          ],
        );
      },
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            challenge.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: challenge.progressPercentage,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
              challenge.type == ChallengeType.daily ? Colors.amber : Colors.purple,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(challenge.progressPercentage * 100).toInt()}% completato',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonsSection(BuildContext context, Player player) {
    return Column(
      children: [
        _buildButton(
          ' Esercizio di Lettura ',
          Colors.green.shade700,
              () => Navigator.pushNamed(context, '/reading_exercise'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildButton(
                'Sfide',
                const Color(0xFF4A148C), // Viola scuro ad alto contrasto
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChallengesScreen()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildButton(
                'Negozio',
                Colors.amber.shade900,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StoreScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            /*Expanded(
              child: _buildButton(
                'Opzioni',
                Colors.cyan.shade900,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OptionsScreen()),
                ),
              ),
            ),*/
            const SizedBox(width: 8),
            Expanded(
              child: _buildButton(
                'Menu',
                Colors.blueGrey.shade900,
                    () => Navigator.pushReplacementNamed(context, '/'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'OpenDyslexic',
        ),
      ),
    );
  }
}
