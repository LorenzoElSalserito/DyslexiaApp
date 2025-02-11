// lib/widgets/progression_map.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../services/player_manager.dart';
import '../models/player.dart';
import '../models/level.dart';
import '../models/enums.dart';

/// Widget che mostra la mappa di progressione del giocatore, inclusi il livello corrente,
/// i sottolivelli e gli indicatori di progresso. La disposizione è responsive e ancorata.
class ProgressionMap extends StatelessWidget {
  const ProgressionMap({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final playerManager = Provider.of<PlayerManager>(context);
    final Player? player = playerManager.currentProfile;
    final gameService = Provider.of<GameService>(context);
    final currentSubLevel = gameService.getCurrentSubLevel();

    if (player == null) {
      return const Center(
        child: Text(
          'Nessun profilo selezionato',
          style: TextStyle(fontFamily: 'OpenDyslexic', fontSize: 18),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                flex: 2,
                child: _buildLevelHeader(player),
              ),
              const SizedBox(height: 4),
              Flexible(
                flex: 2,
                child: _buildProgressBar(gameService),
              ),
              const SizedBox(height: 4),
              Flexible(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: _buildLevelDetails(gameService, currentSubLevel),
                ),
              ),
              if (gameService.hasActiveStreak) ...[
                const SizedBox(height: 4),
                Flexible(
                  flex: 1,
                  child: _buildStreakIndicator(gameService.streak),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLevelHeader(Player player) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink.shade500, Colors.pink.shade900],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getLevelIcon(player.currentLevel),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Livello ${player.currentLevel}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
              ],
            ),
            if (player.newGamePlusCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'NG+${player.newGamePlusCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(GameService gameService) {
    double progress = gameService.getLevelUpProgress();
    final averageAccuracy = gameService.getAverageAccuracy();
    final isGoodAccuracy = averageAccuracy >= GameService.requiredAccuracy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 240,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  tween: Tween<double>(begin: 0, end: progress),
                  builder: (context, value, _) {
                    return FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isGoodAccuracy
                                ? [Colors.green.shade400, Colors.green.shade600]
                                : [Colors.orange.shade400, Colors.orange.shade600],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${(averageAccuracy * 100).toStringAsFixed(1)}% Accuratezza',
            style: TextStyle(
              color: isGoodAccuracy ? Colors.green.shade400 : Colors.orange,
              fontSize: 12,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelDetails(GameService gameService, SubLevel currentSubLevel) {
    final targetDays = GameService.requiredDaysForLevelUp;
    final daysWithGoodAccuracy = (gameService.getLevelUpProgress() * targetDays).floor();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactDetailRow('Fase:', currentSubLevel.name, Icons.flag),
          const SizedBox(height: 2),
          _buildCompactDetailRow(
            'Obiettivo:',
            '${(GameService.requiredAccuracy * 100).toInt()}%',
            Icons.track_changes,
          ),
          const SizedBox(height: 2),
          _buildCompactDetailRow(
            'Giorni:',
            '$daysWithGoodAccuracy/$targetDays',
            Icons.calendar_today,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDetailRow(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'OpenDyslexic',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakIndicator(int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
          const SizedBox(width: 4),
          Text(
            'Streak: $streak',
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLevelIcon(int level) {
    return switch (level) {
      1 => Icons.text_fields,    // Livello parole
      2 => Icons.short_text,     // Livello frasi
      3 => Icons.article,        // Livello paragrafi
      4 => Icons.menu_book,      // Livello pagine
      _ => Icons.help,
    };
  }
}
