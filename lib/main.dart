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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PlayerManager(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => Player(),
        ),
        ChangeNotifierProvider(
          create: (_) => ContentService(),
        ),
        Provider(
          create: (_) => LearningAnalyticsService(prefs),
        ),
        ChangeNotifierProxyProvider2<Player, ContentService, ExerciseManager>(
          create: (context) => ExerciseManager(
            player: context.read<Player>(),
            contentService: context.read<ContentService>(),
            analyticsService: context.read<LearningAnalyticsService>(),
          ),
          update: (context, player, contentService, previous) =>
              ExerciseManager(
                player: player,
                contentService: contentService,
                analyticsService: context.read<LearningAnalyticsService>(),
              ),
        ),
        ChangeNotifierProxyProvider<Player, GameService>(
          create: (context) => GameService(
            player: context.read<Player>(),
            contentService: context.read<ContentService>(),
            exerciseManager: context.read<ExerciseManager>(),
          ),
          update: (context, player, previous) =>
              GameService(
                player: player,
                contentService: context.read<ContentService>(),
                exerciseManager: context.read<ExerciseManager>(),
              ),
        ),
        ChangeNotifierProxyProvider<Player, ChallengeService>(
          create: (context) => ChallengeService(prefs, context.read<Player>()),
          update: (context, player, previous) =>
              ChallengeService(prefs, player),
        ),
        ChangeNotifierProxyProvider<Player, StoreService>(
          create: (context) => StoreService(prefs, context.read<Player>()),
          update: (context, player, previous) =>
              StoreService(prefs, player),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dyslexia App',
      theme: ThemeConfig.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreenWidget(),
        '/game': (context) => GameScreen(),
        '/challenges': (context) => ChallengesScreen(),
        //'/options': (context) => OptionsScreen(),
        '/store': (context) => StoreScreen(),
        '/profile_selection': (context) => const ProfileSelectionScreen(),
        '/profile_creation': (context) => ProfileCreationScreen(),
        '/reading_exercise': (context) => ReadingExerciseScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Errore')),
            body: Center(
              child: Text('Route ${settings.name} non trovata'),
            ),
          ),
        );
      },
    );
  }
}