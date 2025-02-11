// lib/screens/game_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';  // Import aggiunto per la classe Player
import '../services/game_service.dart';
import '../services/store_service.dart';
import '../services/challenge_service.dart';
import '../services/player_manager.dart';
import '../models/challenge.dart';
import '../widgets/progression_map.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  bool _hasCheckedDailyBonus = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    debugPrint('[GameScreen] _initializeScreen: Avvio inizializzazione');
    if (!mounted) return;

    try {
      final playerManager = Provider.of<PlayerManager>(context, listen: false);
      final gameService = Provider.of<GameService>(context, listen: false);

      if (!gameService.isInitialized) {
        debugPrint('[GameScreen] Inizializzo GameService...');
        await gameService.initialize();
      }

      if (!_hasCheckedDailyBonus) {
        await _checkDailyBonus();
      }

      setState(() {
        _isInitialized = true;
      });
      debugPrint('[GameScreen] Inizializzazione completata');
    } catch (e) {
      debugPrint('[GameScreen] Errore nell\'inizializzazione: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Si è verificato un errore: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _checkDailyBonus() async {
    debugPrint('[GameScreen] _checkDailyBonus: Verifica bonus giornaliero');
    if (_hasCheckedDailyBonus) return;

    try {
      final gameService = Provider.of<GameService>(context, listen: false);
      if (gameService.isDailyBonusAvailable) {
        debugPrint('[GameScreen] Bonus giornaliero disponibile');
        await gameService.resetDailyBonus();
        if (mounted) {
          await gameService.showDailyLoginBonus(context);
        }
      }

      setState(() {
        _hasCheckedDailyBonus = true;
      });
      debugPrint('[GameScreen] Bonus giornaliero verificato');
    } catch (e) {
      debugPrint('[GameScreen] Errore nel controllo bonus giornaliero: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayerManager, GameService>(
      builder: (context, playerManager, gameService, _) {
        final player = playerManager.currentProfile;
        if (!_isInitialized || player == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              debugPrint('[GameScreen] LayoutBuilder: constraints=$constraints');
              return Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade900,
                      Colors.blue.shade800,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTopSection(player),
                      ),
                      const Expanded(
                        flex: 3,
                        child: ProgressionMap(),
                      ),
                      Expanded(
                        flex: 4,
                        child: _buildActiveChallenges(),
                      ),
                      Expanded(
                        flex: 3,
                        child: _buildButtonsSection(player),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopSection(Player player) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double fontSize = constraints.maxWidth * 0.05;
        if (fontSize > 24) fontSize = 24;
        if (fontSize < 16) fontSize = 16;
        return Container(
          padding: EdgeInsets.symmetric(
            vertical: constraints.maxHeight * 0.1,
            horizontal: constraints.maxWidth * 0.05,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<StoreService>(
                      builder: (context, store, _) => Text(
                        '${store.currentTitle ?? 'Novizio'} ${player.name}',
                        style: TextStyle(
                          fontFamily: 'OpenDyslexic',
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.diamond, color: Colors.orange, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          player.totalCrystals.toString(),
                          style: const TextStyle(
                            color: Colors.orange,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${player.currentConsecutiveDays} giorni',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                    ],
                  ),
                  Consumer<GameService>(
                    builder: (context, gameService, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.track_changes, color: Colors.lightGreenAccent, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '${(gameService.getAverageAccuracy() * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.lightGreenAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveChallenges() {
    return Consumer<ChallengeService>(
      builder: (context, challengeService, _) {
        final activeChallenges = challengeService.activeChallenges
            .where((c) => !c.isCompleted)
            .take(2)
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
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
                    onPressed: () => Navigator.pushNamed(context, '/challenges'),
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
                Expanded(
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeChallenges.length,
                    itemBuilder: (context, index) =>
                        _buildChallengeCard(activeChallenges[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChallengeCard(Challenge challenge) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: challenge.progressPercentage,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(challenge.color),
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
      ),
    );
  }

  Widget _buildButtonsSection(Player player) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Expanded(
                child: _buildButton(
                  'Esercizio di Lettura',
                  Colors.green.shade700,
                      () => Navigator.pushNamed(context, '/reading_exercise'),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildButton(
                        'Sfide',
                        const Color(0xFF4A148C),
                            () => Navigator.pushNamed(context, '/challenges'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildButton(
                        'Negozio',
                        Colors.amber.shade900,
                            () => Navigator.pushNamed(context, '/store'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    if (player.isAdmin) ...[
                      Expanded(
                        child: _buildButton(
                          'Level Up',
                          Colors.purple.shade900,
                              () {
                            player.levelUp();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _buildButton(
                        'Menu',
                        Colors.blueGrey.shade900,
                            () => Navigator.pushReplacementNamed(context, '/'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        shadowColor: color.withOpacity(0.5),
        minimumSize: const Size(100, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
