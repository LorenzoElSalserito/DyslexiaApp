import 'package:flutter/material.dart';
import '../services/game_service.dart';

class ProgressionMap extends StatelessWidget {
  final int currentLevel;
  final int currentStep;

  ProgressionMap({required this.currentLevel, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Livello $currentLevel',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        SizedBox(height: 10),
        Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: currentStep / GameService.levelTargets[currentLevel]!,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Step $currentStep / ${GameService.levelTargets[currentLevel]}',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}