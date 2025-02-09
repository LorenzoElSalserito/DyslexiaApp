// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/player_manager.dart';
import 'services/challenge_service.dart';
import 'services/learning_analytics_service.dart';
import 'services/content_service.dart';
import 'services/exercise_manager.dart';
import 'services/game_service.dart';
import 'services/store_service.dart';
import 'models/player.dart';
import 'screens/splash_screen.dart';
import 'screens/game_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/profile_selection_screen.dart';
import 'screens/profile_creation_screen.dart';
import 'screens/store_screen.dart';
import 'screens/reading_exercise_screen.dart';
import 'config/theme_config.dart';

/// Punto di ingresso principale dell'applicazione
void main() async {
  // Assicuriamoci che Flutter sia inizializzato correttamente
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializzazione delle SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Configurazione del percorso per la libreria VOSK
  const String voskLibPath = String.fromEnvironment('VOSK_LIB_PATH');
  debugPrint("VOSK_LIB_PATH: $voskLibPath");

  // Avvio dell'applicazione con la gestione dello stato tramite Provider
  runApp(
    MultiProvider(
      providers: [
        // Provider per la gestione dei profili utente
        ChangeNotifierProvider(
          create: (_) => PlayerManager(prefs),
        ),

        // Provider per il giocatore corrente
        ChangeNotifierProvider(
          create: (_) => Player(),
        ),

        // Provider per il servizio dei contenuti
        ChangeNotifierProvider(
          create: (_) => ContentService(),
          lazy: false, // Inizializza immediatamente per caricare i contenuti
        ),

        // Provider per il servizio di analytics
        Provider(
          create: (_) => LearningAnalyticsService(prefs),
        ),

        // Provider per il gestore degli esercizi
        ChangeNotifierProxyProvider2<Player, ContentService, ExerciseManager>(
          create: (context) => ExerciseManager(
            player: context.read<Player>(),
            contentService: context.read<ContentService>(),
            analyticsService: context.read<LearningAnalyticsService>(),
          ),
          update: (context, player, contentService, previous) =>
          previous ?? ExerciseManager(
            player: player,
            contentService: contentService,
            analyticsService: context.read<LearningAnalyticsService>(),
          ),
        ),

        // Provider per il servizio di gioco
        ChangeNotifierProxyProvider3<Player, ContentService, ExerciseManager, GameService>(
          create: (context) => GameService(
            player: context.read<Player>(),
            contentService: context.read<ContentService>(),
            exerciseManager: context.read<ExerciseManager>(),
          ),
          update: (context, player, contentService, exerciseManager, previous) {
            final service = previous ?? GameService(
              player: player,
              contentService: contentService,
              exerciseManager: exerciseManager,
            );

            // Inizializza il servizio se necessario
            if (!service.isInitialized) {
              // Usiamo microtask per evitare problemi durante il build
              Future.microtask(() => service.initialize());
            }

            return service;
          },
        ),

        // Provider per il servizio delle sfide
        ChangeNotifierProxyProvider<Player, ChallengeService>(
          create: (context) => ChallengeService(prefs, context.read<Player>()),
          update: (context, player, previous) =>
          previous ?? ChallengeService(prefs, player),
        ),

        // Provider per il servizio del negozio
        ChangeNotifierProxyProvider<Player, StoreService>(
          create: (context) => StoreService(prefs, context.read<Player>()),
          update: (context, player, previous) =>
          previous ?? StoreService(prefs, player),
        ),
      ],
      child: const OpenDSAApp(),
    ),
  );
}

/// Widget principale dell'applicazione
class OpenDSAApp extends StatelessWidget {
  const OpenDSAApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenDSA: Reading',
      theme: ThemeConfig.lightTheme,
      debugShowCheckedModeBanner: false, // Rimuove il banner di debug
      initialRoute: '/',
      routes: {
        // Rotte principali dell'applicazione
        '/': (context) => const SplashScreenWidget(),
        '/game': (context) => const GameScreen(),
        '/challenges': (context) => const ChallengesScreen(),
        '/store': (context) => const StoreScreen(),
        '/profile_selection': (context) => const ProfileSelectionScreen(),
        '/profile_creation': (context) => const ProfileCreationScreen(),
        '/reading_exercise': (context) => const ReadingExerciseScreen(),
      },
      onUnknownRoute: (settings) {
        // Gestione delle rotte non trovate
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text(
                'Errore',
                style: TextStyle(fontFamily: 'OpenDyslexic'),
              ),
            ),
            body: Center(
              child: Text(
                'Route ${settings.name} non trovata',
                style: const TextStyle(fontFamily: 'OpenDyslexic'),
              ),
            ),
          ),
        );
      },
    );
  }
}