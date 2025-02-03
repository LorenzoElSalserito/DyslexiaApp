import 'package:flutter/services.dart';
import 'dart:async';
import '../models/recognition_result.dart';
import '../config/app_config.dart';

/// Tipi di feedback disponibili nell'applicazione
enum FeedbackType {
  success,  // Per i risultati corretti
  error,    // Per gli errori
  warning,  // Per le situazioni che richiedono attenzione
  progress  // Per indicare il progresso durante l'esercizio
}

/// Configurazione del sistema di feedback
class FeedbackOptions {
  final bool useVibration;  // Feedback aptico
  final bool useSound;      // Feedback sonoro
  final bool useVisual;     // Feedback visivo
  final double volumeThreshold;  // Soglia per il feedback sonoro
  final Duration feedbackDuration;  // Durata del feedback

  FeedbackOptions({
    this.useVibration = true,
    this.useSound = true,
    this.useVisual = true,
    this.volumeThreshold = AppConfig.volumeThreshold,
    this.feedbackDuration = const Duration(milliseconds: 300),
  });

  // Crea una copia delle opzioni con modifiche
  FeedbackOptions copyWith({
    bool? useVibration,
    bool? useSound,
    bool? useVisual,
    double? volumeThreshold,
    Duration? feedbackDuration,
  }) {
    return FeedbackOptions(
      useVibration: useVibration ?? this.useVibration,
      useSound: useSound ?? this.useSound,
      useVisual: useVisual ?? this.useVisual,
      volumeThreshold: volumeThreshold ?? this.volumeThreshold,
      feedbackDuration: feedbackDuration ?? this.feedbackDuration,
    );
  }
}

/// Servizio principale per la gestione del feedback
class FeedbackService {
  // Implementazione singleton per garantire un'unica istanza
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;

  // Stato e configurazione del servizio
  FeedbackOptions _options = FeedbackOptions();
  bool _isEnabled = true;
  final _feedbackController = StreamController<FeedbackEvent>.broadcast();

  // Costruttore privato per il singleton
  FeedbackService._internal();

  // Inizializzazione del servizio con opzioni personalizzate
  void initialize(FeedbackOptions options) {
    _options = options;
    _isEnabled = true;
  }

  /// Fornisce feedback in base al tipo richiesto
  Future<void> provideFeedback(FeedbackType type, {double? intensity}) async {
    if (!_isEnabled) return;

    // Crea un evento di feedback
    final event = FeedbackEvent(
      type: type,
      intensity: intensity ?? 1.0,
      timestamp: DateTime.now(),
    );

    try {
      // Esegue il feedback appropriato in base al tipo
      switch (type) {
        case FeedbackType.success:
          await _provideSuccessFeedback(event);
        case FeedbackType.error:
          await _provideErrorFeedback(event);
        case FeedbackType.warning:
          await _provideWarningFeedback(event);
        case FeedbackType.progress:
          await _provideProgressFeedback(event);
      }

      // Notifica gli ascoltatori
      _feedbackController.add(event);
    } catch (e) {
      print('Errore durante il feedback: $e');
    }
  }

  /// Feedback per successi
  Future<void> _provideSuccessFeedback(FeedbackEvent event) async {
    if (_options.useVibration) {
      await HapticFeedback.mediumImpact();
    }
    // Qui si potrebbero aggiungere suoni o altri tipi di feedback
  }

  /// Feedback per errori
  Future<void> _provideErrorFeedback(FeedbackEvent event) async {
    if (_options.useVibration) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Feedback per avvisi
  Future<void> _provideWarningFeedback(FeedbackEvent event) async {
    if (_options.useVibration) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Feedback per il progresso
  Future<void> _provideProgressFeedback(FeedbackEvent event) async {
    if (_options.useVibration) {
      // Intensità del feedback basata sul progresso
      if (event.intensity > 0.8) {
        await HapticFeedback.mediumImpact();
      } else if (event.intensity > 0.5) {
        await HapticFeedback.selectionClick();
      } else {
        await HapticFeedback.lightImpact();
      }
    }
  }

  /// Gestisce il feedback per i risultati del riconoscimento vocale
  Future<void> handleRecognitionResult(RecognitionResult result) async {
    if (result.isCorrect) {
      await provideFeedback(FeedbackType.success);
    } else if (result.similarity > 0.7) {
      await provideFeedback(FeedbackType.warning);
    } else {
      await provideFeedback(FeedbackType.error);
    }
  }

  /// Gestisce il feedback per il livello del volume
  Future<void> handleVolumeLevel(double level) async {
    if (level > _options.volumeThreshold) {
      await provideFeedback(
        FeedbackType.progress,
        intensity: level.clamp(0.0, 1.0),
      );
    }
  }

  // Metodi per il controllo del servizio
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  void updateOptions(FeedbackOptions newOptions) {
    _options = newOptions;
  }

  // Stream per osservare gli eventi di feedback
  Stream<FeedbackEvent> get feedbackStream => _feedbackController.stream;

  // Getters per lo stato del servizio
  FeedbackOptions get currentOptions => _options;
  bool get isEnabled => _isEnabled;

  // Pulizia delle risorse
  Future<void> dispose() async {
    await _feedbackController.close();
  }
}

/// Classe che rappresenta un evento di feedback
class FeedbackEvent {
  final FeedbackType type;
  final double intensity;
  final DateTime timestamp;

  FeedbackEvent({
    required this.type,
    required this.intensity,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'FeedbackEvent{type: $type, intensity: $intensity, timestamp: $timestamp}';
  }
}

/// Estensione per semplificare l'uso del feedback con i risultati
extension FeedbackExtension on RecognitionResult {
  Future<void> provideFeedback() async {
    final feedbackService = FeedbackService();
    await feedbackService.handleRecognitionResult(this);
  }
}