import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alert_provider.dart';
import 'dashboard_screen.dart';
import 'alert_screen.dart';
import 'face_setup_screen.dart';
import 'home_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Alerts received while backgrounded are written to storage by the FCM
    // background isolate; reload them so the list is current on resume.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AlertProvider>().loadAlerts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // IndexedStack keeps all tabs alive so switching doesn't dispose +
        // rebuild each screen (which re-fetched profiles and re-initialised
        // the camera every time).
        child: IndexedStack(
          index: _currentIndex,
          children: [
            DashboardScreen(isActive: _currentIndex == 0),
            const AlertScreen(),
            FaceSetupScreen(isActive: _currentIndex == 2),
            const HomeScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
          backgroundColor: Colors.black, 
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
            BottomNavigationBarItem(icon: Icon(Icons.face), label: 'Face Setup'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Profiles'),
          ],
        ),
      ),
    );
  }
}