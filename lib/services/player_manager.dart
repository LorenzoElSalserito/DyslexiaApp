// lib/services/player_manager.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/player.dart';
import '../services/file_storage_service.dart';

/// Gestore dei profili giocatore.
/// Si occupa della creazione, caricamento e gestione dei profili,
/// utilizzando il FileStorageService per la persistenza dei dati
/// e SharedPreferences solo per memorizzare l'ultimo profilo usato.
class PlayerManager extends ChangeNotifier {
  final SharedPreferences _prefs;
  final FileStorageService _fileStorage = FileStorageService();
  static const String _lastProfileKey = 'last_profile_id';
  static const int maxProfiles = 4;

  List<Player> _profiles = [];
  Player? _currentProfile;
  bool _isInitialized = false;

  PlayerManager(this._prefs);

  // Getters pubblici
  List<Player> get profiles => List.unmodifiable(_profiles);
  Player? get currentProfile => _currentProfile;
  bool get hasCurrentProfile => _currentProfile != null;
  bool get canCreateProfile => _profiles.length < maxProfiles;
  bool get isInitialized => _isInitialized;

  /// Inizializza il manager caricando i profili salvati.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Carica tutti i profili dal FileStorageService
      final profileIds = await _fileStorage.getAllProfileIds();
      _profiles = [];
      for (final id in profileIds) {
        final profileData = await _fileStorage.readProfile(id);
        if (profileData.isNotEmpty) {
          final player = Player();
          player.fromJson(profileData);
          _profiles.add(player);
        }
      }

      // Imposta il profilo corrente basandosi sull'ultimo usato
      if (_profiles.isNotEmpty) {
        final lastProfileId = _prefs.getString(_lastProfileKey);
        if (lastProfileId != null) {
          try {
            _currentProfile =
                _profiles.firstWhere((p) => p.id == lastProfileId);
          } catch (e) {
            // Se non viene trovato il profilo con l'ID salvato, usa il primo della lista.
            _currentProfile = _profiles.first;
          }
        } else {
          _currentProfile = _profiles.first;
        }
      } else {
        _currentProfile = null;
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing PlayerManager: $e');
      rethrow;
    }
  }

  /// Seleziona un profilo dato. Se il profilo è presente nella lista, viene ricaricato
  /// dal file e impostato come profilo attivo.
  Future<void> selectProfile(Player profile) async {
    if (!_isInitialized) await initialize();

    try {
      // Cerca il profilo con lo stesso id nella lista
      final selected = _profiles.firstWhere(
            (p) => p.id == profile.id,
        orElse: () => profile,
      );
      // Rileggi i dati dal file per aggiornare l'istanza
      final profileData = await _fileStorage.readProfile(selected.id);
      if (profileData.isNotEmpty) {
        selected.fromJson(profileData);
      } else {
        print('Nessun dato letto per il profilo ${selected.id}');
      }
      _currentProfile = selected;
      await _prefs.setString(_lastProfileKey, selected.id);
      notifyListeners();
    } catch (e) {
      print('Errore nella selezione del profilo: $e');
      rethrow;
    }
  }

  /// Elimina uno o più profili.
  Future<void> deleteProfiles(List<String> profileIds) async {
    if (!_isInitialized) await initialize();

    try {
      for (final profileId in profileIds) {
        // Elimina il file del profilo
        await _fileStorage.deleteProfile(profileId);

        // Rimuove il profilo dalla lista in memoria
        _profiles.removeWhere((p) => p.id == profileId);

        // Se il profilo corrente è stato eliminato, aggiorna il profilo corrente
        if (_currentProfile?.id == profileId) {
          _currentProfile = _profiles.isNotEmpty ? _profiles.first : null;
          if (_currentProfile != null) {
            await _prefs.setString(_lastProfileKey, _currentProfile!.id);
          } else {
            await _prefs.remove(_lastProfileKey);
          }
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error deleting profiles: $e');
      rethrow;
    }
  }

  /// Elimina un singolo profilo.
  Future<bool> deleteProfile(String profileId) async {
    if (!_isInitialized) await initialize();

    try {
      await deleteProfiles([profileId]);
      return true;
    } catch (e) {
      print('Error deleting profile: $e');
      return false;
    }
  }

  /// Carica lo stato di un giocatore.
  Future<bool> loadPlayerState(Player player) async {
    if (!_isInitialized) await initialize();

    try {
      if (player.id.isEmpty && _profiles.isNotEmpty) {
        player.id = _profiles.first.id;
      }

      final profileData = await _fileStorage.readProfile(player.id);
      if (profileData.isNotEmpty) {
        player.fromJson(profileData);
        return true;
      }
      return false;
    } catch (e) {
      print('Error loading player state: $e');
      return false;
    }
  }

  /// Aggiorna un profilo giocatore.
  Future<void> updatePlayerProfile(Player player, String name) async {
    if (!_isInitialized) await initialize();

    try {
      if (_profiles.any((p) => p.name == name && p.id != player.id)) {
        throw Exception('Profile name already exists');
      }

      // Genera un nuovo ID se necessario
      if (player.id.isEmpty) {
        player.id = DateTime.now().millisecondsSinceEpoch.toString();
      }

      await player.setPlayerInfo(name);

      if (!_profiles.contains(player)) {
        _profiles.add(player);
      }

      _currentProfile = player;

      final profileData = player.toJson();
      await _fileStorage.writeProfile(player.id, profileData);
      await _prefs.setString(_lastProfileKey, player.id);
      notifyListeners();
    } catch (e) {
      print('Error updating player profile: $e');
      rethrow;
    }
  }

  /// Crea un nuovo profilo.
  Future<Player> createProfile(String name) async {
    if (!_isInitialized) await initialize();

    if (_profiles.length >= maxProfiles) {
      throw Exception('Maximum number of profiles reached');
    }
    if (_profiles.any((p) => p.name == name)) {
      throw Exception('Profile name already exists');
    }

    late Player newPlayer;
    try {
      newPlayer = Player();
      newPlayer.id = DateTime.now().millisecondsSinceEpoch.toString();

      _profiles.add(newPlayer);
      _currentProfile = newPlayer;

      await _prefs.setString(_lastProfileKey, newPlayer.id);
      await newPlayer.setPlayerInfo(name);

      final profileData = newPlayer.toJson();
      await _fileStorage.writeProfile(newPlayer.id, profileData);
      notifyListeners();
      return newPlayer;
    } catch (e) {
      _profiles.removeWhere((p) => p.id == newPlayer.id);
      if (_currentProfile?.id == newPlayer.id) {
        _currentProfile = _profiles.isNotEmpty ? _profiles.first : null;
      }
      print('Error creating profile: $e');
      rethrow;
    }
  }
}
