class Profile {
  final int id;
  final int householdId;
  final String name;
  final String? email;
  final String? googleSub;
  final String? mirrorId;
  final String createdAt;
  final bool spotifyConnected;
  final String? spotifyDisplayName;

  Profile({
    required this.id,
    required this.householdId,
    required this.name,
    this.email,
    this.googleSub,
    this.mirrorId,
    required this.createdAt,
    this.spotifyConnected = false,
    this.spotifyDisplayName,
  });

  bool get hasGmail   => email != null && googleSub != null;
  bool get hasSpotify => spotifyConnected;
  bool get hasMirror  => mirrorId != null && mirrorId!.isNotEmpty;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id:                 json['id'],
        householdId:        json['household_id'],
        name:               json['name'],
        email:              json['email'],
        googleSub:          json['google_sub'],
        mirrorId:           json['mirror_id'],
        createdAt:          json['created_at'] ?? '',
        spotifyConnected:   json['spotify_connected'] == true || json['spotify_connected'] == 1,
        spotifyDisplayName: json['spotify_display_name'],
      );
}
