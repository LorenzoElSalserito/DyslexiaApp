import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/player.dart';
import '../models/level.dart';
import '../models/enums.dart';
import '../config/app_config.dart';

class ProgressionMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final player = Provider.of<Player>(context);
    final gameService = Provider.of<GameService>(context);
    final currentSubLevel = gameService.getCurrentSubLevel();

    return Column(
      children: [
        _buildLevelHeader(player, gameService),
        SizedBox(height: 10),
        _buildProgressBar(gameService),
        SizedBox(height: 16),
        _buildLevelDetails(player, gameService, currentSubLevel),
        SizedBox(height: 10),
        if (gameService.currentStreak > 0)
          _buildStreakIndicator(gameService.currentStreak),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelHeader(Player player, GameService gameService) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getLevelIcon(player.currentLevel),
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                'Livello ${player.currentLevel}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (player.newGamePlusCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'NG+${player.newGamePlusCount}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(GameService gameService) {
    return Column(
      children: [
        Container(
          width: 300,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  tween: Tween<double>(
                    begin: 0,
                    end: gameService.levelProgress,
                  ),
                  builder: (context, value, child) {
                    return FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade300,
                              Colors.green.shade500,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Center(
                child: Text(
                  'Step ${gameService.player.currentStep} / ${gameService.getCurrentLevelTarget()}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          _getDifficultyText(gameService.currentDifficulty),
          style: TextStyle(
            color: _getDifficultyColor(gameService.currentDifficulty),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelDetails(Player player, GameService gameService, SubLevel currentSubLevel) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            'Fase Attuale',
            currentSubLevel.name,
            Icons.emoji_flags,
          ),
          SizedBox(height: 8),
          _buildDetailRow(
            'Obiettivo',
            '${gameService.getCurrentLevelTarget()} completati',
            Icons.stars,
          ),
          SizedBox(height: 8),
          _buildDetailRow(
            'Cristalli',
            '${player.totalCrystals}',
            Icons.diamond,
          ),
          if (gameService.canBuyLevel())
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Puoi acquistare il livello successivo!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStreakIndicator(int streak) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: Colors.orange),
          SizedBox(width: 8),
          Text(
            'Streak: $streak',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getLevelIcon(int level) {
    switch (level) {
      case 1:
        return Icons.text_fields;  // Parole
      case 2:
        return Icons.short_text;   // Frasi
      case 3:
        return Icons.article;      // Paragrafi
      case 4:
        return Icons.menu_book;    // Pagine
      default:
        return Icons.help;
    }
  }

  String _getDifficultyText(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return '⭐ Difficoltà: Facile';
      case Difficulty.medium:
        return '⭐⭐ Difficoltà: Media';
      case Difficulty.hard:
        return '⭐⭐⭐ Difficoltà: Difficile';
      default:
        return 'Difficoltà sconosciuta';
    }
  }

  Color _getDifficultyColor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}