import 'package:flutter/material.dart';

class Trophy {
  final String id;
  final String title; // Titolo visualizzato accanto al nome del giocatore
  final String name;  // Nome del trofeo nello store
  final String description;
  final int baseCost;
  final IconData icon;
  final Color color;
  final String rarity;
  bool isOwned;
  final int sequenceNumber;

  Trophy({
    required this.id,
    required this.title,
    required this.name,
    required this.description,
    required this.baseCost,
    required this.icon,
    required this.color,
    required this.rarity,
    required this.sequenceNumber,
    this.isOwned = false,
  });

  int get cost => (baseCost * (1 + (2 * sequenceNumber))).round();

  Map<String, dynamic> toJson() => {
    'id': id,
    'isOwned': isOwned,
  };

  factory Trophy.fromJson(Map<String, dynamic> json, Trophy template) {
    return Trophy(
      id: template.id,
      title: template.title,
      name: template.name,
      description: template.description,
      baseCost: template.baseCost,
      icon: template.icon,
      color: template.color,
      rarity: template.rarity,
      sequenceNumber: template.sequenceNumber,
      isOwned: json['isOwned'] ?? false,
    );
  }

  static List<Trophy> defaultTrophies = [
    Trophy(
      id: 'amateur_reader',
      title: 'Lettore Amatore',
      name: 'Trofeo del Lettore Amatore',
      description: 'Il primo passo nel tuo viaggio di lettura',
      baseCost: 500,
      icon: Icons.auto_stories,
      color: Colors.amber,
      rarity: 'Comune',
      sequenceNumber: 1,
    ),
    Trophy(
      id: 'trained_reader',
      title: 'Lettore Allenato',
      name: 'Trofeo del Lettore Allenato',
      description: 'Stai sviluppando le tue abilità di lettura',
      baseCost: 600,
      icon: Icons.menu_book,
      color: Colors.green,
      rarity: 'Comune',
      sequenceNumber: 2,
    ),
    Trophy(
      id: 'beginner_reader',
      title: 'Lettore Principiante',
      name: 'Trofeo del Lettore Principiante',
      description: 'Le tue capacità di lettura stanno crescendo',
      baseCost: 700,
      icon: Icons.book,
      color: Colors.blue,
      rarity: 'Non comune',
      sequenceNumber: 3,
    ),
    Trophy(
      id: 'good_reader',
      title: 'Bravo Lettore',
      name: 'Trofeo del Bravo Lettore',
      description: 'Stai diventando davvero bravo nella lettura',
      baseCost: 800,
      icon: Icons.stars,
      color: Colors.purple,
      rarity: 'Non comune',
      sequenceNumber: 4,
    ),
    Trophy(
      id: 'great_reader',
      title: 'Ottimo Lettore',
      name: 'Trofeo dell\'Ottimo Lettore',
      description: 'Le tue capacità di lettura sono eccellenti',
      baseCost: 900,
      icon: Icons.workspace_premium,
      color: Colors.orange,
      rarity: 'Raro',
      sequenceNumber: 5,
    ),
    Trophy(
      id: 'super_reader',
      title: 'Super Lettore',
      name: 'Trofeo del Super Lettore',
      description: 'Hai raggiunto un livello superiore di lettura',
      baseCost: 1000,
      icon: Icons.psychology,
      color: Colors.red,
      rarity: 'Raro',
      sequenceNumber: 6,
    ),
    Trophy(
      id: 'grand_reader',
      title: 'Gran Lettore',
      name: 'Trofeo del Gran Lettore',
      description: 'Sei diventato un lettore eccezionale',
      baseCost: 1200,
      icon: Icons.grade,
      color: Colors.indigo,
      rarity: 'Epico',
      sequenceNumber: 7,
    ),
    Trophy(
      id: 'master_reader',
      title: 'Lettore Maestro',
      name: 'Trofeo del Lettore Maestro',
      description: 'Hai padroneggiato l\'arte della lettura',
      baseCost: 1500,
      icon: Icons.emoji_events,
      color: Colors.deepPurple,
      rarity: 'Epico',
      sequenceNumber: 8,
    ),
    Trophy(
      id: 'grandmaster_reader',
      title: 'Gran Maestro Lettore',
      name: 'Trofeo del Gran Maestro Lettore',
      description: 'Il più alto riconoscimento per un lettore',
      baseCost: 2000,
      icon: Icons.military_tech,
      color: Colors.teal,
      rarity: 'Leggendario',
      sequenceNumber: 9,
    ),
    Trophy(
      id: 'supreme_grandmaster_reader',
      title: 'Gran Maestro Supremo Della Lettura',
      name: 'Trofeo del Gran Maestro Supremo Della Lettura',
      description: 'La Consacrazione nella Leggenda per un lettore',
      baseCost: 1000000,
      icon: Icons.stars_rounded,
      color: Colors.amber.shade800,
      rarity: 'Leggendario',
      sequenceNumber: 10,
    ),
  ];
}
