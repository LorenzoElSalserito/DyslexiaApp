import 'package:flutter/material.dart';
import '../models/recognition_result.dart';
import '../utils/text_similarity.dart';

class VoiceRecognitionFeedback extends StatelessWidget {
  final bool isRecording;
  final double? volumeLevel;
  final RecognitionResult? result;
  final String targetText;

  const VoiceRecognitionFeedback({
    Key? key,
    required this.isRecording,
    this.volumeLevel,
    this.result,
    required this.targetText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isRecording) _buildRecordingIndicator(),
        if (result != null) _buildRecognitionResult(context),
      ],
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PulsatingCircle(),
              SizedBox(width: 8),
              Text(
                'Registrazione in corso...',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ),
          if (volumeLevel != null) ...[
            SizedBox(height: 8),
            _buildVolumeMeter(),
          ],
        ],
      ),
    );
  }

  Widget _buildVolumeMeter() {
    return Column(
      children: [
        Container(
          height: 20,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: volumeLevel,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.red.withOpacity(0.5),
              ),
            ),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Livello Volume',
          style: TextStyle(
            color: Colors.red[300],
            fontSize: 12,
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ],
    );
  }

  Widget _buildRecognitionResult(BuildContext context) {
    final similarity = result!.similarity * 100;
    final isCorrect = result!.isCorrect;
    final textFeedback = TextSimilarity.getDetailedFeedback(
        result!.text,
        targetText
    );

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Testo Riconosciuto:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              fontFamily: 'OpenDyslexic',
            ),
          ),
          SizedBox(height: 8),
          _buildTextComparison(),
          SizedBox(height: 16),
          _buildAccuracyIndicator(similarity, isCorrect),
          SizedBox(height: 12),
          _buildDetailedFeedback(textFeedback, isCorrect),
          if (!isCorrect) _buildCommonErrorsSection(),
        ],
      ),
    );
  }

  Widget _buildTextComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result!.text,
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'OpenDyslexic',
            height: 1.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Testo Target:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            fontFamily: 'OpenDyslexic',
          ),
        ),
        Text(
          targetText,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontFamily: 'OpenDyslexic',
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAccuracyIndicator(double similarity, bool isCorrect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Accuratezza:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontFamily: 'OpenDyslexic',
              ),
            ),
            Text(
              '${similarity.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.green : Colors.orange,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: result!.similarity,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isCorrect ? Colors.green : Colors.orange,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedFeedback(String feedback, bool isCorrect) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.info,
                color: isCorrect ? Colors.green : Colors.orange,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Feedback:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            feedback,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey[700],
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommonErrorsSection() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggerimenti per migliorare:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange[700],
              fontFamily: 'OpenDyslexic',
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• Leggi lentamente e con calma\n'
                '• Concentrati su una parola alla volta\n'
                '• Usa il dito per seguire il testo\n'
                '• Prendi un respiro profondo prima di iniziare',
            style: TextStyle(
              color: Colors.orange[700],
              fontSize: 14,
              height: 1.5,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }
}

class PulsatingCircle extends StatefulWidget {
  @override
  _PulsatingCircleState createState() => _PulsatingCircleState();
}

class _PulsatingCircleState extends State<PulsatingCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(1 - _animation.value),
            border: Border.all(color: Colors.red),
          ),
        );
      },
    );
  }
}