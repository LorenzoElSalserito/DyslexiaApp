// lib/models/enums.dart

/// Livelli di difficoltà del gioco
enum Difficulty {
  easy,
  medium,
  hard,
}

/// Tipi di sfide disponibili
enum ChallengeType {
  daily,
  weekly,
  special,
}

/// Stato delle sfide
enum ChallengeStatus {
  notStarted,
  inProgress,
  completed,
  failed,
}

/// Tipi di esercizi
enum ExerciseType {
  word,
  sentence,
  paragraph,
  page,
}

/// Stati dell'audio
enum AudioState {
  stopped,
  recording,
  paused,
}

/// Tipi di feedback
enum FeedbackType {
  success,
  error,
  warning,
  progress,
}