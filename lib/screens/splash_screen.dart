import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_mirror_app/screens/main_navigation.dart';
import '../providers/auth_provider.dart';
import 'welcome_screen.dart';

// Shown while we check for a stored JWT. Routes to home or onboarding.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    final auth = context.read<AuthProvider>();
    await auth.init();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) =>
          auth.isLoggedIn ? const MainNavigation() : const WelcomeScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wb_sunny_outlined, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Smart Mirror',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
