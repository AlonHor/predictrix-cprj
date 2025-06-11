import 'package:predictrix/redux/types/assertion.dart';
import 'package:predictrix/redux/types/profile.dart';

class ChatMessage {
  final Profile sender;
  late dynamic message;
  final DateTime timestamp;
  final String type;

  ChatMessage({
    required this.sender,
    required this.message,
    required this.timestamp,
    this.type = 'text',
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'assertion') {
      return ChatMessage(
        sender: Profile.fromJson(json['sender']),
        message: Assertion.fromJson(json['content']),
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: 'assertion',
      );
    } else {
      return ChatMessage(
        sender: Profile.fromJson(json['sender']),
        message: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
    }
  }
}
