class Profile {
  final String displayName;
  final String photoUrl;

  Profile({
    required this.displayName,
    required this.photoUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String,
    );
  }
}
