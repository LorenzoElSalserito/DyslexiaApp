// lib/screens/challenges_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/challenge_service.dart';
import '../widgets/challenge_list.dart';

class ChallengesScreen extends StatefulWidget {
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
        title: Text('Sfide'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
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
      body: Consumer<ChallengeService>(
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
    );
  }

  Widget _buildDailyChallenges(ChallengeService challengeService) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _buildSectionHeader(
              'Sfide Giornaliere',
              'Completa queste sfide entro la fine della giornata!',
            ),
          ),
          SizedBox(height: 16),
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
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _buildSectionHeader(
              'Sfide Settimanali',
              'Sfide più impegnative con ricompense maggiori!',
            ),
          ),
          SizedBox(height: 16),
          ChallengeList(
            challenges: challengeService.activeChallenges,
            showDaily: false,
            showWeekly: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}