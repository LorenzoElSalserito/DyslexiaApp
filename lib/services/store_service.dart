import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/trophy.dart';
import '../models/player.dart';

class StoreService extends ChangeNotifier {
  static const String _ownedTrophiesKey = 'owned_trophies';

  final SharedPreferences _prefs;
  final Player _player;
  List<Trophy> _availableTrophies = [];
  List<Trophy> _ownedTrophies = [];

  StoreService(this._prefs, this._player) {
    _initializeStore();
  }

  List<Trophy> get availableTrophies => List.unmodifiable(_availableTrophies);
  List<Trophy> get ownedTrophies => List.unmodifiable(_ownedTrophies);

  String? get currentTitle {
    final ownedAndSorted = _ownedTrophies..sort((a, b) => b.sequenceNumber.compareTo(a.sequenceNumber));
    return ownedAndSorted.isNotEmpty ? ownedAndSorted.first.title : null;
  }

  void _initializeStore() {
    _availableTrophies = Trophy.defaultTrophies;
    final savedTrophies = _prefs.getStringList(_ownedTrophiesKey) ?? [];
    for (var trophyId in savedTrophies) {
      final trophy = _availableTrophies.firstWhere(
            (t) => t.id == trophyId,
        orElse: () => throw Exception('Trophy not found: $trophyId'),
      );
      trophy.isOwned = true;
      _ownedTrophies.add(trophy);
    }
    notifyListeners();
  }

  bool canPurchaseTrophy(Trophy trophy) {
    if (trophy.isOwned) return false;
    for (var t in _availableTrophies) {
      if (t.sequenceNumber < trophy.sequenceNumber && !t.isOwned) {
        return false;
      }
    }
    return _player.totalCrystals >= trophy.cost;
  }

  Future<bool> purchaseTrophy(Trophy trophy) async {
    if (!canPurchaseTrophy(trophy)) return false;
    try {
      _player.addCrystals(-trophy.cost);
      trophy.isOwned = true;
      _ownedTrophies.add(trophy);
      await _saveTrophies();
      notifyListeners();
      return true;
    } catch (e) {
      print('Errore nell\'acquisto del trofeo: $e');
      return false;
    }
  }

  Future<void> _saveTrophies() async {
    final trophyIds = _ownedTrophies.map((t) => t.id).toList();
    await _prefs.setStringList(_ownedTrophiesKey, trophyIds);
  }

  Trophy? getTrophyById(String id) {
    try {
      return _availableTrophies.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Trophy> getTrophiesByRarity(String rarity) {
    return _availableTrophies.where((t) => t.rarity == rarity).toList();
  }

  Future<void> resetStore() async {
    _ownedTrophies.clear();
    for (var trophy in _availableTrophies) {
      trophy.isOwned = false;
    }
    await _prefs.remove(_ownedTrophiesKey);
    notifyListeners();
  }
}
