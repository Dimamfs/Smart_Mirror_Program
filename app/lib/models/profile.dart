class Profile {
  final int id;
  final int householdId;
  final String name;
  final String? email;
  final String? googleSub;
  final String createdAt;

  Profile({
    required this.id,
    required this.householdId,
    required this.name,
    this.email,
    this.googleSub,
    required this.createdAt,
  });

  bool get hasGmail => email != null && googleSub != null;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'],
        householdId: json['household_id'],
        name: json['name'],
        email: json['email'],
        googleSub: json['google_sub'],
        createdAt: json['created_at'] ?? '',
      );
}
