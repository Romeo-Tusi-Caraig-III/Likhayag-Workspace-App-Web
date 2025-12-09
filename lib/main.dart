import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ADMIN SCREENS
import 'admin/admin_dashboard.dart';
import 'admin/planner_dashboard.dart' as planner;
import 'admin/calendar.dart' as calendar;
import 'admin/profile.dart';
import 'admin/meetings.dart';
import 'admin/budget.dart';
import 'admin/root_scaffold.dart';

// USER SCREENS
import 'user/user_root_scaffold.dart';
import 'user/user_profile.dart';
import 'user/user_dashboard.dart';

// NEW USER-SPECIFIC PAGES
import 'user/user_calendar.dart';
import 'user/user_budget.dart';
import 'user/user_planner.dart';
import 'user/user_meetings.dart';

// AUTH SCREENS
import 'login.dart';
import 'auth/signup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPaintSizeEnabled = false;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // removed 'const' to avoid const constructor mismatch if any child widgets are not const
  MyApp({Key? key}) : super(key: key);

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
        // AUTH
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignUpPage(),
        '/home': (context) => RoleBasedHome(),

        // ADMIN ROUTES
        '/admin/home': (context) => RootScaffoldWithStylishNav(),
        '/dashboard': (context) => DashboardPage(),
        '/planner': (context) => planner.PlannerPage(),
        // using alias for calendar import
        '/calendar': (context) => calendar.CalendarPage(),
        '/profile': (context) => ProfilePage(),
        '/meetings': (context) => MeetingsPage(),
        '/budget': (context) => BudgetPage(),

        // USER ROUTES
        '/user/home': (context) => UserRootScaffold(),
        '/user/dashboard': (context) => UserDashboardPage(),
        '/user/profile': (context) => UserProfilePage(),

        // NEW USER-SPECIFIC ROUTES
        '/user/calendar': (context) => UserCalendarPage(),
        '/user/budget': (context) => UserBudgetPage(),
        '/user/planner': (context) => UserPlannerPage(),
        '/user/meetings': (context) => UserMeetingsPage(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text("Route not found")),
            body: Center(child: Text("No route for ${settings.name}")),
          ),
        );
      },
    );
  }
}

class RoleBasedHome extends StatefulWidget {
  // removed const ctor for parity with children
  RoleBasedHome({Key? key}) : super(key: key);

  @override
  State<RoleBasedHome> createState() => _RoleBasedHomeState();
}

class _RoleBasedHomeState extends State<RoleBasedHome> {
  @override
  void initState() {
    super.initState();
    _determineHomeRoute();
  }

  Future<void> _determineHomeRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';
    final role = prefs.getString('userRole') ?? 'user';

    if (!mounted) return;

    final isAdmin = email.toLowerCase() == 'admin@admin.com' ||
        role.toLowerCase() == 'admin' ||
        role.toLowerCase() == 'administrator';

    if (isAdmin) {
      Navigator.pushReplacementNamed(context, '/admin/home');
    } else {
      Navigator.pushReplacementNamed(context, '/user/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: Color(0xFF10B981)),
            SizedBox(height: 20),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
