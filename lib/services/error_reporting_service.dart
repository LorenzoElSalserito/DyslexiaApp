// lib/services/error_reporting_service.dart

import 'package:flutter/foundation.dart';

class ErrorReportingService {
  static void reportError(dynamic error, StackTrace? stackTrace) {
    // In un'applicazione reale, qui invieresti l'errore a un servizio di monitoraggio
    // come Sentry, Firebase Crashlytics, o un tuo server personalizzato.

    // Per ora, stampiamo semplicemente l'errore sulla console
    print('Errore catturato:');
    print('Errore: $error');
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
    }

    // Puoi aggiungere qui altra logica, come salvare l'errore localmente
    // o mostrare un messaggio all'utente
  }
}