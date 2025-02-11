import 'package:flutter/material.dart';
import '../models/recognition_result.dart';

/// Widget che mostra un popup animato per i cristalli guadagnati.
/// Gestisce sia il feedback per singoli esercizi che il riepilogo delle sessioni
/// e il bonus giornaliero, fornendo un'esperienza utente gratificante e informativa.
class CrystalPopup extends StatefulWidget {
  final int earnedCrystals;           // Cristalli guadagnati in questa sessione
  final int level;                    // Livello attuale del giocatore
  final double progress;              // Progresso/accuratezza dell'esercizio
  final RecognitionResult? recognitionResult;  // Risultato del riconoscimento vocale
  final bool isSessionSummary;        // Indica se è un riepilogo sessione
  final bool isStreakBonus;           // Indica se è un bonus streak
  final int? consecutiveDays;         // Giorni consecutivi di gioco
  final VoidCallback? onContinue;     // Callback per continuare
  final VoidCallback? onEnd;          // Callback per terminare
  final bool isDailyLoginBonus;       // Indica se è un bonus di login giornaliero

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
    this.isDailyLoginBonus = false,
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
    _setupAnimations();
    _controller.forward();
  }

  /// Configura tutte le animazioni necessarie per il popup
  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Animazione di scala principale
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 60.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 20.0,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Animazione di rotazione del cristallo
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));

    // Animazione di scala per il bonus
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
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
  }

  /// Determina il colore del cristallo in base al livello e al progresso
  Color _getCrystalColor() {
    double opacity = 0.5 + (widget.progress * 0.5);
    opacity = opacity.clamp(0.0, 1.0);
    return switch (widget.level) {
      1 => Colors.red.withOpacity(opacity),
      2 => Colors.orange.withOpacity(opacity),
      3 => Colors.yellow.withOpacity(opacity),
      4 => Colors.blue.withOpacity(opacity),
      _ => Colors.purple.withOpacity(opacity),
    };
  }

  @override
  Widget build(BuildContext context) {
    String titleText;
    String messageText = '';

    // Determina il titolo e il messaggio in base al tipo di popup
    if (widget.isDailyLoginBonus) {
      titleText = 'Bonus Giornaliero!';
      messageText = widget.consecutiveDays != null && widget.consecutiveDays! > 1
          ? 'Hai effettuato il login per ${widget.consecutiveDays} giorni consecutivi!\nBravo! Continua ad Esercitarti e ti regaleremo altri Cristalli'
          : 'Benvenuto di nuovo!\nContinua ad esercitarti ogni giorno per ottenere più bonus!';
    } else if (widget.isSessionSummary) {
      titleText = 'Riepilogo Sessione';
    } else if (widget.isStreakBonus) {
      titleText = 'Bonus Streak!';
    } else {
      titleText = 'Cristalli Guadagnati!';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.white.withOpacity(0.95),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titleText,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontFamily: 'OpenDyslexic',
              ),
              textAlign: TextAlign.center,
            ),
            if (messageText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                messageText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.green,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildCrystalAnimation(),
            const SizedBox(height: 20),
            _buildCrystalReward(),
            if (widget.consecutiveDays != null && !widget.isDailyLoginBonus)
              _buildConsecutiveDays(),
            if (widget.recognitionResult != null)
              _buildRecognitionResult(),
          ],
        ),
      ),
      actions: _buildActions(context),
    );
  }

  Widget _buildCrystalAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.isDailyLoginBonus || widget.isStreakBonus
            ? _bonusScaleAnimation.value
            : _scaleAnimation.value;
        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: _rotateAnimation.value * 0.2 - 0.1,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: _getCrystalColor().withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.diamond,
                size: 100,
                color: _getCrystalColor(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCrystalReward() {
    return Text(
      '+${widget.earnedCrystals} Cristalli',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
        fontFamily: 'OpenDyslexic',
      ),
    );
  }

  Widget _buildConsecutiveDays() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Giorni consecutivi: ${widget.consecutiveDays}',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[600],
          fontFamily: 'OpenDyslexic',
        ),
      ),
    );
  }

  Widget _buildRecognitionResult() {
    return Column(
      children: [
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
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (widget.isSessionSummary) {
      return [
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
      ];
    } else {
      return [
        TextButton(
          onPressed: widget.onContinue ?? () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: _getCrystalColor(),
          ),
          child: const Text(
            'Continua',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ),
      ];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}