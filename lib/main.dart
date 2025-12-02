// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // <<-- add this import
import 'admin/admin_dashboard.dart';
import 'admin/planner_dashboard.dart';
import 'auth/login.dart';
import 'auth/signup.dart';
import 'admin/calendar.dart';
import 'admin/profile.dart';
import 'admin/meetings.dart';
import 'admin/budget.dart'; // <-- new import



void main() {  WidgetsFlutterBinding.ensureInitialized();
  // Disable debug overflow banners
    WidgetsFlutterBinding.ensureInitialized();

  // Disable the yellow/black overflow debug banners in debug mode.
  debugPaintSizeEnabled = false;

  runApp(const MyApp());

  debugPaintSizeEnabled = false;
  runApp(const MyApp());
  runApp(const MyApp());
  
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),

      // Start on Login Page
      initialRoute: '/login',

      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/planner': (context) => const PlannerPage(),
        '/calendar': (context) => const CalendarPage(),
        '/profile': (context) => ProfilePage(),
        '/meetings': (context) => MeetingsPage(),
        '/budget': (context) => const BudgetPage(), // <-- new route
      }
    );
  }
}
