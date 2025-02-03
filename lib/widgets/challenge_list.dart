// lib/widgets/challenge_list.dart

import 'package:flutter/material.dart';
import '../models/challenge.dart';
import '../models/enums.dart';

class ChallengeList extends StatelessWidget {
  final List<Challenge> challenges;
  final bool showDaily;
  final bool showWeekly;

  const ChallengeList({
    Key? key,
    required this.challenges,
    this.showDaily = true,
    this.showWeekly = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filteredChallenges = challenges.where((challenge) {
      if (challenge.type == ChallengeType.daily && !showDaily) return false;
      if (challenge.type == ChallengeType.weekly && !showWeekly) return false;
      return true;
    }).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredChallenges.length,
      itemBuilder: (context, index) {
        return ChallengeCard(challenge: filteredChallenges[index]);
      },
    );
  }
}

class ChallengeCard extends StatelessWidget {
  final Challenge challenge;

  const ChallengeCard({
    Key? key,
    required this.challenge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getBorderColor(),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              challenge.color.withOpacity(0.1),
              challenge.color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTypeIcon(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChallengeInfo(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildProgressBar(),
              const SizedBox(height: 8),
              _buildRewardSection(),
              _buildTimeRemaining(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData icon;
    Color color = challenge.color;

    switch (challenge.type) {
      case ChallengeType.daily:
        icon = Icons.calendar_today;
        break;
      case ChallengeType.weekly:
        icon = Icons.date_range;
        break;
      case ChallengeType.special:
        icon = Icons.star;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _buildChallengeInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          challenge.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        Text(
          challenge.description,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: challenge.progressPercentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${challenge.currentProgress} / ${challenge.targetValue}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            Text(
              '${(challenge.progressPercentage * 100).toInt()}%',
              style: TextStyle(
                color: _getProgressColor(),
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRewardSection() {
    return Row(
      children: [
        const Icon(
          Icons.diamond,
          color: Colors.amber,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '+${challenge.crystalReward}',
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        if (challenge.status == ChallengeStatus.completed)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Icon(
              Icons.check_circle,
              color: challenge.color,
              size: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildTimeRemaining() {
    final remaining = challenge.expiration.difference(DateTime.now());
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            color: Colors.grey[600],
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            hours > 0
                ? '$hours ore e $minutes minuti'
                : '$minutes minuti',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  Color _getBorderColor() {
    switch (challenge.status) {
      case ChallengeStatus.completed:
        return Colors.green;
      case ChallengeStatus.inProgress:
        return challenge.color;
      case ChallengeStatus.failed:
        return Colors.red;
      case ChallengeStatus.notStarted:
        return Colors.grey.withOpacity(0.3);
    }
  }

  Color _getProgressColor() {
    switch (challenge.status) {
      case ChallengeStatus.completed:
        return Colors.green;
      case ChallengeStatus.failed:
        return Colors.red;
      default:
        return challenge.color;
    }
  }
}