import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/store_service.dart';
import '../services/player_manager.dart';
import '../models/trophy.dart';
import '../models/player.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({Key? key}) : super(key: key);

  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _currentFilter = 'Tutti';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade900, Colors.blue.shade700],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Disponibili'),
                  Tab(text: 'Ottenuti'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAvailableTrophiesTab(),
                    _buildOwnedTrophiesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<PlayerManager>(
      builder: (context, playerManager, child) {
        final Player? player = playerManager.currentProfile;
        final String crystals = player != null ? player.totalCrystals.toString() : '0';
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    'Negozio Trofei',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.diamond, color: Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      crystals,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailableTrophiesTab() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: Consumer2<StoreService, PlayerManager>(
            builder: (context, store, playerManager, child) {
              final Player? player = playerManager.currentProfile;
              var trophies = store.availableTrophies.where((t) => !t.isOwned).toList();
              if (_currentFilter != 'Tutti') {
                trophies = trophies.where((t) => t.rarity == _currentFilter).toList();
              }
              if (trophies.isEmpty) {
                return const Center(
                  child: Text(
                    'Nessun trofeo disponibile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                );
              }
              return _buildTrophyGrid(trophies, store, player);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOwnedTrophiesTab() {
    return Consumer<StoreService>(
      builder: (context, store, child) {
        final trophies = store.ownedTrophies;
        if (trophies.isEmpty) {
          return const Center(
            child: Text(
              'Non hai ancora sbloccato nessun trofeo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          );
        }
        return _buildTrophyGrid(trophies, store, null);
      },
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Tutti', 'Comune', 'Non comune', 'Raro', 'Epico', 'Leggendario']
              .map((filter) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(
                filter,
                style: const TextStyle(fontFamily: 'OpenDyslexic'),
              ),
              selected: _currentFilter == filter,
              selectedColor: Colors.amber,
              checkmarkColor: Colors.black,
              onSelected: (selected) {
                setState(() {
                  _currentFilter = selected ? filter : 'Tutti';
                });
              },
            ),
          ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTrophyGrid(List<Trophy> trophies, StoreService store, Player? player) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: trophies.length,
      itemBuilder: (context, index) => _buildTrophyCard(trophies[index], store, player),
    );
  }

  Widget _buildTrophyCard(Trophy trophy, StoreService store, Player? player) {
    final bool canBuy = player != null && store.canPurchaseTrophy(trophy);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: trophy.color.withOpacity(trophy.isOwned ? 0.8 : 0.3),
          width: trophy.isOwned ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showTrophyDetails(trophy, store, player),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                trophy.icon,
                size: 48,
                color: trophy.color,
              ),
              const SizedBox(height: 8),
              Text(
                trophy.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'OpenDyslexic',
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                trophy.rarity,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 12,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              if (!trophy.isOwned && player != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.diamond,
                      size: 16,
                      color: canBuy ? Colors.amber : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trophy.cost}',
                      style: TextStyle(
                        color: canBuy ? Colors.black : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'OpenDyslexic',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              if (trophy.isOwned)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green[700],
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrophyDetails(Trophy trophy, StoreService store, Player? player) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(trophy.icon, color: trophy.color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                trophy.name,
                style: const TextStyle(
                  fontFamily: 'OpenDyslexic',
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trophy.description,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'OpenDyslexic',
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.star, size: 20, color: trophy.color),
                  const SizedBox(width: 8),
                  Text(
                    'Rarità: ${trophy.rarity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'OpenDyslexic',
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Titolo sbloccato: ${trophy.title}',
                style: const TextStyle(
                  fontFamily: 'OpenDyslexic',
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (!trophy.isOwned && player != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.diamond, size: 20, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Costo: ${trophy.cost}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'OpenDyslexic',
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!trophy.isOwned && player != null)
            TextButton(
              onPressed: store.canPurchaseTrophy(trophy)
                  ? () async {
                final success = await store.purchaseTrophy(trophy);
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Trofeo acquistato con successo!',
                        style: TextStyle(fontFamily: 'OpenDyslexic'),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Impossibile acquistare il trofeo',
                        style: TextStyle(fontFamily: 'OpenDyslexic'),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
                  : null,
              child: const Text(
                'Acquista',
                style: TextStyle(
                  fontFamily: 'OpenDyslexic',
                  color: Colors.blue,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Chiudi',
              style: TextStyle(
                fontFamily: 'OpenDyslexic',
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
