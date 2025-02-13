// lib/models/crystal.dart
enum CrystalType { Red, Orange, Yellow, Green, Blue, Purple }

class Crystal {
  final CrystalType type;
  final int value;

  Crystal(this.type, this.value);
}