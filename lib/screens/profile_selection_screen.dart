// lib/screens/profile_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/player_manager.dart';
import '../models/player.dart';
import 'profile_creation_screen.dart';
import 'game_screen.dart';
import '../widgets/adaptive_profile_card.dart';
import 'dart:math' show min;
import '../services/ui_error_logger.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({Key? key}) : super(key: key);

  @override
  _ProfileSelectionScreenState createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen>
    with SingleTickerProviderStateMixin {
  // Stato della selezione dei profili
  final Set<String> _selectedProfiles = {};
  bool _isDeleting = false;
  bool _isSelectMode = false;

  // Controller per le animazioni
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
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

  // Layout responsivo
  int _getColumnCount(double width) {
    if (width < 360) return 2;        // Smartphone piccoli
    if (width < 600) return 3;        // Smartphone normali
    if (width < 900) return 4;        // Tablet
    return 5;                         // Desktop/Tablet grandi
  }

  EdgeInsets _getScreenPadding(double width) {
    if (width < 360) return const EdgeInsets.all(8);
    if (width < 600) return const EdgeInsets.all(12);
    return const EdgeInsets.all(16);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900, Colors.blue.shade800],
            ),
          ),
          child: SafeArea(
            child: Consumer<PlayerManager>(
              builder: (context, playerManager, child) {
                final profiles = playerManager.profiles;
                final canAddProfile = playerManager.canCreateProfile;
                final screenWidth = MediaQuery.of(context).size.width;
                final columnCount = _getColumnCount(screenWidth);
                final padding = _getScreenPadding(screenWidth);

                return Column(
                  children: [
                    _buildHeader(screenWidth),
                    if (profiles.isNotEmpty)
                      _buildToolbar(),
                    Expanded(
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: padding,
                              sliver: SliverGrid(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columnCount,
                                  childAspectRatio: 0.85,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                    if (index == profiles.length && canAddProfile) {
                                      return _buildAddProfileCard(context);
                                    }
                                    return AdaptiveProfileCard(
                                      profile: profiles[index],
                                      isSelected: _selectedProfiles.contains(profiles[index].id),
                                      isSelectMode: _isSelectMode,
                                      onTap: () => _handleProfileTap(profiles[index]),
                                      onLongPress: () => _handleProfileLongPress(profiles[index]),
                                    );
                                  },
                                  childCount: profiles.length + (canAddProfile ? 1 : 0),
                                ),
                              ),
                            ),
                            if (profiles.isEmpty)
                              SliverFillRemaining(
                                child: Center(
                                  child: _buildEmptyState(canAddProfile),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_isSelectMode && _selectedProfiles.isNotEmpty)
                      _buildDeleteButton(playerManager),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'OpenDSA: Reading',
              style: TextStyle(
                fontSize: screenWidth < 360 ? 24 : AppConfig.title,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool canAddProfile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person_add_outlined,
          size: 64,
          color: Colors.white.withOpacity(0.5),
        ),
        const SizedBox(height: 16),
        const Text(
          'Nessun profilo presente',
          style: TextStyle(
            color: Colors.white,
            fontSize: AppConfig.title,
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_selectedProfiles.isNotEmpty)
            Text(
              '${_selectedProfiles.length} selezionat${_selectedProfiles.length == 1 ? 'o' : 'i'}',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'OpenDyslexic',
              ),
            ),
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
            onPressed: _toggleSelectMode,
          ),
        ],
      ),
    );
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      if (!_isSelectMode) {
        _selectedProfiles.clear();
      }
    });
  }

  void _handleProfileTap(Player profile) {
    if (_isSelectMode) {
      setState(() {
        if (_selectedProfiles.contains(profile.id)) {
          _selectedProfiles.remove(profile.id);
        } else {
          _selectedProfiles.add(profile.id);
        }
      });
    } else {
      _selectProfile(profile);
    }
  }

  void _handleProfileLongPress(Player profile) {
    if (!_isSelectMode) {
      setState(() {
        _isSelectMode = true;
        _selectedProfiles.add(profile.id);
      });
    }
  }

  Future<bool> _handleBackPress() async {
    if (_isSelectMode) {
      setState(() {
        _isSelectMode = false;
        _selectedProfiles.clear();
      });
      return false;
    }
    return true;
  }

  Future<void> _selectProfile(Player profile) async {
    final logger = UIErrorLogger();
    logger.logInfo('[ProfileSelectionScreen] Selezione profilo: ${profile.id}');

    try {
      final playerManager = Provider.of<PlayerManager>(context, listen: false);
      await playerManager.selectProfile(profile);

      if (!mounted) return;
      logger.logInfo('[ProfileSelectionScreen] Profilo selezionato con successo, navigazione alla GameScreen');

      // Animazione di uscita
      await _animationController.reverse();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    } catch (e, stackTrace) {
      logger.logError('[ProfileSelectionScreen] Errore nella selezione del profilo', e, stackTrace);

      if (!mounted) return;

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

  Widget _buildAddProfileCard(BuildContext context) {
    // Determiniamo se siamo su uno schermo piccolo
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Hero(
      tag: 'new_profile',
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileCreationScreen()),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                // Riduciamo il raggio su schermi piccoli
                radius: isSmallScreen ? 25 : 30,
                backgroundColor: Colors.greenAccent,
                child: Icon(
                  Icons.add,
                  size: isSmallScreen ? 25 : 30,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isSmallScreen ? 'Nuovo' : 'Nuovo\nProfilo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : AppConfig.subtitle,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(PlayerManager playerManager) {
    // Determiniamo le dimensioni del contenitore in base allo schermo
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 16,
        vertical: isSmallScreen ? 8 : 16,
      ),
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
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 12 : 16,
            horizontal: isSmallScreen ? 16 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _isDeleting ? null : () => _deleteSelectedProfiles(playerManager),
      ),
    );
  }

  Future<void> _deleteSelectedProfiles(PlayerManager playerManager) async {
    final logger = UIErrorLogger();

    if (_selectedProfiles.isEmpty) return;

    logger.logInfo('[ProfileSelectionScreen] Tentativo di eliminazione profili: $_selectedProfiles');

    // Mostriamo un dialog di conferma
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sei sicuro di voler eliminare ${_selectedProfiles.length} profil${_selectedProfiles.length == 1 ? 'o' : 'i'}?',
              style: const TextStyle(fontFamily: 'OpenDyslexic'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Questa azione non può essere annullata.',
              style: TextStyle(
                fontFamily: 'OpenDyslexic',
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Annulla',
              style: TextStyle(fontFamily: 'OpenDyslexic'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
      // Effettuiamo l'eliminazione
      logger.logInfo('[ProfileSelectionScreen] Eliminazione profili confermata: $_selectedProfiles');
      await playerManager.deleteProfiles(List.from(_selectedProfiles));

      if (!mounted) return;
      logger.logInfo('[ProfileSelectionScreen] Profili eliminati con successo');

      // Mostriamo un feedback di successo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profili eliminati con successo',
            style: TextStyle(fontFamily: 'OpenDyslexic'),
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Resettiamo lo stato
      setState(() {
        _selectedProfiles.clear();
        _isSelectMode = false;
      });
    } catch (e, stackTrace) {
      logger.logError('[ProfileSelectionScreen] Errore durante l\'eliminazione dei profili', e, stackTrace);

      if (!mounted) return;

      // Mostriamo un messaggio di errore
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore durante l\'eliminazione: $e',
            style: const TextStyle(fontFamily: 'OpenDyslexic'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// Estensioni utili per il responsive design
extension ScreenSizeHelpers on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  bool get isSmallScreen => screenWidth < 360;
  bool get isMediumScreen => screenWidth < 600;
  bool get isLargeScreen => screenWidth >= 900;

  EdgeInsets get responsivePadding {
    if (isSmallScreen) return const EdgeInsets.all(8);
    if (isMediumScreen) return const EdgeInsets.all(12);
    return const EdgeInsets.all(16);
  }
}