// lib/admin/root_scaffold.dart
import 'package:flutter/material.dart';
import 'budget.dart';
import 'admin_dashboard.dart';
import 'planner_dashboard.dart';
import 'calendar.dart';
import 'profile.dart';
import 'meetings.dart';
import 'budget.dart';
import 'planner_dashboard.dart' as planner;
import 'calendar.dart' as calendar;
class RootScaffoldWithStylishNav extends StatefulWidget {
  const RootScaffoldWithStylishNav({Key? key}) : super(key: key);

  @override
  State<RootScaffoldWithStylishNav> createState() =>
      _RootScaffoldWithStylishNavState();
}

class _RootScaffoldWithStylishNavState
    extends State<RootScaffoldWithStylishNav> {
  int _currentIndex = 0;

  // Use KeyedSubtree wrappers so Flutter won't accidentally reuse the wrong state
  // when the navigation order is changed.
  final List<Widget> _pages = <Widget>[
    KeyedSubtree(key: ValueKey('page_dashboard'), child: DashboardPage()),
    KeyedSubtree(key: ValueKey('page_calendar'), child: CalendarPage()),
    KeyedSubtree(key: ValueKey('page_planner'), child: const planner.PlannerPage()),
    KeyedSubtree(key: ValueKey('page_budget'), child: BudgetPage()),
    KeyedSubtree(key: ValueKey('page_meetings'), child: MeetingsPage()),
    KeyedSubtree(key: ValueKey('page_profile'), child: ProfilePage()),
  ];

  void _onTap(int index) {
    if (index == _currentIndex) return; // avoid unnecessary rebuild when tapping same tab
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // keep pages alive & preserve state
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,

        // NAV ITEMS (Dashboard, Calendar, Planner, Budget, Meetings, Profile)
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            label: 'Meetings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
