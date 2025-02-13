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

/// Punto di ingresso principale dell'applicazione.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializzazione delle SharedPreferences.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        // Provider per la gestione dei profili utente.
        ChangeNotifierProvider<PlayerManager>(
          create: (_) => PlayerManager(prefs),
        ),
        // Provider per il servizio dei contenuti.
        ChangeNotifierProvider<ContentService>(
          create: (_) => ContentService(),
          lazy: false, // Inizializza subito per caricare i contenuti.
        ),
        // Provider per il servizio di analytics.
        Provider<LearningAnalyticsService>(
          create: (_) => LearningAnalyticsService(prefs),
        ),
        // Provider per il gestore degli esercizi: ora si basa sul PlayerManager.
        ChangeNotifierProxyProvider2<PlayerManager, ContentService, ExerciseManager>(
          create: (context) {
            final pm = context.read<PlayerManager>();
            // Se non c'è ancora un profilo attivo, creiamo un dummy (ma in seguito verrà aggiornato)
            return ExerciseManager(
              player: pm.currentProfile ?? Player(),
              contentService: context.read<ContentService>(),
              analyticsService: context.read<LearningAnalyticsService>(),
            );
          },
          update: (context, playerManager, contentService, previous) {
            final current = playerManager.currentProfile;
            if (current != null) {
              previous!.updatePlayer(current);
            }
            return previous!;
          },
        ),
        // Provider per il servizio di gioco: ora si basa sul PlayerManager.
        ChangeNotifierProxyProvider3<PlayerManager, ContentService, ExerciseManager, GameService>(
          create: (context) {
            final pm = context.read<PlayerManager>();
            return GameService(
              player: pm.currentProfile ?? Player(),
              contentService: context.read<ContentService>(),
              exerciseManager: context.read<ExerciseManager>(),
            );
          },
          update: (context, playerManager, contentService, exerciseManager, previous) {
            final current = playerManager.currentProfile;
            if (current != null) {
              previous!.updatePlayer(current);
            }
            if (!previous!.isInitialized) {
              // Avvia l'inizializzazione in una microtask per evitare conflitti durante il build.
              Future.microtask(() => previous.initialize());
            }
            return previous;
          },
        ),
        // Provider per il servizio delle sfide.
        ChangeNotifierProxyProvider<PlayerManager, ChallengeService>(
          create: (context) => ChallengeService(
            prefs,
            context.read<PlayerManager>().currentProfile ?? Player(),
          ),
          update: (context, playerManager, previous) =>
          previous ?? ChallengeService(prefs, playerManager.currentProfile ?? Player()),
        ),
        // Provider per il servizio del negozio.
        ChangeNotifierProxyProvider<PlayerManager, StoreService>(
          create: (context) => StoreService(
            prefs,
            context.read<PlayerManager>().currentProfile ?? Player(),
          ),
          update: (context, playerManager, previous) =>
          previous ?? StoreService(prefs, playerManager.currentProfile ?? Player()),
        ),
      ],
      child: const OpenDSAApp(),
    ),
  );
}

/// Widget principale dell'applicazione.
class OpenDSAApp extends StatelessWidget {
  const OpenDSAApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenDSA: Reading',
      theme: ThemeConfig.lightTheme,
      debugShowCheckedModeBanner: false, // Rimuove il banner di debug.
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreenWidget(),
        '/game': (context) => const GameScreen(),
        '/challenges': (context) => ChallengesScreen(), // Non usiamo "const" per forzare l'aggiornamento
        '/store': (context) => const StoreScreen(),
        '/profile_selection': (context) => const ProfileSelectionScreen(),
        '/profile_creation': (context) => const ProfileCreationScreen(),
        '/reading_exercise': (context) => const ReadingExerciseScreen(),
      },
      onUnknownRoute: (settings) {
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
