import 'package:flutter/material.dart';

class ChatMessage {
  final String sender;
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
      sender: json['sender'] as String,
      message: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      iconColor: Colors.blue,
    );
  }
}

