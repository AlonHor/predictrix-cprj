class Vote {
  final String displayName;
  final String photoUrl;
  final bool vote;

  Vote({
    required this.displayName,
    required this.photoUrl,
    required this.vote,
  });

  factory Vote.fromJson(Map<String, dynamic> json) {
    return Vote(
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String,
      vote: json['vote'] as bool,
    );
  }
}
