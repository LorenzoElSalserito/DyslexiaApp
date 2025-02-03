// lib/services/player_manager.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/player.dart';
import '../services/file_storage_service.dart';

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

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadProfiles();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Error initializing PlayerManager: $e');
      rethrow;
    }
  }

  Future<void> _loadProfiles() async {
    try {
      // Carica l'ID dell'ultimo profilo usato
      final lastProfileId = _prefs.getString(_lastProfileKey);

      // Carica tutti i profili salvati
      for (final profileKey in _prefs.getKeys().where((key) => key.startsWith('profile_'))) {
        final profileData = _prefs.getString(profileKey);
        if (profileData != null) {
          try {
            final playerData = json.decode(profileData);
            final player = Player();
            player.fromJson(playerData);
            _profiles.add(player);

            // Se questo è l'ultimo profilo usato, impostalo come corrente
            if (lastProfileId == player.id) {
              _currentProfile = player;
            }
          } catch (e) {
            print('Error parsing profile data: $e');
          }
        }
      }

      // Se non c'è un profilo corrente ma ci sono profili, usa il primo
      if (_currentProfile == null && _profiles.isNotEmpty) {
        _currentProfile = _profiles.first;
        await _prefs.setString(_lastProfileKey, _currentProfile!.id);
      }

      notifyListeners();
    } catch (e) {
      print('Error loading profiles: $e');
      rethrow;
    }
  }

  /// Elimina uno o più profili, pulendo sia le SharedPreferences che i file salvati
  Future<void> deleteProfiles(List<String> profileIds) async {
    if (!_isInitialized) await initialize();

    try {
      for (final profileId in profileIds) {
        // Rimuove il profilo dalle SharedPreferences
        await _prefs.remove('profile_$profileId');

        // Rimuove il file di salvataggio
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

  /// Elimina un singolo profilo
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

  Future<bool> loadPlayerState(Player player) async {
    if (!_isInitialized) await initialize();

    try {
      if (player.id.isEmpty) {
        if (_profiles.isNotEmpty) {
          final existingPlayer = _profiles.first;
          player.id = existingPlayer.id;
        }
      }

      final profileData = await _loadProfileData(player.id);
      if (profileData != null) {
        player.fromJson(profileData);
        return true;
      }
      return false;
    } catch (e) {
      print('Error loading player state: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _loadProfileData(String profileId) async {
    try {
      // Prima prova a caricare dalle SharedPreferences
      final prefData = _prefs.getString('profile_$profileId');
      if (prefData != null) {
        return json.decode(prefData);
      }

      // Se non trovato nelle SharedPreferences, prova il file di storage
      final fileData = await _fileStorage.readProfile(profileId);
      if (fileData.isNotEmpty) {
        return fileData;
      }
    } catch (e) {
      print('Error loading profile data: $e');
    }
    return null;
  }

  Future<void> updatePlayerProfile(Player player, String name) async {
    if (!_isInitialized) await initialize();

    try {
      if (player.id.isEmpty) {
        player.id = DateTime.now().millisecondsSinceEpoch.toString();
      }

      await player.setPlayerInfo(name);

      if (!_profiles.contains(player)) {
        _profiles.add(player);
      }

      _currentProfile = player;
      await _saveProfile(player);
      await _prefs.setString(_lastProfileKey, player.id);

      notifyListeners();
    } catch (e) {
      print('Error updating player profile: $e');
      rethrow;
    }
  }

  Future<void> _saveProfile(Player player) async {
    try {
      final profileData = json.encode(player.toJson());
      await _prefs.setString('profile_${player.id}', profileData);
    } catch (e) {
      print('Error saving profile: $e');
      rethrow;
    }
  }

  Future<Player> createProfile(String name) async {
    if (!_isInitialized) await initialize();
    if (_profiles.length >= maxProfiles) {
      throw Exception('Maximum number of profiles reached');
    }
    if (_profiles.any((p) => p.name == name)) {
      throw Exception('Profile name already exists');
    }

    try {
      final player = Player();
      player.id = DateTime.now().millisecondsSinceEpoch.toString();
      await player.setPlayerInfo(name);

      _profiles.add(player);
      _currentProfile = player;
      await _saveProfile(player);
      await _prefs.setString(_lastProfileKey, player.id);

      notifyListeners();
      return player;
    } catch (e) {
      print('Error creating profile: $e');
      rethrow;
    }
  }

  Future<void> selectProfile(Player profile) async {
    if (!_isInitialized) await initialize();

    _currentProfile = profile;
    await _prefs.setString(_lastProfileKey, profile.id);
    notifyListeners();
  }
}