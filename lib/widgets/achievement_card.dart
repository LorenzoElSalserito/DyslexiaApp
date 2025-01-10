// achievement_card.dart
import 'package:flutter/material.dart';

enum AchievementType {
  levelUp,
  streak,
  accuracy,
  speedReading,
  subLevelMastery,
  dailyChallenge,
  weeklyChallenge,
  perfectScore,
  secret
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int requiredPoints;
  final bool isSecret;
  final AchievementType type;
  final int crystalReward;
  bool isUnlocked;
  final int progress;
  final int target;
  final Color? color;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.requiredPoints,
    required this.type,
    required this.crystalReward,
    this.isSecret = false,
    this.isUnlocked = false,
    this.progress = 0,
    required this.target,
    this.color,
  });

  double get progressPercentage => progress / target;

  Color get achievementColor {
    if (color != null) return color!;

    switch (type) {
      case AchievementType.levelUp:
        return Colors.blue;
      case AchievementType.streak:
        return Colors.orange;
      case AchievementType.accuracy:
        return Colors.green;
      case AchievementType.speedReading:
        return Colors.purple;
      case AchievementType.subLevelMastery:
        return Colors.teal;
      case AchievementType.dailyChallenge:
        return Colors.amber;
      case AchievementType.weeklyChallenge:
        return Colors.indigo;
      case AchievementType.perfectScore:
        return Colors.pink;
      case AchievementType.secret:
        return Colors.grey;
    }
  }
}

class AchievementCard extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback? onTap;
  final bool showAnimation;

  const AchievementCard({
    Key? key,
    required this.achievement,
    this.onTap,
    this.showAnimation = false,
  }) : super(key: key);

  @override
  _AchievementCardState createState() => _AchievementCardState();
}

class _AchievementCardState extends State<AchievementCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 60.0,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    if (widget.showAnimation) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.showAnimation ? _scaleAnimation.value : 1.0,
          child: Opacity(
            opacity: widget.showAnimation ? _opacityAnimation.value : 1.0,
            child: _buildCard(),
          ),
        );
      },
    );
  }

  Widget _buildCard() {
    return Card(
      elevation: widget.achievement.isUnlocked ? 8 : 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.achievement.isUnlocked
              ? widget.achievement.achievementColor
              : Colors.grey.withOpacity(0.3),
          width: widget.achievement.isUnlocked ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: widget.achievement.isUnlocked
                ? LinearGradient(
              colors: [
                widget.achievement.achievementColor.withOpacity(0.1),
                widget.achievement.achievementColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAchievementIcon(),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildAchievementInfo(),
                  ),
                ],
              ),
              if (widget.achievement.target > 0) ...[
                SizedBox(height: 12),
                _buildProgressIndicator(),
              ],
              if (widget.achievement.isUnlocked)
                _buildUnlockedIndicator(),
              if (widget.achievement.crystalReward > 0)
                _buildRewardIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: widget.achievement.achievementColor.withOpacity(
          widget.achievement.isUnlocked ? 0.2 : 0.1,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.achievement.icon,
        color: widget.achievement.isUnlocked
            ? widget.achievement.achievementColor
            : Colors.grey,
        size: 24,
      ),
    );
  }

  Widget _buildAchievementInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.achievement.isSecret && !widget.achievement.isUnlocked
              ? '???'
              : widget.achievement.title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: widget.achievement.isUnlocked
                ? widget.achievement.achievementColor
                : Colors.grey[800],
          ),
        ),
        SizedBox(height: 4),
        Text(
          widget.achievement.isSecret && !widget.achievement.isUnlocked
              ? 'Achievement segreto'
              : widget.achievement.description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: widget.achievement.progressPercentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.achievement.isUnlocked
                  ? widget.achievement.achievementColor
                  : Colors.blue,
            ),
            minHeight: 8,
          ),
        ),
        SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.achievement.progress} / ${widget.achievement.target}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '${(widget.achievement.progressPercentage * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.achievement.achievementColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnlockedIndicator() {
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            Icons.check_circle,
            color: widget.achievement.achievementColor,
            size: 20,
          ),
          SizedBox(width: 4),
          Text(
            'Sbloccato!',
            style: TextStyle(
              color: widget.achievement.achievementColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardIndicator() {
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(
            Icons.diamond,
            color: Colors.amber,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            '+${widget.achievement.crystalReward}',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}