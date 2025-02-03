import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

class ErrorReportingService {
  // Singleton pattern per garantire una singola istanza del servizio
  static final ErrorReportingService _instance = ErrorReportingService._internal();
  factory ErrorReportingService() => _instance;

  // Directory per il salvataggio dei log
  late final Directory _logDirectory;
  // File per il log corrente
  late final File _currentLogFile;

  // Controller per lo stream degli errori
  final _errorController = StreamController<ErrorReport>.broadcast();

  // Limite di errori da mantenere in memoria
  static const int _maxStoredErrors = 100;
  // Lista degli errori recenti
  final List<ErrorReport> _recentErrors = [];

  // Costruttore privato per il singleton
  ErrorReportingService._internal() {
    _initializeService();
  }

  // Inizializzazione asincrona del servizio
  Future<void> _initializeService() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _logDirectory = Directory('${appDir.path}/logs');

      if (!await _logDirectory.exists()) {
        await _logDirectory.create(recursive: true);
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      _currentLogFile = File('${_logDirectory.path}/log_$today.txt');
    } catch (e) {
      print('Errore nell\'inizializzazione del servizio di reporting: $e');
    }
  }

  // Metodo principale per la segnalazione degli errori
  Future<void> reportError(
      dynamic error,
      StackTrace? stackTrace, {
        String? context,
        Map<String, dynamic>? additionalData,
      }) async {
    final errorReport = ErrorReport(
      error: error.toString(),
      stackTrace: stackTrace?.toString(),
      timestamp: DateTime.now(),
      context: context,
      additionalData: additionalData,
    );

    try {
      // Salva l'errore nel log
      await _logError(errorReport);

      // Aggiungi alla lista degli errori recenti
      _addToRecentErrors(errorReport);

      // Notifica gli ascoltatori
      _errorController.add(errorReport);

      // In modalità debug, stampa l'errore sulla console
      if (kDebugMode) {
        print('Errore registrato:');
        print(errorReport.toString());
      }
    } catch (e) {
      // Gestione fallback in caso di errore nel reporting
      print('Errore critico nel sistema di reporting: $e');
    }
  }

  // Salva l'errore nel file di log
  Future<void> _logError(ErrorReport report) async {
    try {
      final logEntry = '${report.toJson()}\n';
      await _currentLogFile.writeAsString(
        logEntry,
        mode: FileMode.append,
      );
    } catch (e) {
      print('Errore nella scrittura del log: $e');
    }
  }

  // Aggiunge un errore alla lista degli errori recenti
  void _addToRecentErrors(ErrorReport error) {
    _recentErrors.add(error);
    if (_recentErrors.length > _maxStoredErrors) {
      _recentErrors.removeAt(0);
    }
  }

  // Stream pubblico per gli errori
  Stream<ErrorReport> get errorStream => _errorController.stream;

  // Lista degli errori recenti
  List<ErrorReport> get recentErrors => List.unmodifiable(_recentErrors);

  // Ottiene tutti i log del giorno specificato
  Future<List<ErrorReport>> getLogsForDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final logFile = File('${_logDirectory.path}/log_$dateStr.txt');

      if (!await logFile.exists()) {
        return [];
      }

      final content = await logFile.readAsString();
      return content
          .split('\n')
          .where((line) => line.isNotEmpty)
          .map((line) => ErrorReport.fromJson(json.decode(line)))
          .toList();
    } catch (e) {
      print('Errore nel recupero dei log: $e');
      return [];
    }
  }

  // Pulisce i log più vecchi di un certo numero di giorni
  Future<void> cleanOldLogs({int daysToKeep = 30}) async {
    try {
      final files = await _logDirectory.list().toList();
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      for (var file in files) {
        if (file is File && file.path.contains('log_')) {
          final dateStr = file.path.split('log_')[1].split('.txt')[0];
          final fileDate = DateTime.parse(dateStr);

          if (fileDate.isBefore(cutoffDate)) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Errore nella pulizia dei log: $e');
    }
  }

  // Rilascia le risorse quando non più necessarie
  Future<void> dispose() async {
    await _errorController.close();
  }
}

// Classe che rappresenta un report di errore
class ErrorReport {
  final String error;
  final String? stackTrace;
  final DateTime timestamp;
  final String? context;
  final Map<String, dynamic>? additionalData;

  ErrorReport({
    required this.error,
    this.stackTrace,
    required this.timestamp,
    this.context,
    this.additionalData,
  });

  // Converte il report in JSON per il salvataggio
  Map<String, dynamic> toJson() => {
    'error': error,
    'stackTrace': stackTrace,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
    'additionalData': additionalData,
  };

  // Crea un report da JSON
  factory ErrorReport.fromJson(Map<String, dynamic> json) {
    return ErrorReport(
      error: json['error'] as String,
      stackTrace: json['stackTrace'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      context: json['context'] as String?,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return '''
Error Report:
  Timestamp: $timestamp
  Error: $error
  Context: ${context ?? 'N/A'}
  Stack Trace: ${stackTrace ?? 'N/A'}
  Additional Data: ${additionalData ?? 'N/A'}
''';
  }
}