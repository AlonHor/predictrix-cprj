import 'package:flutter/material.dart';
import 'package:predictrix/screens/chat_screen.dart';
import 'package:predictrix/utils/navigator.dart';

const chatTitleTextStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.normal,
);

class ChatListTile extends StatelessWidget {
  const ChatListTile(
      {super.key,
      required this.name,
      required this.lastMessage,
      required this.chatId,
      required this.iconColor});

  final String name;
  final String lastMessage;
  final String chatId;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Hero(
        tag: "icon-$chatId",
        child: Material(
          color: Colors.transparent,
          child: CircleAvatar(
            backgroundColor: iconColor,
            child: const Icon(Icons.group),
          ),
        ),
      ),
      title: Hero(
        tag: "title-$chatId",
        child: Material(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ),
      subtitle: Text(
        lastMessage,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        NavigatorUtils.navigateTo(context,
            ChatPage(name: name, chatId: chatId, iconColor: iconColor));
      },
    );
  }
}
