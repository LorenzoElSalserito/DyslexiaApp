// lib/screens/challenges_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/challenge_service.dart';
import '../widgets/challenge_list.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({Key? key}) : super(key: key);

  @override
  _ChallengesScreenState createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
      appBar: AppBar(
        title: const Text(
          'Sfide',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            color: Colors.white,
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
              text: 'Giornaliere',
            ),
            Tab(
              icon: Icon(Icons.date_range),
              text: 'Settimanali',
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade900, Colors.blue.shade700],
          ),
        ),
        child: Consumer<ChallengeService>(
          builder: (context, challengeService, child) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildDailyChallenges(challengeService),
                _buildWeeklyChallenges(challengeService),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDailyChallenges(ChallengeService challengeService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Sfide Giornaliere\nCompleta queste sfide entro la fine della giornata!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
          const SizedBox(height: 16),
          ChallengeList(
            challenges: challengeService.activeChallenges,
            showDaily: true,
            showWeekly: false,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChallenges(ChallengeService challengeService) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Sfide Settimanali\nSfide più impegnative con ricompense maggiori!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
          const SizedBox(height: 16),
          ChallengeList(
            challenges: challengeService.activeChallenges,
            showDaily: false,
            showWeekly: true,
          ),
        ],
      ),
    );
  }
}
