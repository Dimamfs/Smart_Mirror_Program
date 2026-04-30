import 'dart:convert';

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

  // Assuming you are running on an Android emulator.
  // Change 10.0.2.2 to localhost for web/iOS, or your computer's local IP for physical devices.
  String? get faceUrl =>
      faceFilename != null ? 'http://10.0.2.2:3000/faces/$faceFilename' : null;

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
        // This is where jsonDecode is used!
        widgetsConfig: json['widgets_config'] != null
            ? jsonDecode(json['widgets_config'])
            : null,
      );
}
