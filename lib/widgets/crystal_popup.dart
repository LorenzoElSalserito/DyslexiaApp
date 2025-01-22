import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/recognition_result.dart';

class CrystalReward {
  final int baseCrystals;
  final double streakMultiplier;
  final double difficultyMultiplier;
  final double newGamePlusMultiplier;
  final int streak;

  CrystalReward({
    required this.baseCrystals,
    this.streakMultiplier = 1.0,
    this.difficultyMultiplier = 1.0,
    this.newGamePlusMultiplier = 1.0,
    this.streak = 0,
  });

  int get totalCrystals {
    return (baseCrystals * streakMultiplier * difficultyMultiplier * newGamePlusMultiplier).round();
  }
}

class CrystalPopup extends StatefulWidget {
  final int earnedCrystals;
  final int level;
  final double progress;
  final RecognitionResult? recognitionResult;

  const CrystalPopup({
    Key? key,
    required this.earnedCrystals,
    required this.level,
    required this.progress,
    this.recognitionResult,
  }) : super(key: key);

  @override
  _CrystalPopupState createState() => _CrystalPopupState();
}

class _CrystalPopupState extends State<CrystalPopup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _bonusScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2),
        weight: 30.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 70.0,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, 0.6, curve: Curves.elasticOut),
    ));

    _rotateAnimation = Tween<double>(
      begin: -0.2,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _bonusScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.1),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0),
        weight: 60.0,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color getCrystalColor() {
    double opacity = 0.5 + (widget.progress * 0.5);
    opacity = opacity.clamp(0.0, 1.0);

    switch (widget.level) {
      case 1:
        return Colors.red.withOpacity(opacity);
      case 2:
        return Colors.orange.withOpacity(opacity);
      case 3:
        return Colors.yellow.withOpacity(opacity);
      case 4:
        return Colors.blue.withOpacity(opacity);
      default:
        return Colors.purple.withOpacity(opacity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white.withOpacity(0.95),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotateAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: getCrystalColor().withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.diamond,
                      size: 100,
                      color: getCrystalColor(),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 20),
          Text(
            '${widget.earnedCrystals} Cristalli',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          if (widget.recognitionResult != null) ...[
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: widget.recognitionResult!.similarity,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.recognitionResult!.similarity >= 0.85
                    ? Colors.green
                    : Colors.orange,
              ),
              minHeight: 8,
            ),
            SizedBox(height: 8),
            Text(
              widget.recognitionResult!.getFeedbackMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          child: Text('Continua'),
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: getCrystalColor(),
            textStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}