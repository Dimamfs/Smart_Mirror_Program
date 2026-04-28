import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api.dart';
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

  // Parses the response and throws ApiException on non-2xx
  dynamic _parse(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = body['error'] ?? 'Unknown error';
    throw ApiException(msg, res.statusCode);
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  Future<Household> createHousehold(String name) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/households'),
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
      Uri.parse('$kBaseUrl/auth/register'),
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
      Uri.parse('$kBaseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parse(res);
  }

  // ── Profiles ────────────────────────────────────────────────────────────────

  Future<List<Profile>> listProfiles() async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/profiles'),
      headers: _headers,
    );
    final List data = _parse(res)['profiles'];
    return data.map((j) => Profile.fromJson(j)).toList();
  }

  Future<Profile> getProfile(int id) async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/profiles/$id'),
      headers: _headers,
    );
    return Profile.fromJson(_parse(res)['profile']);
  }

  Future<Profile> createProfile({required String name, String? email}) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/profiles'),
      headers: _headers,
      body: jsonEncode({'name': name, if (email != null) 'email': email}),
    );
    return Profile.fromJson(_parse(res)['profile']);
  }

  Future<void> deleteProfile(int profileId) async {
    final res = await http.delete(
      Uri.parse('$kBaseUrl/profiles/$profileId'),
      headers: _headers,
    );
    _parse(res);
  }

  // ── Face Setup ──────────────────────────────────────────────────────────────

  Future<void> uploadFace(int profileId, String imagePath) async {
    final url = '$kBaseUrl/profiles/$profileId/face';
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

  // ── Mirror ──────────────────────────────────────────────────────────────────

  Future<Profile> setMirrorId(int profileId, String? mirrorId) async {
    final url = '$kBaseUrl/profiles/$profileId/mirror';
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
      Uri.parse('$kBaseUrl/profiles/$profileId/gmail/connect'),
      headers: _headers,
    );
    return _parse(res)['url'] as String;
  }

  Future<List<EmailMessage>> getMessages(int profileId) async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/profiles/$profileId/gmail/messages'),
      headers: _headers,
    );
    final List data = _parse(res)['messages'];
    return data.map((j) => EmailMessage.fromJson(j)).toList();
  }

  Future<void> disconnectGmail(int profileId) async {
    final res = await http.delete(
      Uri.parse('$kBaseUrl/profiles/$profileId/gmail'),
      headers: _headers,
    );
    _parse(res);
  }

  // ── Spotify ─────────────────────────────────────────────────────────────────

  Future<String> getSpotifyConnectUrl(int profileId) async {
    debugPrint(
        '[ApiService] GET $kBaseUrl/profiles/$profileId/spotify/connect');
    final res = await http.get(
      Uri.parse('$kBaseUrl/profiles/$profileId/spotify/connect'),
      headers: _headers,
    );
    final url = _parse(res)['url'] as String;
    debugPrint('[ApiService] Spotify connect URL: $url');
    return url;
  }

  Future<Map<String, dynamic>> getSpotifyStatus(int profileId) async {
    debugPrint('[ApiService] GET $kBaseUrl/profiles/$profileId/spotify/status');
    final res = await http.get(
      Uri.parse('$kBaseUrl/profiles/$profileId/spotify/status'),
      headers: _headers,
    );
    final data = _parse(res) as Map<String, dynamic>;
    debugPrint('[ApiService] Spotify status: $data');
    return data;
  }

  Future<void> disconnectSpotify(int profileId) async {
    debugPrint('[ApiService] DELETE $kBaseUrl/profiles/$profileId/spotify');
    final res = await http.delete(
      Uri.parse('$kBaseUrl/profiles/$profileId/spotify'),
      headers: _headers,
    );
    _parse(res);
  }
}
