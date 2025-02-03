import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/streak_notification.dart';

/// Definisce i diversi tipi di notifiche che possono essere mostrate nel gioco
enum NotificationType {
  streak,      // Notifica per le serie di successi consecutivi
  achievement, // Notifica per gli obiettivi sbloccati
  levelUp,     // Notifica per l'avanzamento di livello
  bonus,       // Notifica per bonus speciali
  challenge    // Notifica per le sfide
}

/// Gestore centralizzato delle notifiche di gioco
/// Implementa il pattern Singleton per garantire un unico punto di gestione
class GameNotificationManager {
  // Implementazione del Singleton
  static final GameNotificationManager _instance = GameNotificationManager._internal();
  factory GameNotificationManager() => _instance;
  GameNotificationManager._internal();

  // Controller per lo stream delle notifiche e gestione della visualizzazione
  final StreamController<Widget> _notificationController = StreamController<Widget>.broadcast();
  Stream<Widget> get notificationStream => _notificationController.stream;

  // Gestione dell'overlay delle notifiche attuali
  OverlayEntry? _currentOverlay;
  Timer? _dismissTimer;

  /// Mostra una notifica di streak (serie di successi consecutivi)
  void showStreakNotification(BuildContext context, int streak, double multiplier) {
    final notification = StreakNotification(
      streak: streak,
      multiplier: multiplier,
      onDismiss: () => _removeCurrentOverlay(),
    );
    _showNotification(context, notification);
  }

  /// Mostra una notifica per un achievement sbloccato
  void showAchievementUnlocked(BuildContext context, String title, String description) {
    final notification = _buildAchievementNotification(title, description);
    _showNotification(context, notification);
  }

  /// Mostra una notifica di avanzamento livello
  void showLevelUp(BuildContext context, int level) {
    final notification = _buildLevelUpNotification(level);
    _showNotification(context, notification);
  }

  /// Mostra una notifica per un bonus sbloccato
  void showBonusUnlocked(BuildContext context, String bonusType, double multiplier) {
    final notification = _buildBonusNotification(bonusType, multiplier);
    _showNotification(context, notification);
  }

  /// Metodo interno per mostrare qualsiasi tipo di notifica
  void _showNotification(BuildContext context, Widget notification) {
    // Rimuove eventuali notifiche precedenti
    _removeCurrentOverlay();

    // Crea una nuova entry nell'overlay
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

    // Inserisce la notifica nell'overlay
    Overlay.of(context).insert(_currentOverlay!);

    // Imposta il timer per la rimozione automatica
    _dismissTimer?.cancel();
    _dismissTimer = Timer(Duration(seconds: 3), () {
      _removeCurrentOverlay();
    });

    // Notifica gli ascoltatori dello stream
    _notificationController.add(notification);
  }

  /// Rimuove la notifica corrente
  void _removeCurrentOverlay() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Costruisce una notifica per l'unlock di un achievement
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

  /// Costruisce una notifica per l'avanzamento di livello
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

  /// Costruisce una notifica per l'unlock di un bonus
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

  /// Rilascia le risorse quando il manager viene distrutto
  void dispose() {
    _dismissTimer?.cancel();
    _removeCurrentOverlay();
    _notificationController.close();
  }
}