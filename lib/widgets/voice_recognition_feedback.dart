import 'package:flutter/material.dart';
import '../models/recognition_result.dart';

class VoiceRecognitionFeedback extends StatelessWidget {
  final bool isRecording;
  final String targetText;
  final double volumeLevel;
  final RecognitionResult? result;
  final int? currentAttempt;
  final int? totalAttempts;

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
        if (currentAttempt != null && totalAttempts != null)
          _buildProgressIndicator(),
        if (isRecording)
          _buildRecordingIndicator(),
        if (result != null && !isRecording)
          _buildRecognitionResult(context),
        if (isRecording)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Sto ascoltando...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
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
    );
  }

  Widget _buildRecordingIndicator() {
    return SizedBox(
      height: 100,
      child: Center(
        child: RecordingPulseIndicator(volumeLevel: volumeLevel),
      ),
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
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Testo riconosciuto:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result!.text,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result!.getFeedbackMessage(),
              style: const TextStyle(fontFamily: 'OpenDyslexic'),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordingPulseIndicator extends StatefulWidget {
  final double volumeLevel;

  const RecordingPulseIndicator({
    Key? key,
    required this.volumeLevel,
  }) : super(key: key);

  @override
  State<RecordingPulseIndicator> createState() => _RecordingPulseIndicatorState();
}

class _RecordingPulseIndicatorState extends State<RecordingPulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 50.0 + (widget.volumeLevel * 30.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            );
          },
        ),
        Container(
          width: size * 0.8,
          height: size * 0.8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.shade600,
          ),
          child: const Icon(
            Icons.mic,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}