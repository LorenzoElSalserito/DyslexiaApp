// lib/models/crystal.dart
enum CrystalType { Red, Orange, Yellow, White, Blue }

class Crystal {
  final CrystalType type;
  final int value;

  Crystal(this.type, this.value);
}