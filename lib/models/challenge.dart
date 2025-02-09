// lib/models/challenge.dart

import 'package:flutter/material.dart';
import '../models/enums.dart';

/// Rappresenta una sfida del gioco con tutte le sue proprietà e stato
class Challenge {
  /// Identificatore univoco della sfida
  final String id;

  /// Titolo visualizzato della sfida
  final String title;

  /// Descrizione dettagliata della sfida
  final String description;

  /// Tipo di sfida (giornaliera, settimanale, speciale)
  final ChallengeType type;

  /// Valore obiettivo da raggiungere
  final int targetValue;

  /// Ricompensa base in cristalli
  final int crystalReward;

  /// Data e ora di scadenza della sfida
  final DateTime expiration;

  /// Stato corrente della sfida
  ChallengeStatus status;

  /// Progresso corrente verso l'obiettivo
  int currentProgress;

  /// Costruttore della sfida
  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.crystalReward,
    required this.expiration,
    this.status = ChallengeStatus.notStarted,
    this.currentProgress = 0,
  });

  /// Calcola la percentuale di completamento della sfida
  double get progressPercentage => currentProgress / targetValue;

  /// Verifica se la sfida è stata completata
  bool get isCompleted => status == ChallengeStatus.completed;

  /// Determina il colore della sfida in base al suo tipo
  Color get color {
    switch (type) {
      case ChallengeType.daily:
      // Sfide giornaliere in blu per coerenza con il tema dell'app
        return Colors.blue.shade700;
      case ChallengeType.weekly:
      // Sfide settimanali in viola per distinguerle dalle giornaliere
        return Colors.purple.shade700;
      case ChallengeType.special:
      // Sfide speciali in arancione per evidenziarle
        return Colors.orange.shade700;
    }
  }

  /// Converte la sfida in un formato JSON per il salvataggio
  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.index,
    'currentProgress': currentProgress,
  };

  /// Crea una sfida da un template e dati JSON
  factory Challenge.fromJson(Map<String, dynamic> json, Challenge template) {
    return Challenge(
      id: template.id,
      title: template.title,
      description: template.description,
      type: template.type,
      targetValue: template.targetValue,
      crystalReward: template.crystalReward,
      expiration: template.expiration,
      status: ChallengeStatus.values[json['status'] as int],
      currentProgress: json['currentProgress'] as int,
    );
  }

  /// Calcola la ricompensa finale considerando eventuali bonus
  int calculateFinalReward({
    required int consecutiveDays,
    required int newGamePlusLevel,
  }) {
    double multiplier = 1.0;

    // Bonus per giorni consecutivi di gioco
    if (consecutiveDays > 1) {
      multiplier += (consecutiveDays - 1) * 0.1; // +10% per ogni giorno dopo il primo
    }

    // Bonus New Game+
    if (newGamePlusLevel > 0) {
      multiplier += newGamePlusLevel * 0.5; // +50% per ogni livello NG+
    }

    // Bonus per completamento anticipato
    final timeRemaining = expiration.difference(DateTime.now());
    if (timeRemaining.inHours > 12) {
      multiplier += 0.2; // +20% per completamento anticipato
    }

    return (crystalReward * multiplier).round();
  }

  /// Verifica se la sfida è ancora valida
  bool isValid() {
    return DateTime.now().isBefore(expiration);
  }

  /// Aggiorna lo stato della sfida in base al progresso
  void updateProgress(int newProgress) {
    currentProgress = newProgress;
    if (currentProgress >= targetValue && status != ChallengeStatus.completed) {
      status = ChallengeStatus.completed;
    }
  }

  /// Verifica se la sfida è scaduta
  bool isExpired() {
    return DateTime.now().isAfter(expiration);
  }

  /// Ottiene il tempo rimanente formattato
  String getTimeRemaining() {
    final difference = expiration.difference(DateTime.now());
    if (difference.inDays > 0) {
      return '${difference.inDays}g ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inMinutes}m';
    }
  }
}