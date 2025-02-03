// lib/models/challenge.dart

import 'package:flutter/material.dart';
import '../models/enums.dart';

class Challenge {
  final String id;
  final String title;
  final String description;
  final ChallengeType type;
  final int targetValue;
  final int crystalReward;
  final DateTime expiration;
  ChallengeStatus status;
  int currentProgress;

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

  double get progressPercentage => currentProgress / targetValue;
  bool get isCompleted => status == ChallengeStatus.completed;

  Color get color {
    switch (type) {
      case ChallengeType.daily:
        return Colors.blue;
      case ChallengeType.weekly:
        return Colors.purple;
      case ChallengeType.special:
        return Colors.orange;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.index,
    'currentProgress': currentProgress,
  };

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
}