// game_notification_manager.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/streak_notification.dart';

enum NotificationType {
  streak,
  achievement,
  levelUp,
  bonus,
  challenge
}

class GameNotificationManager {
  static final GameNotificationManager _instance = GameNotificationManager._internal();
  factory GameNotificationManager() => _instance;
  GameNotificationManager._internal();

  final StreamController<Widget> _notificationController = StreamController<Widget>.broadcast();
  Stream<Widget> get notificationStream => _notificationController.stream;

  OverlayEntry? _currentOverlay;
  Timer? _dismissTimer;

  void showStreakNotification(BuildContext context, int streak, double multiplier) {
    final notification = StreakNotification(
      streak: streak,
      multiplier: multiplier,
      onDismiss: () => _removeCurrentOverlay(),
    );
    _showNotification(context, notification);
  }

  void showAchievementUnlocked(BuildContext context, String title, String description) {
    final notification = _buildAchievementNotification(title, description);
    _showNotification(context, notification);
  }

  void showLevelUp(BuildContext context, int level) {
    final notification = _buildLevelUpNotification(level);
    _showNotification(context, notification);
  }

  void showBonusUnlocked(BuildContext context, String bonusType, double multiplier) {
    final notification = _buildBonusNotification(bonusType, multiplier);
    _showNotification(context, notification);
  }

  void _showNotification(BuildContext context, Widget notification) {
    _removeCurrentOverlay();

    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Center(child: notification),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);

    _dismissTimer?.cancel();
    _dismissTimer = Timer(Duration(seconds: 3), () {
      _removeCurrentOverlay();
    });

    _notificationController.add(notification);
  }

  void _removeCurrentOverlay() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  Widget _buildAchievementNotification(String title, String description) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade700],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, color: Colors.white),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Achievement Sbloccato!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelUpNotification(int level) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade700],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_upward, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Livello $level Sbloccato!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusNotification(String bonusType, double multiplier) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.green.shade700],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: Colors.white),
          SizedBox(width: 8),
          Text(
            '$bonusType: x${multiplier.toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void dispose() {
    _dismissTimer?.cancel();
    _removeCurrentOverlay();
    _notificationController.close();
  }
}