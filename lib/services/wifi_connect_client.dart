import 'dart:convert';
import 'package:http/http.dart' as http;

class WifiNetwork {
  final String ssid;
  final bool secured;
  const WifiNetwork({required this.ssid, required this.secured});
}

/// HTTP client for the balena wifi-connect captive-portal API running on the Pi.
///
/// The Pi AP is always at 192.168.42.1 (set by wifi-guard.sh).
/// Two endpoints:
///   GET  /networks  → list of available SSIDs (Pi-side scan, no phone location needed)
///   POST /connect   → form-urlencoded ssid+passphrase; Pi joins and tears the AP down
class WifiConnectClient {
  static const _portal = 'http://192.168.42.1';

  static Future<List<WifiNetwork>> scan() async {
    final res = await http
        .get(Uri.parse('$_portal/networks'))
        .timeout(const Duration(seconds: 8));
    final body = jsonDecode(res.body);
    final List<dynamic> items = body is List ? body : [];
    final seen = <String>{};
    return items
        .map((e) {
          if (e is String) return WifiNetwork(ssid: e, secured: true);
          if (e is Map) {
            return WifiNetwork(
              ssid: e['ssid']?.toString() ?? '',
              secured: (e['security'] ?? 'wpa').toString() != 'none',
            );
          }
          return null;
        })
        .whereType<WifiNetwork>()
        .where((n) => n.ssid.isNotEmpty && seen.add(n.ssid))
        .toList();
  }

  /// Submit the chosen network. After a successful POST the Pi drops the AP —
  /// connection-reset and later timeouts are both treated as success.
  static Future<void> connect({
    required String ssid,
    String identity = '',
    required String passphrase,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$_portal/connect'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'ssid': ssid,
              if (identity.isNotEmpty) 'identity': identity,
              'passphrase': passphrase,
            },
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // AP tears down on success; a dropped socket / timeout is expected.
    }
  }
}
