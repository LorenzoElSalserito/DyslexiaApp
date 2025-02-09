// lib/screens/game_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../services/game_service.dart';
import '../services/store_service.dart';
import '../services/challenge_service.dart';
import '../models/challenge.dart';
import '../widgets/progression_map.dart';
import '../services/game_notification_manager.dart';
import 'store_screen.dart';
import 'challenges_screen.dart';
import 'reading_exercise_screen.dart';

/// Schermata principale del gioco che mostra il progresso del giocatore,
/// le sfide attive e le varie opzioni di gioco disponibili.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  // Servizi e stato
  late final GameNotificationManager _notificationManager;
  bool _hasCheckedDailyBonus = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _notificationManager = GameNotificationManager();
    // Registriamo l'observer per gestire i cambi di stato dell'app
    WidgetsBinding.instance.addObserver(this);

    // Inizializzazione posticipata dopo il build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Controlliamo il bonus quando l'app torna in foreground
    if (state == AppLifecycleState.resumed && _isInitialized) {
      _checkDailyBonus();
    }
  }

  /// Inizializza la schermata e controlla il bonus giornaliero
  Future<void> _initializeScreen() async {
    if (!mounted) return;

    try {
      // Otteniamo i servizi necessari
      final gameService = Provider.of<GameService>(context, listen: false);

      // Aspettiamo che il GameService sia inizializzato
      if (!gameService.isInitialized) {
        await gameService.initialize();
      }

      // Controlliamo il bonus giornaliero
      await _checkDailyBonus();

      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Errore nell\'inizializzazione della schermata: $e');
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

  /// Controlla e mostra il bonus giornaliero se necessario
  Future<void> _checkDailyBonus() async {
    if (_hasCheckedDailyBonus) return;

    try {
      final player = Provider.of<Player>(context, listen: false);
      final now = DateTime.now();
      final lastPlayDate = player.lastPlayDate;

      // Verifica se è un nuovo giorno
      if (lastPlayDate == null ||
          lastPlayDate.year != now.year ||
          lastPlayDate.month != now.month ||
          lastPlayDate.day != now.day) {

        // Calcola il bonus basato sui giorni consecutivi
        bool isConsecutiveDay = lastPlayDate != null &&
            _isConsecutiveDay(lastPlayDate, now);

        int consecutiveDays = player.currentConsecutiveDays;
        if (isConsecutiveDay) {
          consecutiveDays++;
          if (consecutiveDays > player.maxConsecutiveDays) {
            player.maxConsecutiveDays = consecutiveDays;
          }
        } else {
          consecutiveDays = 1;
        }

        // Aggiorna il contatore dei giorni consecutivi
        player.currentConsecutiveDays = consecutiveDays;

        // Calcola e assegna il bonus
        int bonus = _calculateDailyBonus(consecutiveDays);
        player.addCrystals(bonus);

        // Mostra la notifica del bonus
        if (mounted) {
          await _notificationManager.showDailyLoginBonus(
            context,
            consecutiveDays,
          );
        }

        // Aggiorna la data dell'ultimo accesso
        player.lastPlayDate = now;
        await player.saveProgress();
      }

      setState(() => _hasCheckedDailyBonus = true);
    } catch (e) {
      debugPrint('Errore nel controllo del bonus giornaliero: $e');
    }
  }

  /// Verifica se due date sono consecutive
  bool _isConsecutiveDay(DateTime previous, DateTime current) {
    final yesterday = current.subtract(const Duration(days: 1));
    return previous.year == yesterday.year &&
        previous.month == yesterday.month &&
        previous.day == yesterday.day;
  }

  /// Calcola il bonus giornaliero basato sui giorni consecutivi
  int _calculateDailyBonus(int consecutiveDays) {
    // Bonus base di 10 cristalli più 0.5 per ogni giorno consecutivo
    return (10 + (consecutiveDays - 1) * 0.5).round();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<Player, GameService>(
      builder: (context, player, gameService, _) {
        if (!_isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

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
                    _buildTopSection(player),
                    const SizedBox(height: 50),
                    SizedBox(
                      height: 180,
                      child: ProgressionMap(),
                    ),
                    const SizedBox(height: 50),
                    _buildActiveChallenges(),
                    const SizedBox(height: 50),
                    _buildButtonsSection(player),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopSection(Player player) {
    final store = Provider.of<StoreService>(context);
    final currentTitle = store.currentTitle;

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

  Widget _buildActiveChallenges() {
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
    );
  }

  Widget _buildButtonsSection(Player player) {
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
        const SizedBox(height: 8),
        Row(
          children: [
            if (player.isAdmin) ...[
              Expanded(
                child: _buildButton(
                  'Level Up',
                  Colors.purple.shade900,
                      () {
                    player.levelUp();
                    _notificationManager.showLevelUp(context, player.currentLevel);
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
        shadowColor: color.withOpacity(0.5),
        // Miglioriamo l'accessibilità con il contrasto
        minimumSize: const Size(100, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationManager.dispose();
    super.dispose();
  }
}