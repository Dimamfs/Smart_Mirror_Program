import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../connect_mirror_screen.dart';

/// Step 0 of the first-run flow.
///
/// Guides the customer through connecting the Pi to their home WiFi via the
/// SmartMirror-Setup hotspot + captive portal (balena wifi-connect).
/// Once done, continues to [ConnectMirrorScreen] (scan the mirror QR).
class ConnectWifiScreen extends StatelessWidget {
  const ConnectWifiScreen({super.key});

  // Must match wifi-guard.sh defaults (or the printed values in the box).
  static const _ssid = 'SmartMirror-Setup';
  static const _passphrase = 'SmartMirror1';
  static const _portalUrl = 'http://192.168.42.1';

  Future<void> _openPortal() async {
    final uri = Uri.parse(_portalUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _continue(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ConnectMirrorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.wifi_tethering, size: 56, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Connect mirror\nto WiFi',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your mirror needs to join your home WiFi before the app can reach it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
              const SizedBox(height: 32),
              _Step(
                number: '1',
                title: 'Join the mirror\'s hotspot',
                body: 'Open your phone\'s WiFi settings and connect to:\n'
                    '"$_ssid"  ·  Password: $_passphrase',
              ),
              const SizedBox(height: 20),
              _Step(
                number: '2',
                title: 'Open the setup page',
                body: 'A setup page should open automatically. '
                    'If not, tap "Open WiFi setup page" below.',
              ),
              const SizedBox(height: 20),
              _Step(
                number: '3',
                title: 'Pick your home WiFi',
                body: 'Choose your network, enter your password, and tap Connect. '
                    'The mirror will join and the hotspot will disappear.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openPortal,
                  icon: const Icon(Icons.open_in_browser, size: 20),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text(
                    'Open WiFi setup page',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _continue(context),
                  icon: const Icon(Icons.arrow_forward, size: 20),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text(
                    'Mirror is connected — Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _continue(context),
                  child: const Text(
                    'My mirror is already on WiFi — skip',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _Step({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
