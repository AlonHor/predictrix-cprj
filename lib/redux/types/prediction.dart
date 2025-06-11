class Prediction {
  final String displayName;
  final String photoUrl;
  final double confidence;
  final bool forecast;

  Prediction({
    required this.displayName,
    required this.photoUrl,
    required this.confidence,
    required this.forecast,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String,
      confidence: json['confidence'] as double,
      forecast: json['forecast'] as bool,
    );
  }
}
