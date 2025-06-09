import 'package:flutter/material.dart';

class ChatTile {
  final String name;
  final String lastMessage;
  final String chatId;
  final Color iconColor;

  ChatTile({
    required this.name,
    required this.lastMessage,
    required this.chatId,
    required this.iconColor,
  });

  factory ChatTile.fromJson(Map<String, dynamic> json) {
    return ChatTile(
      name: json['name'] as String,
      lastMessage: json['lastMessage'] as String,
      chatId: json['chatId'] as String,
      iconColor: Colors.blue,
    );
  }
}

