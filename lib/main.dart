import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/main_menu_screen.dart';
import 'screens/game_screen.dart';
import 'screens/profile_creation_screen.dart';
import 'screens/options_screen.dart';
import 'screens/reading_exercise_screen.dart';
import 'models/player.dart';
import 'services/content_service.dart';
import 'services/game_service.dart';
import 'services/error_reporting_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ErrorReportingService.reportError(details.exception, details.stack);
  };

  final contentService = ContentService();
  await contentService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Player()),
        ProxyProvider<Player, GameService>(
          update: (_, player, __) => GameService(player: player, contentService: contentService),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dislessia App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: TextTheme(
          bodyLarge: TextStyle(fontSize: 18.0, fontFamily: 'OpenDyslexic'),
          bodyMedium: TextStyle(fontSize: 16.0, fontFamily: 'OpenDyslexic'),
        ),
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('it', ''),
        const Locale('en', ''),
      ],
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => MainMenuScreen(),
        '/game': (context) => GameScreen(),
        '/profile': (context) => ProfileCreationScreen(),
        '/options': (context) => OptionsScreen(),
        '/reading_exercise': (context) => ReadingExerciseScreen(),
      },
    );
  }
}