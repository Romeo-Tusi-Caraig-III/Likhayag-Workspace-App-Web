// lib/user/user_root_scaffold.dart
// Root scaffold with bottom navigation for user screens

import 'package:flutter/material.dart';
import 'user_dashboard.dart';
import 'user_calendar.dart';
import 'user_budget.dart';
import 'user_meetings.dart';
import 'user_planner.dart';
import 'user_profile.dart';

class UserRootScaffold extends StatefulWidget {
  const UserRootScaffold({super.key});

  @override
  State<UserRootScaffold> createState() => _UserRootScaffoldState();
}

class _UserRootScaffoldState extends State<UserRootScaffold> {
  int _currentIndex = 0;

  static const Color emeraldStart = Color(0xFF10B981);
  static const Color emeraldEnd = Color(0xFF059669);

  final List<Widget> _screens = const [
    UserDashboardPage(),
    UserCalendarPage(),
    UserPlannerPage(),
    UserBudgetPage(),
    UserMeetingsPage(),
    UserProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: emeraldEnd,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note),
              label: 'Planner',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: 'Budget',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.video_call_outlined),
              activeIcon: Icon(Icons.video_call),
              label: 'Meetings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}