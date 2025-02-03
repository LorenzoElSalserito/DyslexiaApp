// lib/screens/options_screen.dart

import 'package:flutter/material.dart';

class OptionsScreen extends StatefulWidget {
  // Aggiungiamo il costruttore const
  const OptionsScreen({Key? key}) : super(key: key);

  @override
  _OptionsScreenState createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  String _selectedFont = 'OpenDyslexic';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.lightBlue.shade800, Colors.lightBlue.shade500],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildOptions()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Opzioni',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOptionSection(
            'Aspetto',
            [
              _buildFontOption(),
            ],
          ),
          const SizedBox(height: 24),
          _buildOptionSection(
            'Audio',
            [
              _buildSwitchOption(
                'Effetti Sonori',
                true,
                    (value) {
                  // TODO: Implementare la gestione degli effetti sonori
                },
              ),
              _buildSwitchOption(
                'Feedback Vocale',
                false,
                    (value) {
                  // TODO: Implementare la gestione del feedback vocale
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionSection(String title, List<Widget> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: options,
          ),
        ),
      ],
    );
  }

  Widget _buildFontOption() {
    return ListTile(
      title: const Text(
        'Font',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'OpenDyslexic',
        ),
      ),
      trailing: DropdownButton<String>(
        value: _selectedFont,
        dropdownColor: Colors.lightBlue.shade800,
        items: const [
          DropdownMenuItem(
            value: 'OpenDyslexic',
            child: Text(
              'OpenDyslexic',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedFont = value;
            });
          }
        },
      ),
    );
  }

  Widget _buildSwitchOption(
      String title,
      bool initialValue,
      ValueChanged<bool> onChanged,
      ) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'OpenDyslexic',
        ),
      ),
      trailing: Switch(
        value: initialValue,
        onChanged: onChanged,
      ),
    );
  }
}