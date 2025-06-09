import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:predictrix/redux/reducers.dart';
import 'package:predictrix/redux/types/chat_message.dart';
import 'package:predictrix/redux/types/profile.dart';
import 'package:predictrix/screens/assertion_creation_screen.dart';
import 'package:predictrix/utils/navigator.dart';
import 'package:predictrix/utils/socket_service.dart';
import 'package:predictrix/widgets/back_widget.dart';
import 'package:predictrix/widgets/message_widget.dart';

class ChatPage extends StatefulWidget {
  const ChatPage(
      {super.key,
      required this.name,
      required this.chatId,
      required this.iconColor});

  final String name;
  final String chatId;
  final Color iconColor;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const Back(),
          title: Row(children: [
            Hero(
              tag: "icon-${widget.chatId}",
              child: Material(
                color: Colors.transparent,
                child: CircleAvatar(
                  backgroundColor: widget.iconColor,
                  child: const Icon(Icons.group),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Hero(
              tag: "title-${widget.chatId}",
              child: Material(
                color: Colors.transparent,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Spacer(),
            const Icon(Icons.menu, size: 16),
          ])),
      body: Column(
        children: [
          Expanded(
            child: StoreConnector<AppState, List<ChatMessage>>(
              distinct: true,
              converter: (store) =>
                  store.state.chatMessages[widget.chatId] ?? [],
              builder: (context, messages) {
                return Scrollbar(
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: messages
                          .map(
                            (msg) => MessageWidget(
                              name: msg.sender.displayName,
                              message: Text(
                                msg.message,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              photoUrl: msg.sender.photoUrl,
                              timestamp: msg.timestamp,
                              verified: false,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: StoreConnector<AppState, bool>(
              distinct: true,
              converter: (store) => store.state.isMessageSending,
              builder: (context, isMessageSending) => Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 6,
                    minLines: 1,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Send a message...',
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Hero(
                  tag: 'send-assertion-${widget.chatId}',
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton.outlined(
                      onPressed: () {
                        NavigatorUtils.navigateTo(context,
                            AssertionCreationScreen(chatId: widget.chatId));
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ),
                if (isMessageSending)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_controller.text.isNotEmpty)
                  IconButton.filled(
                    onPressed: () {
                      final text = _controller.text;
                      if (text.trim().isNotEmpty) {
                        debugPrint('Sending message: $text');

                        // StoreProvider.of<AppState>(context)
                        //     .dispatch(SetIsMessageSendingAction(true));
                        SocketService()
                            .send("sndm${widget.chatId} ${text.trim()}");

                        StoreProvider.of<AppState>(context).dispatch(
                          AddChatMessageAction(
                            widget.chatId,
                            ChatMessage(
                              sender: Profile(
                                  displayName: FirebaseAuth
                                          .instance.currentUser?.displayName ??
                                      'You',
                                  photoUrl: FirebaseAuth
                                          .instance.currentUser?.photoURL ??
                                      ''),
                              message: text.trim(),
                              timestamp: DateTime.now(),
                              iconColor: widget.iconColor,
                            ),
                          ),
                        );

                        _controller.clear();
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.send),
                  )
                else
                  const IconButton.outlined(
                    onPressed: null,
                    icon: Icon(Icons.send),
                  ),
              ]),
            ),
          )
        ],
      ),
    );
  }
}
