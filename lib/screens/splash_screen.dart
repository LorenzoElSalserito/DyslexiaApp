// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/content_service.dart';
import '../services/player_manager.dart';
import 'profile_selection_screen.dart';
import '../services/ui_error_logger.dart';

class SplashScreenWidget extends StatefulWidget {
  const SplashScreenWidget({Key? key}) : super(key: key);

  @override
  _SplashScreenWidgetState createState() => _SplashScreenWidgetState();
}

class _SplashScreenWidgetState extends State<SplashScreenWidget> {
  bool _isLoading = true;
  String _loadingText = 'Inizializzazione...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;
    final logger = UIErrorLogger();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loadingText = 'Inizializzazione...';
    });

    try {
      logger.logInfo('[SplashScreen] Inizio inizializzazione applicazione');

      final contentService = Provider.of<ContentService>(context, listen: false);
      final playerManager = Provider.of<PlayerManager>(context, listen: false);

      // Fase 1: Inizializzazione dei contenuti del gioco
      setState(() => _loadingText = 'Caricamento contenuti...');
      logger.logInfo('[SplashScreen] Inizio caricamento contenuti');
      await contentService.initialize();
      logger.logInfo('[SplashScreen] Contenuti caricati con successo');

      // Fase 2: Inizializzazione del sistema di gestione dei profili
      setState(() => _loadingText = 'Caricamento profili...');
      logger.logInfo('[SplashScreen] Inizio caricamento profili');
      await playerManager.initialize();
      logger.logInfo('[SplashScreen] Profili caricati con successo');

      // Piccola pausa per mostrare l'ultima animazione di caricamento
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      logger.logInfo('[SplashScreen] Inizializzazione completata, navigazione alla schermata di selezione profilo');

      // Naviga alla schermata di selezione profilo
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ProfileSelectionScreen(),
        ),
      );
    } catch (e, stackTrace) {
      if (!mounted) return;
      logger.logError('[SplashScreen] Errore durante l\'inizializzazione', e, stackTrace);

      setState(() {
        _isLoading = false;
        _errorMessage = 'Si è verificato un errore durante il caricamento: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Sfondo a gradiente
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade900, Colors.blue.shade800],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Riquadro quadrato con bordi arrotondati contenente il titolo
                          Center(
                            child: Container(
                              width: 550,
                              height: 250,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'OpenDSA: Reading App',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: AppConfig.title,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'OpenDyslexic',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_isLoading) ...[
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _loadingText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: AppConfig.subtitle,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ] else if (_errorMessage != null) ...[
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red[300],
                                fontSize: 16,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                            const SizedBox(height: AppConfig.subtitle),
                            ElevatedButton(
                              onPressed: _initializeApp,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.blue[900],
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'Riprova',
                                style: TextStyle(
                                  fontSize: AppConfig.subtitle,
                                  fontFamily: 'OpenDyslexic',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
