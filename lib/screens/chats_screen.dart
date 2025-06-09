import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:predictrix/redux/reducers.dart';
import 'package:predictrix/redux/types/chat_tile.dart';
import 'package:predictrix/utils/socket_service.dart';
import 'package:predictrix/widgets/back_widget.dart';
import 'package:predictrix/widgets/chat_list_tile_widget.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  @override
  void initState() {
    super.initState();

    SocketService().send("chts");
  }

  @override
  Widget build(BuildContext context) {
    TextEditingController inviteController = TextEditingController();
    return StoreConnector<AppState, List<ChatTile>>(
      distinct: true,
      converter: (store) => store.state.chats,
      builder: (context, chats) {
        return Scaffold(
          appBar: AppBar(
            leading: const Back(),
            title: const Row(
              children: [
                Hero(
                  tag: "chats-icon",
                  child: Material(
                    color: Colors.transparent,
                    child: Icon(Icons.chat, size: 32),
                  ),
                ),
                SizedBox(width: 16),
                Text("Chats")
              ],
            ),
          ),
          body: ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ChatListTile(
                name: chat.name,
                lastMessage: chat.lastMessage,
                chatId: chat.chatId,
                iconColor: Colors.blue,
                onPop: () {
                  SocketService().send("chts");
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Choose Action'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Create Chat'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Show dialog to enter chat name
                            final chatNameController = TextEditingController();
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Create New Chat'),
                                  content: TextField(
                                    controller: chatNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Chat Name',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.chat),
                                      filled: false,
                                    ),
                                    autofocus: true,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        final name = chatNameController.text.trim();
                                        if (name.isNotEmpty) {
                                          SocketService().send("crtc$name");
                                          Navigator.of(context).pop();
                                        }
                                      },
                                      child: const Text('Create'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.input),
                          label: const Text('Join Chat'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Join with Invite Token'),
                                  content: TextField(
                                    controller: inviteController,
                                    decoration: InputDecoration(
                                      labelText: 'Invite Token',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      prefixIcon: const Icon(Icons.vpn_key),
                                      filled: false,
                                    ),
                                    autofocus: true,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        final token = inviteController.text.trim();
                                        if (token.isNotEmpty) {
                                          SocketService().send('join$token');
                                        }
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Join'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: const Icon(Icons.add, size: 32),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
        );
      },
    );
  }
}
