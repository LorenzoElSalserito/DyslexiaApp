// lib/services/player_manager.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const int maxProfiles = 100;

  List<Player> _profiles = [];
  Player? _currentProfile;
  bool _isInitialized = false;

  // Singleton pattern per mantenere una singola istanza
  static PlayerManager? _instance;

  factory PlayerManager(SharedPreferences prefs) {
    _instance ??= PlayerManager._internal(prefs);
    return _instance!;
  }

  PlayerManager._internal(this._prefs);

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
      debugPrint('Inizializzazione PlayerManager...');

      // Carica tutti i profili dal FileStorageService
      final profileIds = await _fileStorage.getAllProfileIds();
      _profiles = [];

      for (final id in profileIds) {
        final profileData = await _fileStorage.readProfile(id);
        if (profileData.isNotEmpty) {
          final player = Player();
          player.fromJson(profileData);
          _profiles.add(player);
          debugPrint('Caricato profilo: ${player.toJson()}');
        }
      }

      // Imposta il profilo corrente basandosi sull'ultimo usato
      final lastProfileId = _prefs.getString(_lastProfileKey);
      debugPrint('Ultimo profilo usato: $lastProfileId');

      if (_profiles.isNotEmpty) {
        if (lastProfileId != null) {
          try {
            _currentProfile = _profiles.firstWhere((p) => p.id == lastProfileId);
            await _currentProfile!.loadProgress();
            debugPrint('Profilo corrente impostato: ${_currentProfile!.toJson()}');
          } catch (e) {
            _currentProfile = _profiles.first;
            await _currentProfile!.loadProgress();
            debugPrint('Profilo di fallback impostato: ${_currentProfile!.toJson()}');
          }
        } else {
          _currentProfile = _profiles.first;
          await _currentProfile!.loadProgress();
          debugPrint('Primo profilo impostato: ${_currentProfile!.toJson()}');
        }
      } else {
        _currentProfile = null;
        debugPrint('Nessun profilo trovato');
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Errore nell\'inizializzazione di PlayerManager: $e');
      rethrow;
    }
  }

  /// Seleziona un profilo dato. Se il profilo è presente nella lista, viene ricaricato
  /// dal file e impostato come profilo attivo.
  Future<void> selectProfile(Player profile) async {
    if (!_isInitialized) await initialize();

    try {
      debugPrint('Selezione profilo: ${profile.id}');

      // Cerca il profilo con lo stesso id nella lista
      final selected = _profiles.firstWhere(
            (p) => p.id == profile.id,
        orElse: () => profile,
      );

      // Rileggi i dati dal file per aggiornare l'istanza
      final profileData = await _fileStorage.readProfile(selected.id);
      if (profileData.isNotEmpty) {
        selected.fromJson(profileData);
        debugPrint('Dati profilo caricati: ${selected.toJson()}');
      } else {
        debugPrint('Nessun dato trovato per il profilo ${selected.id}');
      }

      _currentProfile = selected;
      await _prefs.setString(_lastProfileKey, selected.id);
      notifyListeners();

      debugPrint('Profilo selezionato con successo');
    } catch (e) {
      debugPrint('Errore nella selezione del profilo: $e');
      rethrow;
    }
  }

  /// Elimina uno o più profili.
  Future<void> deleteProfiles(List<String> profileIds) async {
    if (!_isInitialized) await initialize();

    try {
      debugPrint('Eliminazione profili: $profileIds');

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
      debugPrint('Profili eliminati con successo');
    } catch (e) {
      debugPrint('Errore nell\'eliminazione dei profili: $e');
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
      debugPrint('Errore nell\'eliminazione del profilo: $e');
      return false;
    }
  }

  /// Carica lo stato di un giocatore.
  Future<bool> loadPlayerState(Player player) async {
    if (!_isInitialized) await initialize();

    try {
      debugPrint('Caricamento stato giocatore: ${player.id}');

      if (player.id.isEmpty && _profiles.isNotEmpty) {
        player.id = _profiles.first.id;
      }

      final profileData = await _fileStorage.readProfile(player.id);
      if (profileData.isNotEmpty) {
        player.fromJson(profileData);
        debugPrint('Stato giocatore caricato: ${player.toJson()}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Errore nel caricamento dello stato del giocatore: $e');
      return false;
    }
  }

  /// Aggiorna un profilo giocatore.
  Future<void> updatePlayerProfile(Player player, String name) async {
    if (!_isInitialized) await initialize();

    try {
      debugPrint('Aggiornamento profilo: ${player.id} con nome: $name');

      if (_profiles.any((p) => p.name == name && p.id != player.id)) {
        throw Exception('Il nome del profilo esiste già');
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

      debugPrint('Profilo aggiornato con successo: ${player.toJson()}');
    } catch (e) {
      debugPrint('Errore nell\'aggiornamento del profilo: $e');
      rethrow;
    }
  }

  /// Crea un nuovo profilo.
  Future<Player> createProfile(String name) async {
    if (!_isInitialized) await initialize();

    if (_profiles.length >= maxProfiles) {
      throw Exception('Numero massimo di profili raggiunto');
    }
    if (_profiles.any((p) => p.name == name)) {
      throw Exception('Il nome del profilo esiste già');
    }

    debugPrint('Creazione nuovo profilo con nome: $name');

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

      debugPrint('Nuovo profilo creato: ${newPlayer.toJson()}');
      return newPlayer;
    } catch (e) {
      _profiles.removeWhere((p) => p.id == newPlayer.id);
      if (_currentProfile?.id == newPlayer.id) {
        _currentProfile = _profiles.isNotEmpty ? _profiles.first : null;
      }
      debugPrint('Errore nella creazione del profilo: $e');
      rethrow;
    }
  }
}