// lib/services/game_notification_manager.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/streak_notification.dart';
import '../models/recognition_result.dart';
import '../widgets/crystal_popup.dart';

/// Definisce i diversi tipi di notifiche che possono essere mostrate nel gioco
enum NotificationType {
  streak,      // Notifica per le serie di successi consecutivi
  achievement, // Notifica per gli obiettivi sbloccati
  levelUp,     // Notifica per l'avanzamento di livello
  bonus,       // Notifica per bonus speciali (es. login consecutivi)
  challenge,   // Notifica per le sfide
  exercise     // Notifica per gli esercizi
}

/// Gestore centralizzato delle notifiche di gioco.
/// Implementa il pattern Singleton per garantire un unico punto di gestione
/// delle notifiche in tutta l'applicazione.
class GameNotificationManager {
  // Implementazione del Singleton
  static final GameNotificationManager _instance = GameNotificationManager._internal();
  factory GameNotificationManager() => _instance;
  GameNotificationManager._internal();

  // Controller per lo stream delle notifiche
  final StreamController<Widget> _notificationController = StreamController<Widget>.broadcast();
  Stream<Widget> get notificationStream => _notificationController.stream;

  // Gestione dell'overlay delle notifiche attuali
  OverlayEntry? _currentOverlay;
  Timer? _dismissTimer;

  /// Mostra una notifica per il bonus di login giornaliero
  /// Il bonus aumenta di 0.5 per ogni giorno consecutivo
  Future<void> showDailyLoginBonus(BuildContext context, int consecutiveDays) async {
    // Calcola il bonus base (10) più l'incremento per i giorni consecutivi
    final bonus = (10 + (consecutiveDays - 1) * 0.5).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CrystalPopup(
        earnedCrystals: bonus,
        level: 1,  // Il livello non influenza il colore in questo caso
        progress: 1.0,
        isStreakBonus: true,
        consecutiveDays: consecutiveDays,
        onContinue: () => Navigator.of(context).pop(),
      ),
    );
  }

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

  /// Mostra una notifica per il risultato di un esercizio
  void showExerciseResult(BuildContext context, RecognitionResult result, int crystalsEarned) {
    final notification = _buildExerciseResultNotification(result, crystalsEarned);
    _showNotification(context, notification);
  }

  /// Mostra una notifica per la fine della sessione di esercizi
  void showSessionComplete(BuildContext context, double averageAccuracy, int totalCrystals) {
    final notification = _buildSessionCompleteNotification(averageAccuracy, totalCrystals);
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
    _dismissTimer = Timer(const Duration(seconds: 3), () {
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

  /// Costruisce una notifica per un achievement
  Widget _buildAchievementNotification(String title, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          const Icon(Icons.emoji_events, color: Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'OpenDyslexic',
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          const Icon(Icons.arrow_upward, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            'Livello $level Sbloccato!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  /// Costruisce una notifica per il risultato di un esercizio
  Widget _buildExerciseResultNotification(RecognitionResult result, int crystalsEarned) {
    final isSuccess = result.isCorrect;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSuccess
              ? [Colors.green.shade400, Colors.green.shade700]
              : [Colors.orange.shade400, Colors.orange.shade700],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (isSuccess ? Colors.green : Colors.orange).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            result.getFeedbackMessage(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.diamond, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '+$crystalsEarned',
                style: const TextStyle(
                  color: Colors.white,
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

  /// Costruisce una notifica per il completamento della sessione
  Widget _buildSessionCompleteNotification(double averageAccuracy, int totalCrystals) {
    final isGoodAccuracy = averageAccuracy >= 0.85;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGoodAccuracy
              ? [Colors.green.shade400, Colors.green.shade700]
              : [Colors.orange.shade400, Colors.orange.shade700],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (isGoodAccuracy ? Colors.green : Colors.orange).withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Sessione Completata!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Accuratezza Media: ${(averageAccuracy * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.diamond, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                'Totale: $totalCrystals',
                style: const TextStyle(
                  color: Colors.white,
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

  /// Rilascia le risorse quando il manager viene distrutto
  void dispose() {
    _dismissTimer?.cancel();
    _removeCurrentOverlay();
    _notificationController.close();
  }
}