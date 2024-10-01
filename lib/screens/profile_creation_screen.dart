import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import 'game_screen.dart';

class ProfileCreationScreen extends StatefulWidget {
  @override
  _ProfileCreationScreenState createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _matricolaController = TextEditingController();
  final _corsoController = TextEditingController();

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final player = Provider.of<Player>(context, listen: false);
      await player.setPlayerInfo(
          _nameController.text,
          _surnameController.text,
          _matricolaController.text,
          _corsoController.text
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GameScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Crea Profilo')),
      body: Center(
        child: Container(
          width: 300,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 5,
                blurRadius: 7,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Nome'),
                  validator: (value) => value!.isEmpty ? 'Inserisci il tuo nome' : null,
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: _surnameController,
                  decoration: InputDecoration(labelText: 'Cognome'),
                  validator: (value) => value!.isEmpty ? 'Inserisci il tuo cognome' : null,
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: _matricolaController,
                  decoration: InputDecoration(labelText: 'Matricola'),
                  validator: (value) => value!.isEmpty ? 'Inserisci la tua matricola' : null,
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: _corsoController,
                  decoration: InputDecoration(labelText: 'Corso di Laurea'),
                  validator: (value) => value!.isEmpty ? 'Inserisci il tuo corso di laurea' : null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _saveProfile(),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  child: Text('Salva Profilo'),
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}