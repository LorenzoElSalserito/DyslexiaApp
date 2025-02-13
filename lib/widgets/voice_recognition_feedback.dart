import 'package:flutter/material.dart';
import '../models/recognition_result.dart';
import 'dart:math' as math;

class VoiceRecognitionFeedback extends StatelessWidget {
  // Parametri principali
  final bool isRecording;
  final String targetText;
  final double volumeLevel;
  final RecognitionResult? result;
  final int? currentAttempt;
  final int? totalAttempts;

  // Costanti di stile
  static const double _maxWaveHeight = 100.0;
  static const int _wavePoints = 12;
  static const Duration _waveDuration = Duration(milliseconds: 600);  // Diminuito da 1500 a 600 per animazione più veloce

  const VoiceRecognitionFeedback({
    Key? key,
    required this.isRecording,
    required this.targetText,
    this.volumeLevel = 0.0,
    this.result,
    this.currentAttempt,
    this.totalAttempts,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicatore di progresso delle registrazioni
        if (currentAttempt != null && totalAttempts != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalAttempts!, (index) {
                final isCompleted = index < currentAttempt!;
                final isCurrent = index == currentAttempt;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: isCompleted
                        ? Colors.green
                        : isCurrent
                        ? Colors.yellowAccent
                        : Colors.grey[300],
                    child: isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                );
              }),
            ),
          ),

        // Visualizzazione dell'onda sonora durante la registrazione
        if (isRecording)
          SizedBox(
            height: _maxWaveHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_wavePoints, (index) {
                return _WaveBar(
                  index: index,
                  volumeLevel: volumeLevel,
                  maxHeight: _maxWaveHeight,
                  duration: _waveDuration,
                );
              }),
            ),
          ),

        // Visualizzazione del risultato del riconoscimento
        if (result != null && !isRecording)
          _buildRecognitionResult(context),

        // Messaggi informativi
        if (isRecording)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Sto ascoltando...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecognitionResult(BuildContext context) {
    if (result == null) return const SizedBox.shrink();

    final similarity = (result!.similarity * 100).toStringAsFixed(1);
    final color = result!.isCorrect ? Colors.green : Colors.orange;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result!.isCorrect ? Icons.check_circle : Icons.info,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  'Accuratezza: $similarity%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Testo riconosciuto:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              result!.text,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Text(result!.getFeedbackMessage()),
          ],
        ),
      ),
    );
  }
}

/// Widget animato che rappresenta una barra dell'onda sonora
class _WaveBar extends StatefulWidget {
  final int index;
  final double volumeLevel;
  final double maxHeight;
  final Duration duration;

  const _WaveBar({
    Key? key,
    required this.index,
    required this.volumeLevel,
    required this.maxHeight,
    required this.duration,
  }) : super(key: key);

  @override
  State<_WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<_WaveBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Animazione più fluida con curve personalizzata
    _heightAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutSine)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.3)
            .chain(CurveTween(curve: Curves.easeInSine)),
        weight: 50,
      ),
    ]).animate(_controller);

    // Aggiunge un delay casuale per ogni barra
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) {
        _controller.repeat();
      }
    });
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
        final height = widget.maxHeight *
            _heightAnimation.value *
            widget.volumeLevel *
            (0.4 + (widget.index % 2) * 0.2);  // Aggiunge variazione all'altezza

        return Container(
          width: 4,
          height: height.clamp(4.0, widget.maxHeight),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.black87.withOpacity(0.8),  // Cambiato da blue a black87
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}