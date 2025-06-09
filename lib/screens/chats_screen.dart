import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:predictrix/redux/reducers.dart';
import 'package:predictrix/redux/types/chat_tile.dart';
import 'package:predictrix/widgets/back_widget.dart';
import 'package:predictrix/widgets/chat_list_tile_widget.dart';

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, List<ChatTile>>(
      distinct: true,
      converter: (store) => store.state.chats,
      builder: (context, chats) {
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
          body: ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ChatListTile(
                  name: chat.name,
                  lastMessage: chat.lastMessage,
                  chatId: chat.chatId,
                  iconColor: Colors.blue,
                  onPop: () {});
            },
          ),
        );
      },
    );
  }
}
