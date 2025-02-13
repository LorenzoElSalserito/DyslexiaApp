// recognition_result.dart
import '../config/app_config.dart';

class RecognitionResult {
  final String text;              // Testo riconosciuto
  final double confidence;        // Livello di confidenza del riconoscimento
  final double similarity;        // Similarità con il testo target
  final bool isCorrect;          // Se il testo è considerato corretto
  final Duration duration;        // Durata della registrazione
  final DateTime timestamp;       // Timestamp del riconoscimento

  RecognitionResult({
    required this.text,
    required this.confidence,
    required this.similarity,
    required this.isCorrect,
    this.duration = const Duration(seconds: 0),
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  // Factory constructor per creare un risultato dal JSON di VOSK
  factory RecognitionResult.fromVoskResult(
      Map<String, dynamic> json,
      String targetText,
      ) {
    final recognizedText = json['text'] as String? ?? '';
    final List<dynamic> words = json['result'] as List<dynamic>? ?? [];

    // Calcola la confidenza media dalle parole riconosciute
    double totalConfidence = 0.0;
    if (words.isNotEmpty) {
      for (var word in words) {
        totalConfidence += (word['conf'] as num).toDouble();
      }
      totalConfidence /= words.length;
    }

    final dur = Duration(milliseconds: (json['duration'] as num? ?? 0).toInt());

    return RecognitionResult(
      text: recognizedText,
      confidence: totalConfidence,
      similarity: totalConfidence, // Usiamo la confidenza di VOSK come similarità
      duration: dur,
      isCorrect: totalConfidence >= AppConfig.minSimilarityScore,
    );
  }

  // Metodo per calcolare i punti bonus basati sulla performance
  double calculateBonusMultiplier() {
    double multiplier = 1.0;

    // Bonus per alta similarità
    if (similarity >= AppConfig.perfectSimilarityScore) {
      multiplier += 0.5;  // +50% per riconoscimento quasi perfetto
    } else if (similarity >= AppConfig.minSimilarityScore + 0.1) {
      multiplier += 0.3;  // +30% per riconoscimento molto buono
    } else if (similarity >= AppConfig.minSimilarityScore) {
      multiplier += 0.1;  // +10% per riconoscimento accettabile
    }

    // Bonus per alta confidenza
    if (confidence > 0.9) {
      multiplier += 0.2;
    } else if (confidence > 0.8) {
      multiplier += 0.1;
    }

    // Penalità per durata eccessiva (se più di 10 secondi)
    if (duration.inSeconds > 10) {
      multiplier -= (duration.inSeconds - 10) * 0.05;
      if (multiplier < 0.5) multiplier = 0.5; // Non scendere sotto il 50%
    }

    return multiplier;
  }

  // Genera un messaggio di feedback basato sul risultato
  String getFeedbackMessage() {
    if (similarity >= AppConfig.perfectSimilarityScore) {
      return 'Eccellente! Lettura perfetta!';
    } else if (similarity >= AppConfig.minSimilarityScore + 0.1) {
      return 'Molto bene! Continua così!';
    } else if (similarity >= AppConfig.minSimilarityScore) {
      return 'Buono! Puoi ancora migliorare.';
    } else if (similarity >= AppConfig.minSimilarityScore - 0.1) {
      return 'Ci sei quasi! Prova ancora.';
    } else {
      return 'Riprova. Concentrati sulla pronuncia.';
    }
  }

  // Converte il risultato in formato JSON
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'confidence': confidence,
      'similarity': similarity,
      'isCorrect': isCorrect,
      'duration': duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Crea una stringa di debug del risultato
  @override
  String toString() {
    return 'RecognitionResult{'
        'text: $text, '
        'confidence: ${confidence.toStringAsFixed(2)}, '
        'similarity: ${similarity.toStringAsFixed(2)}, '
        'isCorrect: $isCorrect, '
        'duration: ${duration.inSeconds}s}';
  }
}