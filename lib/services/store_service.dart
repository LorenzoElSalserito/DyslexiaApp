import 'package:flutter/foundation.dart';
import '../models/trophy.dart';
import '../models/player.dart';

class StoreService extends ChangeNotifier {
  Player _player;
  List<Trophy> _availableTrophies = [];

  StoreService(this._player) {
    _initializeStore();
  }

  List<Trophy> get availableTrophies => List.unmodifiable(_availableTrophies);
  List<Trophy> get ownedTrophies => _availableTrophies.where((t) => t.isOwned).toList();

  String? get currentTitle {
    final ownedAndSorted = List<Trophy>.from(ownedTrophies)
      ..sort((a, b) => b.sequenceNumber.compareTo(a.sequenceNumber));
    return ownedAndSorted.isNotEmpty ? ownedAndSorted.first.title : null;
  }

  void _initializeStore() {
    debugPrint('StoreService: Inizializzazione store per il profilo ${_player.id}');

    if (_player.id.isEmpty) {
      debugPrint('StoreService: ID profilo vuoto, impossibile inizializzare');
      return;
    }

    // Crea una copia fresca dei trofei di default
    _availableTrophies = Trophy.defaultTrophies.map((t) => Trophy(
      id: t.id,
      title: t.title,
      name: t.name,
      description: t.description,
      baseCost: t.baseCost,
      icon: t.icon,
      color: t.color,
      rarity: t.rarity,
      sequenceNumber: t.sequenceNumber,
    )).toList();

    // Carica lo stato dei trofei dal player
    _loadTrophiesFromPlayer();

    notifyListeners();
  }

  /// Carica i trofei posseduti dal player
  void _loadTrophiesFromPlayer() {
    // Reset per sicurezza
    for (var trophy in _availableTrophies) {
      trophy.isOwned = false;
    }

    // Carica i trofei posseduti direttamente dalla lista di trofei del player
    final ownedTrophyIds = _player.ownedTrophies;
    debugPrint('StoreService: Caricamento di ${ownedTrophyIds.length} trofei per il profilo ${_player.id}: $ownedTrophyIds');

    for (var trophyId in ownedTrophyIds) {
      final trophyIndex = _availableTrophies.indexWhere((t) => t.id == trophyId);
      if (trophyIndex != -1) {
        _availableTrophies[trophyIndex].isOwned = true;
        debugPrint('StoreService: Trofeo caricato: ${_availableTrophies[trophyIndex].name}');
      } else {
        debugPrint('StoreService: ATTENZIONE - Trofeo non trovato: $trophyId');
      }
    }
  }

  bool canPurchaseTrophy(Trophy trophy) {
    // Verifiche preventive
    if (_player.id.isEmpty) {
      debugPrint('StoreService: canPurchaseTrophy - ID profilo vuoto');
      return false;
    }

    if (trophy.isOwned) {
      debugPrint('StoreService: Non può acquistare - trofeo già posseduto: ${trophy.id}');
      return false;
    }

    // Verifica che tutti i trofei precedenti siano stati acquistati
    for (var t in _availableTrophies) {
      if (t.sequenceNumber < trophy.sequenceNumber && !t.isOwned) {
        debugPrint('StoreService: Non può acquistare - manca un trofeo precedente: ${t.id}');
        return false;
      }
    }

    // Verifica che ci siano abbastanza cristalli
    final hasSufficientCrystals = _player.totalCrystals >= trophy.cost;
    debugPrint('StoreService: Cristalli sufficienti per ${trophy.id}? $hasSufficientCrystals (disponibili: ${_player.totalCrystals}, costo: ${trophy.cost})');

    return hasSufficientCrystals;
  }

  Future<bool> purchaseTrophy(Trophy trophy) async {
    debugPrint('StoreService: Tentativo di acquisto trofeo: ${trophy.id}, costo: ${trophy.cost}');

    if (_player.id.isEmpty) {
      debugPrint('StoreService: purchaseTrophy - ID profilo vuoto');
      return false;
    }

    if (!canPurchaseTrophy(trophy)) {
      debugPrint('StoreService: Impossibile acquistare il trofeo ${trophy.id}');
      return false;
    }

    try {
      // Sottrai i cristalli dal giocatore
      _player.addCrystals(-trophy.cost);
      debugPrint('StoreService: Cristalli sottratti correttamente. Nuovo saldo: ${_player.totalCrystals}');

      // Segna il trofeo come posseduto
      int trophyIndex = _availableTrophies.indexWhere((t) => t.id == trophy.id);
      if (trophyIndex != -1) {
        _availableTrophies[trophyIndex].isOwned = true;
      } else {
        trophy.isOwned = true;
      }

      // Aggiungi il trofeo direttamente al player usando il nuovo metodo
      _player.addTrophy(trophy.id);

      debugPrint('StoreService: Trofeo ${trophy.id} acquistato e salvato con successo');

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('StoreService: Errore nell\'acquisto del trofeo: $e');
      // Tentativo di rollback
      try {
        _player.addCrystals(trophy.cost); // Restituisci i cristalli
        trophy.isOwned = false; // Resetta lo stato del trofeo
      } catch (rollbackError) {
        debugPrint('StoreService: Errore nel rollback: $rollbackError');
      }
      return false;
    }
  }

  Trophy? getTrophyById(String id) {
    try {
      return _availableTrophies.firstWhere((t) => t.id == id);
    } catch (e) {
      debugPrint('StoreService: Trofeo non trovato: $id');
      return null;
    }
  }

  List<Trophy> getTrophiesByRarity(String rarity) {
    return _availableTrophies.where((t) => t.rarity == rarity).toList();
  }

  Future<void> resetStore() async {
    if (_player.id.isEmpty) {
      debugPrint('StoreService: resetStore - ID profilo vuoto');
      return;
    }

    debugPrint('StoreService: Reset store per profilo ${_player.id}');

    try {
      // Resetta lo stato di tutti i trofei
      for (var trophy in _availableTrophies) {
        trophy.isOwned = false;
      }

      // Pulisci la lista dei trofei posseduti
      while (_player.ownedTrophies.isNotEmpty) {
        _player.addTrophy(_player.ownedTrophies.first); // Rimuove dalla lista
      }

      await _player.saveProgress();
      notifyListeners();
      debugPrint('StoreService: Store resettato con successo');
    } catch (e) {
      debugPrint('StoreService: Errore nel reset dello store: $e');
    }
  }

  // Aggiornamento profilo del giocatore
  void updatePlayerProfile(Player newPlayer) {
    debugPrint('StoreService: updatePlayerProfile chiamato con ${newPlayer.id}');

    if (_player.id != newPlayer.id) {
      debugPrint('StoreService: Cambio profilo da ${_player.id} a ${newPlayer.id}');
      debugPrint('StoreService: Trofei precedenti: ${_player.ownedTrophies}');
      debugPrint('StoreService: Nuovi trofei: ${newPlayer.ownedTrophies}');

      // Aggiorna il riferimento al player
      _player = newPlayer;

      // Reinizializza completamente lo store con il nuovo player
      _initializeStore();
    } else if (_player != newPlayer) {
      // Se è lo stesso player ma istanza diversa, aggiorna il riferimento
      debugPrint('StoreService: Aggiornamento riferimento player (stesso ID)');
      debugPrint('StoreService: Trofei attuali: ${_player.ownedTrophies}');
      debugPrint('StoreService: Trofei nuovi: ${newPlayer.ownedTrophies}');

      _player = newPlayer;
      _loadTrophiesFromPlayer();
      notifyListeners();
    }
  }
}