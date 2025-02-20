// lib/screens/challenges_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/challenge_service.dart';
import '../widgets/challenge_list.dart';
import '../models/challenge.dart';

/// Stato di caricamento della schermata delle sfide
enum ChallengesLoadingState {
  initializing,  // Stato iniziale durante il primo caricamento
  loading,       // Caricamento in corso (refresh)
  loaded,        // Caricamento completato con successo
  error,         // Errore durante il caricamento
}

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({Key? key}) : super(key: key);

  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  // Controller per la gestione delle tab
  late TabController _tabController;

  // Stato del caricamento
  ChallengesLoadingState _loadingState = ChallengesLoadingState.initializing;
  String? _errorMessage;

  // Gestione del refresh
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;
  static const Duration _minRefreshInterval = Duration(seconds: 30);

  // Retry counter per i tentativi di caricamento
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    // Inizializza il caricamento delle sfide
    _initializeChallenges();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Aggiorna le sfide quando l'app torna in primo piano
      _refreshIfNeeded();
    }
  }

  Future<void> _initializeChallenges() async {
    if (!mounted) return;

    setState(() {
      _loadingState = ChallengesLoadingState.initializing;
      _errorMessage = null;
    });

    try {
      final challengeService = Provider.of<ChallengeService>(context, listen: false);

      // Breve delay per permettere l'animazione di caricamento
      await Future.delayed(const Duration(milliseconds: 300));

      // Verifica la connessione e lo stato del servizio
      await _verifyServiceHealth(challengeService);

      if (!mounted) return;

      setState(() {
        _loadingState = ChallengesLoadingState.loaded;
        _lastRefreshTime = DateTime.now();
        _retryCount = 0;
      });
    } catch (e) {
      if (!mounted) return;

      _handleError(e);
    }
  }

  Future<void> _verifyServiceHealth(ChallengeService service) async {
    try {
      // Verifica che il servizio abbia sfide caricate
      final hasDaily = service.dailyChallenges.isNotEmpty;
      final hasWeekly = service.weeklyChallenges.isNotEmpty;

      if (!hasDaily && !hasWeekly) {
        // Se non ci sono sfide, potrebbe essere necessario un refresh
        await service.refreshChallenges();
      }
    } catch (e) {
      throw Exception('Errore nella verifica del servizio: $e');
    }
  }

  Future<void> _refreshIfNeeded() async {
    // Evita refresh troppo frequenti
    if (_isRefreshing || _loadingState == ChallengesLoadingState.initializing) {
      return;
    }

    final now = DateTime.now();
    if (_lastRefreshTime != null &&
        now.difference(_lastRefreshTime!) < _minRefreshInterval) {
      return;
    }

    await _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {
      _isRefreshing = true;
      _loadingState = ChallengesLoadingState.loading;
    });

    try {
      final challengeService = Provider.of<ChallengeService>(context, listen: false);
      final refreshed = await challengeService.refreshChallenges();
      if (!refreshed) {
        // Se non ci sono nuove sfide, mostriamo un feedback all'utente
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Le sfide sono già aggiornate',
                style: TextStyle(fontFamily: 'OpenDyslexic'),
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _loadingState = ChallengesLoadingState.loaded;
        _lastRefreshTime = DateTime.now();
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      _handleError(e);
      setState(() => _isRefreshing = false);
    }
  }

  void _handleError(dynamic error) {
    _retryCount++;

    setState(() {
      _loadingState = ChallengesLoadingState.error;
      _errorMessage = 'Errore nel caricamento delle sfide: ${error.toString()}';
    });

    // Retry automatico se non abbiamo superato il limite
    if (_retryCount < _maxRetries) {
      Future.delayed(
        Duration(seconds: _retryCount * 2), // Backoff esponenziale
            () => _initializeChallenges(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isRefreshing) {
          // Mostra un dialog se stiamo refreshando
          return await _showExitConfirmationDialog();
        }
        return true;
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      title: const Text(
        'OpenDSA: Reading - Sfide',
        style: TextStyle(
          fontFamily: 'OpenDyslexic',
          color: Colors.white,
          fontSize: AppConfig.title,
        ),
      ),
      backgroundColor: Colors.blue.shade900,
      bottom: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.calendar_today),
            child: Text(
              'Giornaliere',
              style: TextStyle(
                fontFamily: 'OpenDyslexic',
                fontSize: AppConfig.others,
              ),
            ),
          ),
          Tab(
            icon: Icon(Icons.date_range),
            child: Text(
              'Settimanali',
              style: TextStyle(
                fontFamily: 'OpenDyslexic',
                fontSize: AppConfig.others,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (_loadingState == ChallengesLoadingState.loaded)
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed: _isRefreshing ? null : () => _refresh(),
          ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade900, Colors.blue.shade700],
        ),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (_loadingState) {
      case ChallengesLoadingState.initializing:
      case ChallengesLoadingState.loading:
        return _buildLoadingIndicator();

      case ChallengesLoadingState.error:
        return _buildErrorView();

      case ChallengesLoadingState.loaded:
        return _buildChallengesView();
    }
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            _loadingState == ChallengesLoadingState.initializing
                ? 'Caricamento sfide...'
                : 'Aggiornamento sfide...',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'OpenDyslexic',
              fontSize: AppConfig.subtitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Si è verificato un errore',
              style: const TextStyle(
                color: Colors.red,
                fontFamily: 'OpenDyslexic',
                fontSize: AppConfig.subtitle,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_retryCount >= _maxRetries)
              ElevatedButton(
                onPressed: () {
                  _retryCount = 0;
                  _initializeChallenges();
                },
                child: const Text(
                  'Riprova',
                  style: TextStyle(
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesView() {
    return Consumer<ChallengeService>(
      builder: (context, challengeService, child) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildChallengeTab(
                challengeService.dailyChallenges,
                'Sfide Giornaliere',
                'Nessuna sfida giornaliera disponibile',
              ),
              _buildChallengeTab(
                challengeService.weeklyChallenges,
                'Sfide Settimanali',
                'Nessuna sfida settimanale disponibile',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChallengeTab(List<Challenge> challenges, String title, String emptyMessage) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: AppConfig.subtitle,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
        ),
        if (challenges.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: AppConfig.subtitle,
                  fontFamily: 'OpenDyslexic',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: ChallengeCard(challenge: challenges[index]),
                ),
                childCount: challenges.length,
              ),
            ),
          ),
      ],
    );
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Uscire?',
          style: TextStyle(fontFamily: 'OpenDyslexic'),
        ),
        content: const Text(
          'Le sfide si stanno aggiornando. Vuoi davvero uscire?',
          style: TextStyle(fontFamily: 'OpenDyslexic'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'No',
              style: TextStyle(fontFamily: 'OpenDyslexic'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sì',
              style: TextStyle(fontFamily: 'OpenDyslexic', color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }
}