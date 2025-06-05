import 'package:flutter/material.dart';
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
            child: Scrollbar(
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    MessageWidget(
                      name: "A Random Dude",
                      message: const Text(
                        "This is a pretty long message. Like, I could talk here for hours about how long this message is. I mean, seriously, who even reads this?",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.green,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 0),
                      verified: true,
                    ),
                    MessageWidget(
                      name: "Alon",
                      message: const Text(
                        "Nah, I don't think so. I mean, who even reads this?",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.red,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 1),
                      verified: true,
                    ),
                    // MessageWidget(
                    //   name: "Alon",
                    //   message: PredictionWidget(prediction: "This is a prediction"),
                    //   iconColor: Colors.red,
                    // ),
                    MessageWidget(
                      name: "Jane",
                      message: const Text(
                        "Hey everyone! How's it going?",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.blue,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 2),
                    ),
                    MessageWidget(
                      name: "Mike",
                      message: const Text(
                        "I'm doing well, thanks for asking!",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.orange,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 3),
                    ),
                    MessageWidget(
                      name: "Sara",
                      message: const Text(
                        "Did anyone see the game last night?",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.purple,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 4),
                      verified: true,
                    ),
                    MessageWidget(
                      name: "Tom",
                      message: const Text(
                        "Yeah, it was amazing! Can't believe that final score.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.teal,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 5),
                    ),
                    MessageWidget(
                      name: "Linda",
                      message: const Text(
                        "I'm just here for the snacks.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.pink,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 6),
                      verified: true,
                    ),
                    MessageWidget(
                      name: "Alex",
                      message: const Text(
                        "Count me in!",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.cyan,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 7),
                      verified: true,
                    ),
                    MessageWidget(
                      name: "Nina",
                      message: const Text(
                        "What movie are we watching?",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.indigo,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 8),
                    ),
                    MessageWidget(
                      name: "John",
                      message: const Text(
                        "Yes.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.red,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 8),
                    ),
                    MessageWidget(
                      name: "Sam",
                      message: const Text(
                        "How about something funny? I could use a laugh.",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.green,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 9),
                      verified: true,
                    ),
                    MessageWidget(
                      name: "Razon",
                      message: const Text(
                        "Chicken Jockey",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      iconColor: Colors.teal,
                      timestamp: DateTime.utc(2023, 10, 1, 12, 9),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
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
                IconButton.outlined(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton.filled(
                    onPressed: () {
                      final text = _controller.text;
                      if (text.trim().isNotEmpty) {
                        debugPrint('Sending: $text');
                        _controller.clear();
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.send),
                  )
                else
                  IconButton.outlined(
                    onPressed: () {},
                    icon: const Icon(Icons.send),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
