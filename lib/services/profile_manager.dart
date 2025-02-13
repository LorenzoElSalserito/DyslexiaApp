// lib/services/profile_manager.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/player.dart';

/// Classe che rappresenta un profilo giocatore esteso
class PlayerProfile extends Player {
  final String id;
  String? avatarUrl;
  final DateTime createdAt;
  DateTime lastAccess;
  Map<String, dynamic> gameData = {};

  PlayerProfile({
    required this.id,
    required String name,
    this.avatarUrl,
    required this.createdAt,
    DateTime? lastAccess,
    int totalCrystals = 0,
    int currentLevel = 1,
    int maxConsecutiveDays = 0,
    int currentConsecutiveDays = 0,
    Map<String, dynamic>? initialGameData,
  }) : lastAccess = lastAccess ?? createdAt {
    this.name = name;
    this.totalCrystals = totalCrystals;
    this.currentLevel = currentLevel;
    this.maxConsecutiveDays = maxConsecutiveDays;
    this.currentConsecutiveDays = currentConsecutiveDays;
    if (initialGameData != null) {
      this.gameData = Map<String, dynamic>.from(initialGameData);
    }
  }

  @override
  Map<String, dynamic> toJson() {
    final playerData = super.toJson();
    return {
      ...playerData,
      'id': id,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'lastAccess': lastAccess.toIso8601String(),
      'gameData': gameData,
    };
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccess: DateTime.parse(json['lastAccess'] as String),
      totalCrystals: json['totalCrystals'] as int? ?? 0,
      currentLevel: json['currentLevel'] as int? ?? 1,
      maxConsecutiveDays: json['maxConsecutiveDays'] as int? ?? 0,
      currentConsecutiveDays: json['currentConsecutiveDays'] as int? ?? 0,
      initialGameData: json['gameData'] as Map<String, dynamic>?,
    );
  }

  void updateLastAccess() {
    lastAccess = DateTime.now();
  }
}

/// Gestore dei profili giocatore
class ProfileManager extends ChangeNotifier {
  static const String _profilesKey = 'user_profiles';
  static const int _maxProfiles = 100;

  final SharedPreferences _prefs;
  List<PlayerProfile> _profiles = [];
  PlayerProfile? _activeProfile;

  ProfileManager(this._prefs) {
    _loadProfiles();
  }

  List<PlayerProfile> get profiles => List.unmodifiable(_profiles);
  PlayerProfile? get activeProfile => _activeProfile;
  bool get canAddProfile => _profiles.length < _maxProfiles;

  /// Carica i profili dal sistema
  Future<void> _loadProfiles() async {
    try {
      final profilesJson = _prefs.getString(_profilesKey);
      if (profilesJson != null) {
        final List<dynamic> profilesList = json.decode(profilesJson);
        _profiles = profilesList
            .map((data) =>
            PlayerProfile.fromJson(data as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Errore nel caricamento dei profili: $e');
      _profiles = [];
      notifyListeners();
    }
  }

  /// Salva i profili nel sistema
  Future<void> _saveProfiles() async {
    try {
      final profilesJson =
      json.encode(_profiles.map((p) => p.toJson()).toList());
      await _prefs.setString(_profilesKey, profilesJson);
    } catch (e) {
      print('Errore nel salvataggio dei profili: $e');
    }
  }

  /// Crea un nuovo profilo
  Future<bool> createProfile(String name, String? avatarUrl) async {
    if (_profiles.length >= _maxProfiles) return false;
    if (_profiles.any((p) => p.name == name)) return false;

    try {
      final newProfile = PlayerProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        avatarUrl: avatarUrl,
        createdAt: DateTime.now(),
      );

      _profiles.add(newProfile);
      await _saveProfiles();
      notifyListeners();
      return true;
    } catch (e) {
      print('Errore nella creazione del profilo: $e');
      return false;
    }
  }

  /// Seleziona un profilo esistente
  Future<bool> selectProfile(String profileId) async {
    try {
      final profile = _profiles.firstWhere(
            (p) => p.id == profileId,
        orElse: () => throw Exception('Profilo non trovato'),
      );

      profile.updateLastAccess();
      _activeProfile = profile;
      await _saveProfiles();
      notifyListeners();
      return true;
    } catch (e) {
      print('Errore nella selezione del profilo: $e');
      return false;
    }
  }

  /// Elimina un profilo esistente
  Future<bool> deleteProfile(String profileId) async {
    try {
      final initialLength = _profiles.length;
      _profiles.removeWhere((p) => p.id == profileId);

      if (_profiles.length < initialLength) {
        if (_activeProfile?.id == profileId) {
          _activeProfile = null;
        }
        await _saveProfiles();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Errore nella eliminazione del profilo: $e');
      return false;
    }
  }

  /// Modifica un profilo esistente
  Future<bool> editProfile(String profileId, {String? name, String? avatarUrl}) async {
    try {
      final profile = _profiles.firstWhere(
            (p) => p.id == profileId,
        orElse: () => throw Exception('Profilo non trovato'),
      );

      if (name != null && name != profile.name) {
        if (_profiles.any((p) => p.name == name && p.id != profileId)) {
          return false;
        }
        profile.name = name;
      }

      if (avatarUrl != null) {
        profile.avatarUrl = avatarUrl;
      }

      await _saveProfiles();
      notifyListeners();
      return true;
    } catch (e) {
      print('Errore nella modifica del profilo: $e');
      return false;
    }
  }

  /// Ottiene l'ultimo profilo attivo
  Future<PlayerProfile?> getLastActiveProfile() async {
    if (_profiles.isEmpty) return null;
    return _profiles.reduce((a, b) =>
    a.lastAccess.isAfter(b.lastAccess) ? a : b);
  }

  /// Resetta tutti i profili
  Future<void> resetProfiles() async {
    _profiles.clear();
    _activeProfile = null;
    await _prefs.remove(_profilesKey);
    notifyListeners();
  }
}
