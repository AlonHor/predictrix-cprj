import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:predictrix/utils/socket_service.dart';
import 'package:predictrix/widgets/back_widget.dart';
import 'package:predictrix/widgets/chat_list_tile_widget.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

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
      iconColor: Colors.blue, // Color(json['iconColor'] as int),
    );
  }
}

class _ChatsPageState extends State<ChatsPage> {
  List<ChatTile> chats = [];
  late final StreamSubscription _subscription;

  @override
  void initState() {
    print("Initializing ChatsPage");
    super.initState();

    SocketService().send("chts");
    _subscription = SocketService().onData.listen((data) {
      print("Received data: $data");
      if (mounted) {
        setState(() {
          chats = (jsonDecode(data) as List)
              .map((item) => ChatTile.fromJson(item as Map<String, dynamic>))
              .toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const Back(),
          title: const Row(children: [
            Hero(
                tag: "chats-icon",
                child: Material(
                    color: Colors.transparent,
                    child: Icon(Icons.chat, size: 32))),
            SizedBox(width: 16),
            Text("Chats")
          ])),
      body: Column(children: [
        for (int i = 0; i < chats.length; i++)
          ChatListTile(
            name: chats[i].name,
            lastMessage: chats[i].lastMessage,
            chatId: "chat_${chats[i].chatId}",
            iconColor: i % 2 == 0 ? Colors.blue : Colors.red,
          ),
      ]),
    );
  }
}
