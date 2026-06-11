import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../connect_mirror_screen.dart';
import '../../services/wifi_connect_client.dart';
import '../../services/mirror_hotspot.dart';

enum _FlowStep {
  joinPrompt,
  joining,
  scanning,
  pickNetwork,
  enterPassword,
  submitting,
  submitted,
}

/// Step 0 of the first-run flow.
///
/// Guides the user through connecting the Pi to their home WiFi using the
/// balena wifi-connect HTTP API (GET /networks, POST /connect).
/// Android auto-joins the SmartMirror-Setup AP via WifiNetworkSpecifier;
/// iOS shows manual join instructions.
class ConnectWifiScreen extends StatefulWidget {
  const ConnectWifiScreen({super.key});

  @override
  State<ConnectWifiScreen> createState() => _ConnectWifiScreenState();
}

class _ConnectWifiScreenState extends State<ConnectWifiScreen> {
  static const _portalUrl = 'http://192.168.42.1';

  _FlowStep _step = _FlowStep.joinPrompt;
  List<WifiNetwork> _networks = [];
  WifiNetwork? _selected;
  final _pwCtrl = TextEditingController();
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  void _goToMirrorConnect() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ConnectMirrorScreen()),
    );
  }

  Future<void> _openPortal() async {
    await launchUrl(Uri.parse(_portalUrl), mode: LaunchMode.externalApplication);
  }

  Future<void> _autoJoin() async {
    setState(() {
      _step = _FlowStep.joining;
      _error = null;
    });
    final ok = await MirrorHotspot.join();
    if (!mounted) return;
    if (ok) {
      await _scan();
    } else {
      setState(() {
        _step = _FlowStep.joinPrompt;
        _error = 'Could not connect to ${MirrorHotspot.ssid}. '
            "Join it manually in Settings, then tap \"I've joined\".";
      });
    }
  }

  Future<void> _scan() async {
    setState(() {
      _step = _FlowStep.scanning;
      _error = null;
    });
    try {
      final nets = await WifiConnectClient.scan();
      if (!mounted) return;
      setState(() {
        _networks = nets;
        _step = _FlowStep.pickNetwork;
        _error = nets.isEmpty ? 'No networks found. Try refreshing.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _FlowStep.joinPrompt;
        _error = "Couldn't reach the setup page. "
            'Make sure you\'re on ${MirrorHotspot.ssid}, then retry.';
      });
    }
  }

  void _pick(WifiNetwork net) {
    _pwCtrl.clear();
    setState(() {
      _selected = net;
      _showPassword = false;
      _error = null;
      _step = net.secured ? _FlowStep.enterPassword : _FlowStep.submitting;
    });
    if (!net.secured) _submit('');
  }

  Future<void> _submit(String pw) async {
    final net = _selected!;
    setState(() {
      _step = _FlowStep.submitting;
      _error = null;
    });
    await WifiConnectClient.connect(ssid: net.ssid, passphrase: pw);
    if (!mounted) return;
    await MirrorHotspot.leave();
    if (!mounted) return;
    setState(() => _step = _FlowStep.submitted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: switch (_step) {
          _FlowStep.joinPrompt || _FlowStep.joining => _buildJoinPrompt(),
          _FlowStep.scanning => _buildSpinner('Scanning for networks…'),
          _FlowStep.pickNetwork => _buildPicker(),
          _FlowStep.enterPassword => _buildPassword(),
          _FlowStep.submitting => _buildSpinner('Connecting mirror…'),
          _FlowStep.submitted => _buildDone(),
        },
      ),
    );
  }

  // ── join prompt ───────────────────────────────────────────────────────────

  Widget _buildJoinPrompt() {
    final isAndroid = Platform.isAndroid;
    return Padding(
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
          if (isAndroid) ...[
            const _StepRow(
              number: '1',
              title: "Connect to the mirror's hotspot",
              body: 'Tap the button below. Your phone will ask to connect to '
                  '"${MirrorHotspot.ssid}" — approve it.',
            ),
            const SizedBox(height: 20),
            const _StepRow(
              number: '2',
              title: 'Pick your home WiFi',
              body: 'Choose your network and enter its password. '
                  'The mirror will connect and its hotspot will disappear.',
            ),
          ] else ...[
            const _StepRow(
              number: '1',
              title: "Join the mirror's hotspot",
              body: 'Open Settings → Wi‑Fi and connect to:\n'
                  '"${MirrorHotspot.ssid}"  ·  Password: ${MirrorHotspot.passphrase}',
            ),
            const SizedBox(height: 20),
            const _StepRow(
              number: '2',
              title: 'Return here and pick your home WiFi',
              body: "Come back to this app and tap \"I've joined\" to see available networks.",
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _step == _FlowStep.joining
                  ? null
                  : (isAndroid ? _autoJoin : _scan),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _step == _FlowStep.joining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text(
                      isAndroid
                          ? 'Connect to ${MirrorHotspot.ssid}'
                          : "I've joined — find networks",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _openPortal,
              icon: const Icon(Icons.open_in_browser, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              label: const Text('Open WiFi setup page',
                  style: TextStyle(fontSize: 15)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _goToMirrorConnect,
            child: const Text(
              'My mirror is already on WiFi — skip',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── spinner (scanning / submitting) ──────────────────────────────────────

  Widget _buildSpinner(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 20),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  // ── network picker ────────────────────────────────────────────────────────

  Widget _buildPicker() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 12, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Pick your home WiFi',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: _scan,
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
            child: Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _networks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No networks found.',
                          style: TextStyle(color: Colors.white54, fontSize: 15)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _scan,
                          child: const Text('Refresh',
                              style: TextStyle(color: Colors.white70))),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _networks.length,
                  itemBuilder: (_, i) {
                    final n = _networks[i];
                    return ListTile(
                      leading: Icon(
                        n.secured ? Icons.lock : Icons.lock_open,
                        color: Colors.white70,
                        size: 20,
                      ),
                      title: Text(n.ssid,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white38),
                      onTap: () => _pick(n),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _openPortal,
                  icon: const Icon(Icons.open_in_browser, size: 18),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text('Open WiFi setup page'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _goToMirrorConnect,
                child: const Text(
                  'My mirror is already on WiFi — skip',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── password entry ────────────────────────────────────────────────────────

  Widget _buildPassword() {
    final net = _selected!;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const Icon(Icons.wifi_password, size: 40, color: Colors.white),
          const SizedBox(height: 20),
          Text(
            net.ssid,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the password for this network.',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _pwCtrl,
            obscureText: !_showPassword,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: Colors.white10,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white38),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                ),
                onPressed: () =>
                    setState(() => _showPassword = !_showPassword),
              ),
            ),
            onSubmitted: _submit,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _submit(_pwCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Connect',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => setState(() {
                _step = _FlowStep.pickNetwork;
                _error = null;
              }),
              child: const Text(
                '← Back to network list',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── submitted ─────────────────────────────────────────────────────────────

  Widget _buildDone() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          const Icon(Icons.check_circle_outline, size: 64, color: Colors.white),
          const SizedBox(height: 24),
          Text(
            'Connecting to\n${_selected?.ssid ?? 'your network'}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your mirror is joining your home WiFi. '
            'Reconnect your phone to your home WiFi, then tap Continue.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _goToMirrorConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _StepRow(
      {required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
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
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(body,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
