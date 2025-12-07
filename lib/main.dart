// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// ADMIN SCREENS
import 'admin/admin_dashboard.dart';
import 'admin/planner_dashboard.dart';
import 'admin/calendar.dart';
import 'admin/profile.dart';
import 'admin/meetings.dart';
import 'admin/budget.dart';

// AUTH SCREENS
import 'login.dart';
import 'auth/signup.dart';

// NEW NAVIGATION SYSTEM
import 'admin/root_scaffold..dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  debugPaintSizeEnabled = false;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Likhayag',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),

      initialRoute: '/login',

      routes: {
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignUpPage(),

        // When the user logs in successfully → go to this
        '/home': (context) => RootScaffoldWithStylishNav(),

        '/dashboard': (context) => DashboardPage(),
        '/planner': (context) => PlannerPage(),
        '/calendar': (context) => CalendarPage(),
        '/profile': (context) => ProfilePage(),
        '/meetings': (context) => MeetingsPage(),
        '/budget': (context) => BudgetPage(),
      },
    );
  }
}
