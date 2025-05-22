import 'package:flutter/material.dart';
import 'package:predictrix/widgets/back_widget.dart';
import 'package:predictrix/widgets/chat_list_tile_widget.dart';

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

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
      body: const Column(children: [
        ...[
          ChatListTile(
            name: "Friends Group",
            lastMessage: "Sam: How about something funny? I could use a laugh.",
            chatId: "a1b2c3",
            iconColor: Colors.blue,
          ),
          ChatListTile(
            name: "Family",
            lastMessage: "Kid: Hey!",
            chatId: "a2b3c4",
            iconColor: Colors.red,
          ),
          // ChatListTile(
          //   name: "Very Long Group Name For Testing Purposes",
          //   lastMessage: "Sam: How about something funny? I could use a laugh.",
          //   chatId: "a3b4c5",
          //   iconColor: Colors.green,
          // ),
        ],
      ]),
    );
  }
}
