import 'package:flutter/material.dart';


class OptionsScreen extends StatefulWidget {
  @override
  _OptionsScreenState createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  String selectedFont = 'Lexend';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Opzioni')),
      body: Center(
        child: ListTile(
          title: Text('Font'),
          trailing: DropdownButton<String>(
            value: selectedFont,
            items: ['Lexend', 'OpenDyslexic'].map((font) {
              return DropdownMenuItem(
                value: font,
                child: Text(font),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedFont = value!;
              });
            },
          ),
        ),
      ),
    );
  }
}