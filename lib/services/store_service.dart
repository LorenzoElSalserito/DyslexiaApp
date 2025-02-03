// lib/services/store_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/trophy.dart';
import '../models/player.dart';

/// Servizio che gestisce lo store dei trofei
class StoreService extends ChangeNotifier {
  static const String _ownedTrophiesKey = 'owned_trophies';

  final SharedPreferences _prefs;
  final Player _player;
  List<Trophy> _availableTrophies = [];
  List<Trophy> _ownedTrophies = [];

  StoreService(this._prefs, this._player) {
    _initializeStore();
  }

  // Getters pubblici
  List<Trophy> get availableTrophies => List.unmodifiable(_availableTrophies);
  List<Trophy> get ownedTrophies => List.unmodifiable(_ownedTrophies);

  // Ottiene il titolo attualmente attivo del giocatore
  String? get currentTitle {
    // Restituisce il titolo del trofeo più recente posseduto
    final ownedAndSorted = _ownedTrophies
      ..sort((a, b) => b.sequenceNumber.compareTo(a.sequenceNumber));
    return ownedAndSorted.isNotEmpty ? ownedAndSorted.first.title : null;
  }

  // Inizializza lo store caricando i trofei salvati
  void _initializeStore() {
    // Carica tutti i trofei predefiniti
    _availableTrophies = Trophy.defaultTrophies;

    // Carica i trofei posseduti dal salvataggio
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

  // Verifica se un trofeo può essere acquistato
  bool canPurchaseTrophy(Trophy trophy) {
    if (trophy.isOwned) return false;

    // Verifica che non ci siano trofei di livello inferiore non posseduti
    for (var t in _availableTrophies) {
      if (t.sequenceNumber < trophy.sequenceNumber && !t.isOwned) {
        return false;
      }
    }

    return _player.totalCrystals >= trophy.cost;
  }

  // Acquista un trofeo
  Future<bool> purchaseTrophy(Trophy trophy) async {
    if (!canPurchaseTrophy(trophy)) return false;

    try {
      // Sottrai i cristalli
      _player.addCrystals(-trophy.cost);

      // Aggiorna lo stato del trofeo
      trophy.isOwned = true;
      _ownedTrophies.add(trophy);

      // Salva lo stato
      await _saveTrophies();

      notifyListeners();
      return true;
    } catch (e) {
      print('Errore nell\'acquisto del trofeo: $e');
      return false;
    }
  }

  // Salva i trofei posseduti
  Future<void> _saveTrophies() async {
    final trophyIds = _ownedTrophies.map((t) => t.id).toList();
    await _prefs.setStringList(_ownedTrophiesKey, trophyIds);
  }

  // Ottiene un trofeo per ID
  Trophy? getTrophyById(String id) {
    try {
      return _availableTrophies.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  // Filtra i trofei per rarità
  List<Trophy> getTrophiesByRarity(String rarity) {
    return _availableTrophies.where((t) => t.rarity == rarity).toList();
  }

  // Resetta lo store (principalmente per debug)
  Future<void> resetStore() async {
    _ownedTrophies.clear();
    for (var trophy in _availableTrophies) {
      trophy.isOwned = false;
    }
    await _prefs.remove(_ownedTrophiesKey);
    notifyListeners();
  }
}