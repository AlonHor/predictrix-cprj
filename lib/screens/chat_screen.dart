import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:predictrix/redux/reducers.dart';
import 'package:predictrix/redux/types/assertion.dart';
import 'package:predictrix/redux/types/chat_message.dart';
import 'package:predictrix/redux/types/member.dart';
import 'package:predictrix/redux/types/profile.dart';
import 'package:predictrix/screens/assertion_creation_screen.dart';
import 'package:predictrix/utils/navigator.dart';
import 'package:predictrix/utils/socket_service.dart';
import 'package:predictrix/widgets/assertion_widget.dart';
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

  List<Widget> _buildMessagesWithDateSeparators(List<ChatMessage> messages) {
    List<Widget> messageWidgets = [];
    DateTime? lastDate;

    // Sort messages by timestamp (oldest to newest)
    final sortedMessages = List<ChatMessage>.from(messages);
    sortedMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (var message in sortedMessages) {
      // Convert to local time zone and get date portion only
      final DateTime localDateTime = message.timestamp.toLocal();
      final DateTime messageDate = DateTime(
        localDateTime.year,
        localDateTime.month,
        localDateTime.day,
      );

      // Check if we need to add a date separator
      if (lastDate == null ||
          messageDate.year != lastDate.year ||
          messageDate.month != lastDate.month ||
          messageDate.day != lastDate.day) {
        lastDate = messageDate;

        // Add a date separator widget
        messageWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const Expanded(child: Divider(color: Colors.white24)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    _formatDate(messageDate),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
          ),
        );
      }

      final String messageType = message.type;

      if (messageType == "text") {
        messageWidgets.add(
          MessageWidget(
            name: message.sender.displayName,
            message: SelectableText(
              message.message as String,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            photoUrl: message.sender.photoUrl,
            timestamp: message.timestamp,
            verified: false,
          ),
        );
      } else if (messageType == "assertion") {
        final String assertionId = message.message as String;
        final Assertion? content =
            StoreProvider.of<AppState>(context).state.assertions[assertionId];
        if (content == null) {
          messageWidgets.add(
            MessageWidget(
              name: message.sender.displayName,
              message: Text(
                "Assertion not found: $assertionId",
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
              photoUrl: message.sender.photoUrl,
              timestamp: message.timestamp,
              verified: false,
            ),
          );
          continue;
        } else {
          messageWidgets.add(
            MessageWidget(
              name: message.sender.displayName,
              message: StoreConnector<AppState, Assertion>(
                distinct: true,
                converter: (store) => store.state.assertions[assertionId]!,
                builder: (context, assertion) =>
                    AssertionWidget(assertion: assertion),
              ),
              photoUrl: message.sender.photoUrl,
              timestamp: message.timestamp,
              verified: false,
            ),
          );
        }
      }
    }

    return messageWidgets;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Today';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    } else {
      // Format: June 10, 2025
      return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1]; // month is 1-based, array is 0-based
  }

  void _showMembersDialog() {
    SocketService().send("memb${widget.chatId}");
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.blueGrey[800],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: StoreConnector<AppState, List<Member>>(
              distinct: true,
              converter: (store) => store.state.members[widget.chatId] ?? [],
              builder: (context, members) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, right: 4),
                      child: Row(
                        children: [
                          Text(
                            'Members of ${widget.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon:
                                const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    members.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white70),
                              ),
                            ),
                          )
                        : Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              itemCount: members.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(color: Colors.white12),
                              itemBuilder: (context, index) {
                                final member = members[index];
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      // Profile photo
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage:
                                            member.photoUrl.isNotEmpty
                                                ? NetworkImage(member.photoUrl)
                                                : null,
                                        backgroundColor: Colors.blueGrey[600],
                                        child: member.photoUrl.isEmpty
                                            ? Text(
                                                member.displayName.isNotEmpty
                                                    ? member.displayName[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),

                                      // Name and member info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              member.displayName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // ELO score
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey[700],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.equalizer,
                                              color: Colors.white70,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'ELO: ${member.elo}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                    members.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                minimumSize: const Size(double.infinity, 44),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: const Back(),
          title: GestureDetector(
              onTap: _showMembersDialog,
              child: Row(children: [
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
                IconButton(
                  icon: const Icon(Icons.link, size: 20),
                  onPressed: () {
                    SocketService().send("cjtk${widget.chatId}");
                  },
                  tooltip: 'Copy join link',
                ),
              ]))),
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
                      children: _buildMessagesWithDateSeparators(messages),
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
                      icon: const Icon(Icons.route),
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

                      String displayName =
                          StoreProvider.of<AppState>(context).state.displayName;
                      if (displayName.trim().isEmpty) {
                        displayName = 'Unknown User';
                      }

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
                                  displayName: displayName,
                                  photoUrl: FirebaseAuth
                                          .instance.currentUser?.photoURL ??
                                      ''),
                              message: text.trim(),
                              timestamp: DateTime.now().toLocal(),
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
