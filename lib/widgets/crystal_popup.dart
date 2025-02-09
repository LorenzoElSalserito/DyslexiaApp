import 'package:flutter/material.dart';
import '../models/recognition_result.dart';

/// Widget che mostra un popup animato per i cristalli guadagnati,
/// supporta sia il feedback degli esercizi singoli che il riepilogo della sessione
class CrystalPopup extends StatefulWidget {
  final int earnedCrystals;
  final int level;
  final double progress;
  final RecognitionResult? recognitionResult;
  final bool isSessionSummary;
  final bool isStreakBonus;
  final int? consecutiveDays;
  final VoidCallback? onContinue;
  final VoidCallback? onEnd;

  const CrystalPopup({
    Key? key,
    required this.earnedCrystals,
    required this.level,
    required this.progress,
    this.recognitionResult,
    this.isSessionSummary = false,
    this.isStreakBonus = false,
    this.consecutiveDays,
    this.onContinue,
    this.onEnd,
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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 30.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 70.0,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _bonusScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.1),
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

  /// Determina il colore del cristallo in base al livello
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titolo del popup
            Text(
              widget.isStreakBonus
                  ? 'Bravo! Continua ad Esercitarti e ti regaleremo altri Cristalli'
                  : widget.isSessionSummary
                  ? 'Riepilogo Sessione'
                  : 'Cristalli Guadagnati!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: 'OpenDyslexic',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Animazione del cristallo
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotateAnimation.value * 0.2 - 0.1,
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
            const SizedBox(height: 20),

            // Cristalli guadagnati
            Text(
              '+${widget.earnedCrystals} Cristalli',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
                fontFamily: 'OpenDyslexic',
              ),
            ),

            // Giorni consecutivi (se applicabile)
            if (widget.consecutiveDays != null) ...[
              const SizedBox(height: 12),
              Text(
                'Giorni consecutivi: ${widget.consecutiveDays}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],

            // Risultato del riconoscimento (se presente)
            if (widget.recognitionResult != null) ...[
              const SizedBox(height: 16),
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
              const SizedBox(height: 8),
              Text(
                widget.recognitionResult!.getFeedbackMessage(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Pulsanti di azione
        if (widget.isSessionSummary) ...[
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: widget.onEnd ?? () => Navigator.of(context).pop(false),
            child: const Text(
              'Fine',
              style: TextStyle(fontFamily: 'OpenDyslexic'),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: widget.onContinue ?? () => Navigator.of(context).pop(true),
            child: const Text(
              'Continua',
              style: TextStyle(fontFamily: 'OpenDyslexic'),
            ),
          ),
        ] else ...[
          TextButton(
            child: const Text(
              'Continua',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            onPressed: widget.onContinue ?? () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: getCrystalColor(),
            ),
          ),
        ],
      ],
    );
  }
}