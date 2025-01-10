
// feedback_service.dart

import 'package:flutter/services.dart';
import '../models/recognition_result.dart';

enum FeedbackType {
  success,
  error,
  warning,
  progress
}

class FeedbackOptions {
  final bool useVibration;
  final bool useSound;
  final bool useVisual;

  FeedbackOptions({
    this.useVibration = true,
    this.useSound = true,
    this.useVisual = true,
  });
}

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;

  FeedbackOptions _options = FeedbackOptions();
  bool _isEnabled = true;

  FeedbackService._internal();

  void initialize(FeedbackOptions options) {
    _options = options;
  }

  Future<void> provideFeedback(FeedbackType type, {double? intensity}) async {
    if (!_isEnabled) return;

    switch (type) {
      case FeedbackType.success:
        await _provideSuccessFeedback();
        break;
      case FeedbackType.error:
        await _provideErrorFeedback();
        break;
      case FeedbackType.warning:
        await _provideWarningFeedback();
        break;
      case FeedbackType.progress:
        await _provideProgressFeedback(intensity ?? 1.0);
        break;
    }
  }

  Future<void> _provideSuccessFeedback() async {
    if (_options.useVibration) {
      await HapticFeedback.mediumImpact();
    }
  }

  Future<void> _provideErrorFeedback() async {
    if (_options.useVibration) {
      await HapticFeedback.heavyImpact();
    }
  }

  Future<void> _provideWarningFeedback() async {
    if (_options.useVibration) {
      await HapticFeedback.lightImpact();
    }
  }

  Future<void> _provideProgressFeedback(double intensity) async {
    if (_options.useVibration) {
      if (intensity > 0.8) {
        await HapticFeedback.mediumImpact();
      } else if (intensity > 0.5) {
        await HapticFeedback.selectionClick();
      } else {
        await HapticFeedback.lightImpact();
      }
    }
  }

  Future<void> handleRecognitionResult(RecognitionResult result) async {
    if (result.isCorrect) {
      await provideFeedback(FeedbackType.success);
    } else if (result.similarity > 0.7) {
      await provideFeedback(FeedbackType.warning);
    } else {
      await provideFeedback(FeedbackType.error);
    }
  }

  Future<void> handleVolumeLevel(double level) async {
    if (level > 0.8) {
      await provideFeedback(FeedbackType.progress, intensity: level);
    }
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  void updateOptions(FeedbackOptions newOptions) {
    _options = newOptions;
  }

  FeedbackOptions get currentOptions => _options;
  bool get isEnabled => _isEnabled;
}

// Estensione per semplificare l'uso del feedback
extension FeedbackExtension on RecognitionResult {
  Future<void> provideFeedback() async {
    final feedbackService = FeedbackService();
    await feedbackService.handleRecognitionResult(this);
  }
}