import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_menu_screen.dart';
import 'models/player.dart';
import 'services/content_service.dart';
import 'services/game_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final contentService = ContentService();
  await contentService.initialize();

  runApp(MyApp(contentService: contentService));
}

class MyApp extends StatelessWidget {
  final ContentService contentService;

  MyApp({required this.contentService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Player()),
        ProxyProvider<Player, GameService>(
          update: (_, player, __) => GameService(player: player, contentService: contentService),
        ),
      ],
      child: MaterialApp(
        title: 'Dislessia App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: MainMenuScreen(),  // Impostato come schermata iniziale
      ),
    );
  }
}