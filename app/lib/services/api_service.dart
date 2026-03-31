import 'dart:convert';
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
}
