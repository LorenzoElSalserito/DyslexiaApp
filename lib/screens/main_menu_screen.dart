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
            colors: [Colors.blue[800]!, Colors.grey[400]!],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Dislessia App',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 50),
              ElevatedButton(
                child: Text('Nuovo Gioco'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: Size(200, 50),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileCreationScreen()));
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('Continua'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasSavedGame ? Colors.white : Colors.grey,
                  foregroundColor: Colors.black,
                  minimumSize: Size(200, 50),
                ),
                onPressed: _hasSavedGame ? _continueSavedGame : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('Opzioni'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: Size(200, 50),
                ),
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
}