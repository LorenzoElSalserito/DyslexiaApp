import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

// Servizi
import 'services/vosk_service.dart';
import 'services/audio_service.dart';
import 'services/game_service.dart';
import 'services/content_service.dart';
import 'services/speech_recognition_service.dart';
import 'services/learning_analytics_service.dart';
import 'services/training_session_service.dart';
import 'services/feedback_service.dart';
import 'services/model_cache_service.dart';
import 'services/recognition_manager.dart';
import 'services/exercise_manager.dart';
import 'services/achievement_manager.dart';
import 'services/challenge_service.dart';

// Models
import 'models/player.dart';

// Config
import 'config/app_config.dart';
import 'config/theme_config.dart';

// Screens
import 'screens/main_menu_screen.dart';
import 'screens/game_screen.dart';
import 'screens/reading_exercise_screen.dart';
import 'screens/profile_creation_screen.dart';
import 'screens/options_screen.dart';
import 'screens/challenges_screen.dart';

// Widgets
import 'widgets/game_notification_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Forza l'orientamento verticale
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inizializza SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Inizializza i servizi core
  final modelCacheService = ModelCacheService.instance;
  await modelCacheService.initialize();

  final contentService = ContentService();
  await contentService.initialize();

  // Inizializza il feedback service con le opzioni di default
  final feedbackService = FeedbackService();
  feedbackService.initialize(FeedbackOptions(
    useVibration: AppConfig.defaultVibrationEnabled,
    useSound: AppConfig.defaultSoundEnabled,
    useVisual: AppConfig.defaultVisualEnabled,
  ));

  runApp(MyApp(
    prefs: prefs,
    contentService: contentService,
  ));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final ContentService contentService;

  const MyApp({
    Key? key,
    required this.prefs,
    required this.contentService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Player Provider
        ChangeNotifierProvider(
          create: (context) => Player(),
        ),

        // Learning Analytics Provider
        Provider(
          create: (context) => LearningAnalyticsService(prefs),
        ),

        // Exercise Manager Provider
        Provider(
          create: (context) => ExerciseManager(
            player: context.read<Player>(),
            contentService: contentService,
            analyticsService: context.read<LearningAnalyticsService>(),
          ),
        ),

        // Achievement Manager Provider
        Provider(
          create: (context) => AchievementManager(
            player: context.read<Player>(),
            analytics: context.read<LearningAnalyticsService>(),
          ),
        ),

        // Challenge Service Provider
        ChangeNotifierProvider(
          create: (context) => ChallengeService(
            prefs,
            context.read<Player>(),
          ),
        ),

        // Game Service Provider
        Provider(
          create: (context) => GameService(
            player: context.read<Player>(),
            contentService: contentService,
            exerciseManager: context.read<ExerciseManager>(),
          ),
        ),

        // Recognition Manager Provider
        ChangeNotifierProvider(
          create: (context) => RecognitionManager(
            speechService: SpeechRecognitionService(),
          ),
        ),

        // Training Session Provider
        Provider(
          create: (context) => TrainingSessionService(
            prefs: prefs,
            analyticsService: context.read<LearningAnalyticsService>(),
            recognitionManager: context.read<RecognitionManager>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        theme: ThemeConfig.lightTheme,
        builder: (context, child) => GameNotificationWrapper(
          child: child ?? Container(),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => MainMenuScreen(),
          '/game': (context) => GameScreen(),
          '/reading_exercise': (context) => ReadingExerciseScreen(),
          '/profile_creation': (context) => ProfileCreationScreen(),
          '/options': (context) => OptionsScreen(),
          '/challenges': (context) => ChallengesScreen(),
        },
      ),
    );
  }

  // ErrorWidget personalizzato per il debug
  static Widget errorScreen(FlutterErrorDetails errorDetails) {
    return Material(
      child: Container(
        padding: EdgeInsets.all(16),
        color: Colors.red[100],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 16),
            Text(
              'Si è verificato un errore',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (AppConfig.appVersion.endsWith('dev'))
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  errorDetails.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}