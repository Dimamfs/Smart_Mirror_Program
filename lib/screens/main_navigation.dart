import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alert_provider.dart';
import '../providers/auth_provider.dart';
import '../services/pending_pairing.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _completePendingPairing());
  }

  Future<void> _completePendingPairing() async {
    if (!PendingPairing.has) return;
    final sid  = PendingPairing.sid!;
    final code = PendingPairing.code!;
    PendingPairing.clear();
    try {
      final api      = context.read<AuthProvider>().api;
      final result   = await api.pairMirror(sid: sid, shortCode: code);
      final mirrorId = result['mirrorId'] as String?;
      if (mirrorId == null) return;
      final profiles = await api.listProfiles();
      if (profiles.isEmpty) return;
      await api.setMirrorId(profiles.first.id, mirrorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mirror paired'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      // Session expired or rotated — discard silently; user can pair manually.
    }
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