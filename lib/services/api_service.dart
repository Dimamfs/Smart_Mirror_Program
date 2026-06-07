import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api.dart';
import '../models/ai_settings.dart';
import '../models/household.dart';
import '../models/profile.dart';
import '../models/email_message.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class ApiService {
  final String? token;

  ApiService({this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // Parses the response and throws ApiException on non-2xx.
  // Tolerates empty bodies (e.g. 204 No Content) and non-JSON error pages
  // so callers get a clean ApiException instead of a raw FormatException.
  dynamic _parse(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;

    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        if (ok) return null; // 2xx with a non-JSON body — nothing to return
        throw ApiException(
            'Unexpected server response (HTTP ${res.statusCode})',
            res.statusCode);
      }
    }

    if (ok) return body;

    final msg = (body is Map && body['error'] != null)
        ? body['error'].toString()
        : 'Request failed (HTTP ${res.statusCode})';
    throw ApiException(msg, res.statusCode);
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  Future<Household> createHousehold(String name) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/households'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    return Household.fromJson(_parse(res)['household']);
  }

  Future<Map<String, dynamic>> register({
    required int householdId,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'householdId': householdId,
        'email': email,
        'password': password,
      }),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(res);
  }

  // ── Profiles ────────────────────────────────────────────────────────────────

  Future<List<Profile>> listProfiles() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profiles'),
      headers: _headers,
    );
    final List data = _parse(res)['profiles'];
    return data.map((j) => Profile.fromJson(j)).toList();
  }

  Future<Profile> getProfile(int id) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$id'),
      headers: _headers,
    );
    return Profile.fromJson(_parse(res)['profile']);
  }

  Future<Profile> createProfile({required String name, String? email}) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/profiles'),
      headers: _headers,
      body: jsonEncode({'name': name, if (email != null) 'email': email}),
    );
    return Profile.fromJson(_parse(res)['profile']);
  }

  Future<void> deleteProfile(int profileId) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$profileId'),
      headers: _headers,
    );
    _parse(res);
  }

  Future<Profile> updateWidgets(
      int profileId, Map<String, bool> widgets) async {
    final url = '${ApiConfig.baseUrl}/profiles/$profileId/widgets';
    debugPrint('[ApiService] PATCH $url');
    final res = await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode({'widgets': widgets}),
    );
    return Profile.fromJson(_parse(res)['profile']);
  }

  // ── Face Setup ──────────────────────────────────────────────────────────────

  Future<void> uploadFace(int profileId, String imagePath) async {
    final url = '${ApiConfig.baseUrl}/profiles/$profileId/face';
    debugPrint('[ApiService] POST $url');

    var request = http.MultipartRequest('POST', Uri.parse(url));

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath('face', imagePath));

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('[ApiService] Face uploaded successfully');
    } else {
      final msg = jsonDecode(response.body)['error'] ?? 'Failed to upload face';
      throw ApiException(msg, response.statusCode);
    }
  }

  Future<void> uploadFaces(int profileId, List<String> imagePaths) async {
    final url = '${ApiConfig.baseUrl}/profiles/$profileId/faces';
    debugPrint('[ApiService] POST $url (${imagePaths.length} files)');

    var request = http.MultipartRequest('POST', Uri.parse(url));

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    for (final path in imagePaths) {
      request.files.add(await http.MultipartFile.fromPath('faces', path));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      debugPrint('[ApiService] ${imagePaths.length} face poses uploaded');
    } else {
      final msg =
          jsonDecode(response.body)['error'] ?? 'Failed to upload faces';
      throw ApiException(msg, response.statusCode);
    }
  }

  // ── Mirror ──────────────────────────────────────────────────────────────────

  // Registers (or refreshes) the device's FCM token with the backend so the
  // household can receive push notifications for security alerts.
  Future<void> registerDeviceToken(String token, {String platform = 'android'}) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/devices/token'),
      headers: _headers,
      body: jsonEncode({'token': token, 'platform': platform}),
    );
    _parse(res);
  }

  Future<void> unregisterDeviceToken(String token) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/devices/token'),
      headers: _headers,
      body: jsonEncode({'token': token}),
    );
    _parse(res);
  }

  // Completes a QR pairing handshake initiated by the mirror's sync module.
  // sid and shortCode come from the scanned QR payload.
  // Returns { mirrorId (= mirror public key), deviceToken }.
  Future<Map<String, dynamic>> pairMirror({
    required String sid,
    required String shortCode,
    String phonePublicKey = '',
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/mirrors/pair'),
      headers: _headers,
      body: jsonEncode({
        'sid': sid,
        'shortCode': shortCode,
        'phonePublicKey': phonePublicKey,
      }),
    );
    return _parse(res) as Map<String, dynamic>;
  }

  // Pairs using the 6-character short code shown below the QR on the mirror screen.
  // Use this when the QR can't be scanned (emulator, no camera permission, etc.).
  // Returns { mirrorId, deviceToken }.
  Future<Map<String, dynamic>> pairByCode({
    required String shortCode,
    String phonePublicKey = '',
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/mirrors/pair/code'),
      headers: _headers,
      body: jsonEncode({
        'shortCode': shortCode,
        'phonePublicKey': phonePublicKey,
      }),
    );
    return _parse(res) as Map<String, dynamic>;
  }

  // Tells the mirror (and its polling backend) that this profile is now active.
  // Body: { mirrorId, profileId }
  Future<void> setActiveUser({
    required String mirrorId,
    required int profileId,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/mirrors/active-user'),
      headers: _headers,
      body: jsonEncode({'mirrorId': mirrorId, 'profileId': profileId}),
    );
    _parse(res);
  }

  Future<Profile> setMirrorId(int profileId, String? mirrorId) async {
    final url = '${ApiConfig.baseUrl}/profiles/$profileId/mirror';
    debugPrint('[ApiService] PATCH $url body={"mirrorId": "$mirrorId"}');
    final res = await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode({'mirrorId': mirrorId}),
    );
    debugPrint(
        '[ApiService] setMirrorId response: ${res.statusCode} ${res.body}');
    return Profile.fromJson(_parse(res)['profile']);
  }

  // ── Gmail ───────────────────────────────────────────────────────────────────

  Future<String> getGmailConnectUrl(int profileId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$profileId/gmail/connect'),
      headers: _headers,
    );
    return _parse(res)['url'] as String;
  }

  Future<List<EmailMessage>> getMessages(int profileId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$profileId/gmail/messages'),
      headers: _headers,
    );
    final List data = _parse(res)['messages'];
    return data.map((j) => EmailMessage.fromJson(j)).toList();
  }

  Future<void> disconnectGmail(int profileId) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$profileId/gmail'),
      headers: _headers,
    );
    _parse(res);
  }

  // ── Spotify ─────────────────────────────────────────────────────────────────

  Future<String> getSpotifyConnectUrl(int profileId) async {
    debugPrint(
        '[ApiService] GET ${ApiConfig.baseUrl}/profiles/$profileId/spotify/connect');
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$profileId/spotify/connect'),
      headers: _headers,
    );
    final url = _parse(res)['url'] as String;
    debugPrint('[ApiService] Spotify connect URL: $url');
    return url;
  }

  Future<Map<String, dynamic>> getSpotifyStatus(int profileId) async {
    debugPrint('[ApiService] GET ${ApiConfig.baseUrl}/profiles/$profileId/spotify/status');
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$profileId/spotify/status'),
      headers: _headers,
    );
    final data = _parse(res) as Map<String, dynamic>;
    debugPrint('[ApiService] Spotify status: $data');
    return data;
  }

  Future<Map<String, dynamic>> exchangeSpotifyCode(
      int profileId, String code) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$profileId/spotify/exchange'),
      headers: _headers,
      body: jsonEncode({'code': code}),
    );
    return _parse(res) as Map<String, dynamic>;
  }

  Future<void> disconnectSpotify(int profileId) async {
    debugPrint('[ApiService] DELETE ${ApiConfig.baseUrl}/profiles/$profileId/spotify');
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/profiles/$profileId/spotify'),
      headers: _headers,
    );
    _parse(res);
  }

  // ── AI Settings ─────────────────────────────────────────────────────────────

  Future<AiSettings> getAiSettings() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/ai-settings'),
      headers: _headers,
    );
    final data = _parse(res)['settings'] as Map<String, dynamic>? ?? {};
    return AiSettings.fromJson(data);
  }

  Future<AiSettings> saveAiSettings(AiSettings settings) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/ai-settings'),
      headers: _headers,
      body: jsonEncode({'settings': settings.toJson()}),
    );
    final data = _parse(res)['settings'] as Map<String, dynamic>? ?? {};
    return AiSettings.fromJson(data);
  }
}
