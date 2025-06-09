import 'package:flutter/material.dart';
import 'package:predictrix/redux/types/profile.dart';

class ChatMessage {
  final Profile sender;
  final String message;
  final Color iconColor;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.message,
    required this.iconColor,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      sender: Profile.fromJson(json['sender']),
      message: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      iconColor: Colors.blue,
    );
  }
}
