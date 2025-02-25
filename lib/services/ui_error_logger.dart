// lib/services/ui_error_logger.dart

import 'package:flutter/foundation.dart';

/// Servizio per la registrazione e gestione dei log dell'interfaccia utente.
/// Implementa il pattern Singleton per garantire una singola istanza del servizio.
class UIErrorLogger {
  // Implementazione Singleton
  static final UIErrorLogger _instance = UIErrorLogger._internal();
  factory UIErrorLogger() => _instance;

  // Store dei log
  final List<LogEntry> _logs = [];

  // Livelli di log
  static const int _kMaxLogs = 1000;

  UIErrorLogger._internal();

  /// Registra un'informazione
  void logInfo(String message) {
    _addLog(LogLevel.info, message);
    debugPrint('🟢 INFO: $message');
  }

  /// Registra un avviso
  void logWarning(String message) {
    _addLog(LogLevel.warning, message);
    debugPrint('🟠 WARNING: $message');
  }

  /// Registra un errore
  void logError(String message, dynamic error, [StackTrace? stackTrace]) {
    _addLog(LogLevel.error, message, error, stackTrace);
    debugPrint('🔴 ERROR: $message - $error');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }

  /// Registra un debug
  void logDebug(String message) {
    _addLog(LogLevel.debug, message);
    if (kDebugMode) {
      debugPrint('🔵 DEBUG: $message');
    }
  }

  /// Aggiunge un log alla lista
  void _addLog(LogLevel level, String message, [dynamic error, StackTrace? stackTrace]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.add(entry);

    // Mantiene la dimensione massima dei log
    if (_logs.length > _kMaxLogs) {
      _logs.removeAt(0);
    }
  }

  /// Ottiene la lista dei log
  List<LogEntry> getLogs() => List.unmodifiable(_logs);

  /// Ottiene i log filtrati per livello
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// Pulisce tutti i log
  void clearLogs() {
    _logs.clear();
    logInfo('Log cancellati');
  }
}

/// Livelli di log
enum LogLevel {
  debug,   // Informazioni di debug (solo in modalità debug)
  info,    // Informazioni generali
  warning, // Avvisi
  error,   // Errori
}

/// Rappresenta una voce di log
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    String result = '[$timestamp] ${level.toString().split('.').last.toUpperCase()}: $message';
    if (error != null) {
      result += '\nError: $error';
    }
    if (stackTrace != null) {
      result += '\nStackTrace: $stackTrace';
    }
    return result;
  }
}