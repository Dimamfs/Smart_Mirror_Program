import 'dart:convert';
import '../config/api.dart';

class Profile {
  final int id;
  final int householdId;
  final String name;
  final String? email;
  final String? googleSub;
  final String? mirrorId;
  final String? faceFilename;
  final String createdAt;
  final bool spotifyConnected;
  final String? spotifyDisplayName;
  final Map<String, dynamic>? widgetsConfig;

  Profile({
    required this.id,
    required this.householdId,
    required this.name,
    this.email,
    this.googleSub,
    this.mirrorId,
    this.faceFilename,
    required this.createdAt,
    this.spotifyConnected = false,
    this.spotifyDisplayName,
    this.widgetsConfig,
  });

  bool get hasGmail => email != null && googleSub != null;
  bool get hasSpotify => spotifyConnected;
  bool get hasMirror => mirrorId != null && mirrorId!.isNotEmpty;

  // Derives the face image URL from kBaseUrl so changing the IP in config/api.dart
  // automatically fixes this too (emulator: 10.0.2.2, physical: LAN IP of the server).
  String? get faceUrl {
    if (faceFilename == null) return null;
    // kBaseUrl ends with "/api", strip that suffix to get the server root.
    final serverRoot = kBaseUrl.endsWith('/api')
        ? kBaseUrl.substring(0, kBaseUrl.length - 4)
        : kBaseUrl;
    return '$serverRoot/faces/$faceFilename';
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'],
        householdId: json['household_id'],
        name: json['name'],
        email: json['email'],
        googleSub: json['google_sub'],
        mirrorId: json['mirror_id'],
        faceFilename: json['face_filename'],
        createdAt: json['created_at'] ?? '',
        spotifyConnected:
            json['spotify_connected'] == true || json['spotify_connected'] == 1,
        spotifyDisplayName: json['spotify_display_name'],
        widgetsConfig: _parseWidgetsConfig(json['widgets_config']),
      );

  // widgets_config may arrive as a JSON string (SQLite TEXT column) or as an
  // already-decoded object. Handle both, and never throw on bad data.
  static Map<String, dynamic>? _parseWidgetsConfig(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
