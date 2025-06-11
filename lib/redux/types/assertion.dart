import 'package:predictrix/redux/types/prediction.dart';
import 'package:predictrix/redux/types/vote.dart';

class Assertion {
  final String id;
  final String text;
  final List<Prediction> predictions;
  final List<Vote> votes;
  final DateTime validationDate;
  final DateTime castingForecastDeadline;
  late bool? didPredict;
  final bool completed;
  final bool finalAnswer;

  Assertion({
    required this.id,
    required this.text,
    required this.predictions,
    required this.votes,
    required this.validationDate,
    required this.castingForecastDeadline,
    required this.didPredict,
    required this.completed,
    required this.finalAnswer,
  });

  factory Assertion.fromJson(Map<String, dynamic> json) {
    return Assertion(
      id: json['id'] as String,
      text: json['text'] as String,
      predictions: (json['predictions'] as List<dynamic>)
          .map((prediction) =>
              Prediction.fromJson(prediction as Map<String, dynamic>))
          .toList(),
      votes: (json['votes'] as List<dynamic>?)
              ?.map((vote) => Vote.fromJson(vote as Map<String, dynamic>))
              .toList() ??
          [],
      validationDate: DateTime.parse(json['validationDate'] as String),
      castingForecastDeadline:
          DateTime.parse(json['castingForecastDeadline'] as String),
      didPredict: json['didPredict'] as bool?,
      completed: json['completed'] as bool,
      finalAnswer: json['finalAnswer'] as bool,
    );
  }
}
