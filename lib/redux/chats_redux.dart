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

class SetChatsAction {
  final List<ChatTile> chats;
  SetChatsAction(this.chats);
}

List<ChatTile> chatsReducer(List<ChatTile> state, dynamic action) {
  if (action is SetChatsAction) {
    return action.chats;
  }
  return state;
}

class SetConnectionStatusAction {
  final bool isConnected;
  SetConnectionStatusAction(this.isConnected);
}

@immutable
class AppState {
  final List<ChatTile> chats;
  final bool isConnected;
  const AppState({this.chats = const [], this.isConnected = false});

  AppState copyWith({List<ChatTile>? chats, bool? isConnected}) {
    return AppState(
      chats: chats ?? this.chats,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

// Main App Reducer
AppState appReducer(AppState state, dynamic action) {
  return AppState(
    chats: chatsReducer(state.chats, action),
    isConnected: action is SetConnectionStatusAction
        ? action.isConnected
        : state.isConnected,
  );
}
