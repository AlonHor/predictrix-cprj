class Member {
  final String displayName;
  final String photoUrl;
  final int elo;

  Member({
    required this.displayName,
    required this.photoUrl,
    required this.elo,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String,
      elo: json['elo'] as int,
    );
  }
}
