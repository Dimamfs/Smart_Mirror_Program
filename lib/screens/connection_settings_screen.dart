import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import '../services/connectivity_service.dart';

/// Manual fallback for setting the backend (mirror/server) address when the
/// QR pairing flow isn't available — e.g. no camera, or a mirror running an
/// older build whose QR predates the v2 (URL-carrying) payload.
///
/// Lets the user type an address, test it against `GET /health`, and save it.
/// Saving persists via [ApiConfig.setBaseUrl] so it survives restarts.
///
/// When [popOnSave] is true the screen pops `true` after a successful save
/// instead of showing a snackbar — used as the manual fallback in the first-run
/// connection gate, so the caller can advance to sign-up / sign-in.
class ConnectionSettingsScreen extends StatefulWidget {
  final bool popOnSave;

  const ConnectionSettingsScreen({super.key, this.popOnSave = false});

  @override
  State<ConnectionSettingsScreen> createState() =>
      _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  late final TextEditingController _urlCtrl;

  bool _testing = false;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ApiConfig.hostFromBaseUrl());
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _error = 'Enter the mirror / server address first.';
        _success = null;
      });
      return;
    }

    final base = ApiConfig.normalize(raw);
    setState(() {
      _testing = true;
      _error = null;
      _success = null;
    });

    try {
      final res = await http
          .get(Uri.parse(ConnectivityService.healthUrl(base)))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() => _success = 'Connected — backend is reachable.');
      } else {
        setState(() => _error =
            'Server responded with HTTP ${res.statusCode}. Check the address.');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _error =
            'Timed out. Check the IP and that phone + server share a network.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Connection error — is the backend running and reachable?');
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _error = 'Enter the mirror / server address first.';
        _success = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    await ApiConfig.setBaseUrl(raw);
    if (!mounted) return;
    // First-run gate: hand control back so the caller can proceed to login.
    if (widget.popOnSave) {
      Navigator.of(context).pop(true);
      return;
    }
    // Reflect the host back into the field (scheme/port hidden from user).
    _urlCtrl.text = ApiConfig.hostFromBaseUrl();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server address saved'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Connection',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MIRROR IP ADDRESS',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlCtrl,
                  autocorrect: false,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: '192.168.1.6',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Enter your mirror's IP address (shown on the mirror); "
                  'the app adds the port and path automatically.',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          if (_success != null) ...[
            const SizedBox(height: 16),
            Text(_success!, style: const TextStyle(color: Colors.greenAccent)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _testing ? null : _test,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Test connection',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Save',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
