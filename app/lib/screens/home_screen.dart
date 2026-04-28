import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'add_profile_screen.dart';
import 'profile_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Profile> _profiles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profiles = await context.read<AuthProvider>().api.listProfiles();
      if (mounted) setState(() => _profiles = profiles);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  void _openProfile(Profile profile) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfileScreen(profile: profile),
    ));
    _load(); // refresh after returning — Gmail may have been connected
  }

  void _addProfile() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const AddProfileScreen(),
    ));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Profiles',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: _logout,
            tooltip: 'Sign out',
          ),
        ],
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProfile,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    if (_profiles.isEmpty) {
      return const Center(
        child: Text(
          'No profiles yet.\nTap + to add one.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: Colors.white,
      backgroundColor: Colors.grey[900],
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _profiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ProfileCard(
          profile: _profiles[i],
          onTap: () => _openProfile(_profiles[i]),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Profile profile;
  final VoidCallback onTap;

  const _ProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: profile.hasGmail ? Colors.white24 : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white12,
              backgroundImage: profile.faceUrl != null
                  ? NetworkImage(profile.faceUrl!)
                  : null,
              child: profile.faceUrl == null
                  ? Text(
                      profile.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    )
                  : null, // Hide the letter if we have an image
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600),
                  ),
                  if (profile.email != null)
                    Text(
                      profile.email!,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
                    )
                  else
                    const Text(
                      'No Gmail connected',
                      style: TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                ],
              ),
            ),
            Icon(
              profile.hasGmail ? Icons.mail_outline : Icons.chevron_right,
              color: profile.hasGmail ? Colors.greenAccent : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}
