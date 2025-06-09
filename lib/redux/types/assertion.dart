class Assertion {
  final String id;
  final String text;
  final DateTime validationDate;
  final DateTime castingForecastDeadline;
  final bool completed;
  final bool finalAnswer;

  Assertion({
    required this.id,
    required this.text,
    required this.validationDate,
    required this.castingForecastDeadline,
    required this.completed,
    required this.finalAnswer,
  });

  factory Assertion.fromJson(Map<String, dynamic> json) {
    return Assertion(
      id: json['id'] as String,
      text: json['text'] as String,
      validationDate: DateTime.parse(json['validationDate'] as String),
      castingForecastDeadline:
          DateTime.parse(json['castingForecastDeadline'] as String),
      completed: json['completed'] as bool,
      finalAnswer: json['finalAnswer'] as bool,
    );
  }
}
