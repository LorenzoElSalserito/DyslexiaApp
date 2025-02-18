// lib/models/crystal.dart

/// Rappresenta un cristallo nel gioco, con il suo tipo e valore.
/// I cristalli sono la valuta principale del gioco e vengono guadagnati
/// completando esercizi e sfide.
enum CrystalType { Red, Orange, Yellow, Green, Blue, Purple }

class Crystal {
  final CrystalType type;
  final int value;

  Crystal(this.type, this.value);
}