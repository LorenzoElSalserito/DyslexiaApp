// lib/screens/profile_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_manager.dart';
import '../models/player.dart';
import 'profile_creation_screen.dart';
import 'game_screen.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({Key? key}) : super(key: key);

  @override
  _ProfileSelectionScreenState createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen>
    with SingleTickerProviderStateMixin {
  // Stato per la gestione della selezione e dell'eliminazione
  final Set<String> _selectedProfiles = {};
  bool _isDeleting = false;
  bool _isSelectMode = false; // Flag per la modalità selezione

  // Controller per le animazioni
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Gestione eliminazione profili
  Future<void> _deleteSelectedProfiles(BuildContext context, PlayerManager playerManager) async {
    if (_selectedProfiles.isEmpty) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Elimina Profili',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Sei sicuro di voler eliminare ${_selectedProfiles.length} profil${_selectedProfiles.length == 1 ? 'o' : 'i'} selezionat${_selectedProfiles.length == 1 ? 'o' : 'i'}?\n'
              'Questa operazione non può essere annullata.',
          style: const TextStyle(fontFamily: 'OpenDyslexic'),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Annulla',
              style: TextStyle(fontFamily: 'OpenDyslexic'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text(
              'Elimina',
              style: TextStyle(
                fontFamily: 'OpenDyslexic',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _isDeleting = true);

    try {
      for (final profileId in _selectedProfiles) {
        await playerManager.deleteProfile(profileId);
      }

      setState(() {
        _selectedProfiles.clear();
        _isSelectMode = false; // Disattiva la modalità selezione dopo l'eliminazione
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profili eliminati con successo',
              style: TextStyle(fontFamily: 'OpenDyslexic'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore durante l\'eliminazione: $e',
              style: const TextStyle(fontFamily: 'OpenDyslexic'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerManager>(
      builder: (context, playerManager, child) {
        final profiles = playerManager.profiles;
        final canAddProfile = playerManager.canCreateProfile;

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.lightBlue.shade800, Colors.lightBlue.shade500],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(profiles),
                  // Barra degli strumenti con pulsante di eliminazione
                  if (profiles.isNotEmpty) _buildToolbar(context),
                  Expanded(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, // Aumentato a 3 per profili più piccoli
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: profiles.length + (canAddProfile ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == profiles.length && canAddProfile) {
                            return _buildAddProfileCard(context);
                          }
                          return _buildProfileCard(
                            context,
                            profiles[index],
                            playerManager,
                            isSelected: _selectedProfiles.contains(profiles[index].id),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_isSelectMode && _selectedProfiles.isNotEmpty)
                    _buildDeleteButton(playerManager, context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(List<Player> profiles) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'OpenDSA: Reading',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profiles.isEmpty
                ? 'Crea il tuo primo profilo'
                : 'Seleziona il tuo profilo per iniziare',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  // Barra degli strumenti con pulsante di eliminazione
  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            icon: Icon(
              _isSelectMode ? Icons.close : Icons.delete,
              color: Colors.white,
            ),
            label: Text(
              _isSelectMode ? 'Annulla' : 'Gestisci Profili',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            onPressed: () {
              setState(() {
                _isSelectMode = !_isSelectMode;
                if (!_isSelectMode) {
                  _selectedProfiles.clear();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(PlayerManager playerManager, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: _isDeleting
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Icon(Icons.delete_forever),
          label: Text(
            _isDeleting
                ? 'Eliminazione in corso...'
                : 'Elimina ${_selectedProfiles.length} profil${_selectedProfiles.length == 1 ? 'o' : 'i'}',
            style: const TextStyle(fontFamily: 'OpenDyslexic'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade100,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isDeleting
              ? null
              : () => _deleteSelectedProfiles(context, playerManager),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
      BuildContext context,
      Player profile,
      PlayerManager playerManager, {
        required bool isSelected,
      }) {
    return Card(
      elevation: isSelected ? 8 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.yellow : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedProfiles.remove(profile.id);
              } else {
                _selectedProfiles.add(profile.id);
              }
            });
          } else {
            _selectProfile(context, profile);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Uso di Center per assicurare la centratura di tutto il contenuto
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileAvatar(profile),
                    const SizedBox(height: 8),
                    _buildProfileInfo(profile),
                  ],
                ),
              ),
            ),
            if (_isSelectMode)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.yellow : Colors.white.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check : Icons.check_box_outline_blank,
                    color: isSelected ? Colors.black : Colors.grey,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(Player profile) {
    return Hero(
      tag: 'profile_avatar_${profile.id}',
      child: CircleAvatar(
        radius: 30, // Ridotto da 40 a 30
        backgroundColor: Colors.lightBlue.shade200,
        child: Text(
          profile.name[0].toUpperCase(),
          style: const TextStyle(
            fontSize: 24, // Ridotto da 36 a 24
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(Player profile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center, // Centratura orizzontale
      children: [
        Text(
          profile.name,
          style: const TextStyle(
            fontSize: 14, // Ridotto da 20 a 14
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenDyslexic',
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        if (profile.currentLevel > 1 || profile.totalCrystals > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Liv. ${profile.currentLevel}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontFamily: 'OpenDyslexic',
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond, size: 12, color: Colors.amber),
              const SizedBox(width: 2),
              Text(
                '${profile.totalCrystals}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAddProfileCard(BuildContext context) {
    return Hero(
      tag: 'new_profile',
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.lightBlue.shade200,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfileCreationScreen()),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30, // Dimensione ridotta per corrispondere agli altri profili
                backgroundColor: Colors.lightBlue.shade100,
                child: Icon(
                  Icons.add,
                  size: 30,
                  color: Colors.lightBlue.shade800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nuovo\nProfilo', // Testo su due righe per mantenere il layout compatto
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectProfile(BuildContext context, Player profile) async {
    final playerManager = Provider.of<PlayerManager>(context, listen: false);
    try {
      await playerManager.selectProfile(profile);
      final globalPlayer = Provider.of<Player>(context, listen: false);
      await globalPlayer.loadProgress();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Errore nella selezione del profilo: $e',
              style: const TextStyle(fontFamily: 'OpenDyslexic'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
