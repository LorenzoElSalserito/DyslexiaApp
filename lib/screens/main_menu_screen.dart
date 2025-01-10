// main_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import 'game_screen.dart';
import 'profile_creation_screen.dart';
import 'options_screen.dart';

class MainMenuScreen extends StatefulWidget {
  @override
  _MainMenuScreenState createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _hasSavedGame = false;

  @override
  void initState() {
    super.initState();
    _checkSavedGame();
  }

  void _checkSavedGame() async {
    final player = Provider.of<Player>(context, listen: false);
    final hasProfile = await player.hasProfile();
    setState(() {
      _hasSavedGame = hasProfile;
    });
  }

  void _continueSavedGame() async {
    final player = Provider.of<Player>(context, listen: false);
    await player.loadProgress();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.lightBlue.shade200, Colors.lightBlue.shade100],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Dyslexia App',
                style: TextStyle(
                  fontFamily: 'OpenDyslexic',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 50),
              _buildMenuButton(
                icon: Icons.play_arrow,
                label: 'Nuovo Gioco',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileCreationScreen()));
                },
              ),
              SizedBox(height: 20),
              _buildMenuButton(
                icon: Icons.refresh,
                label: 'Continua',
                onPressed: _hasSavedGame ? _continueSavedGame : null,
                color: _hasSavedGame ? Colors.white : Colors.grey,
              ),
              SizedBox(height: 20),
              _buildMenuButton(
                icon: Icons.emoji_events,
                label: 'Sfide',
                onPressed: () {
                  Navigator.pushNamed(context, '/challenges');
                },
              ),
              SizedBox(height: 20),
              _buildMenuButton(
                icon: Icons.settings,
                label: 'Opzioni',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => OptionsScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return SizedBox(
      width: 200,
      height: 50,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            fontSize: 18,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 5,
        ),
        onPressed: onPressed,
      ),
    );
  }
}