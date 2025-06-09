import 'package:flutter/material.dart';
import 'package:predictrix/redux/types/chat_message.dart';
import 'package:predictrix/redux/types/chat_tile.dart';

class SetIsMessageSendingAction {
  final bool isSending;

  SetIsMessageSendingAction(this.isSending);
}

class SetChatsAction {
  final List<ChatTile> chats;

  SetChatsAction(this.chats);
}

class SetChatMessagesAction {
  final String chatId;
  final List<ChatMessage> messages;

  SetChatMessagesAction(this.chatId, this.messages);
}

class AddChatMessageAction {
  final String chatId;
  final ChatMessage message;

  AddChatMessageAction(this.chatId, this.message);
}

List<ChatTile> chatsReducer(List<ChatTile> state, dynamic action) {
  if (action is SetChatsAction) {
    return action.chats;
  }
  return state;
}

Map<String, List<ChatMessage>> chatMessagesReducer(
    Map<String, List<ChatMessage>> state, dynamic action) {
  if (action is SetChatMessagesAction) {
    return {
      ...state,
      action.chatId: action.messages,
    };
  } else if (action is AddChatMessageAction) {
    final prevMessages = state[action.chatId] ?? [];
    return {
      ...state,
      action.chatId: List.from(prevMessages)..add(action.message),
    };
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
  final Map<String, List<ChatMessage>> chatMessages;
  final bool isConnected;
  final bool isMessageSending;

  const AppState(
      {this.chats = const [],
      this.chatMessages = const {},
      this.isConnected = false,
      this.isMessageSending = false});

  AppState copyWith(
      {List<ChatTile>? chats,
      bool? isConnected,
      Map<String, List<ChatMessage>>? chatMessages,
      bool? isMessageSending}) {
    return AppState(
      chats: chats ?? this.chats,
      isConnected: isConnected ?? this.isConnected,
      chatMessages: chatMessages ?? this.chatMessages,
      isMessageSending: isMessageSending ?? this.isMessageSending,
    );
  }
}

AppState appReducer(AppState state, dynamic action) {
  return AppState(
    chats: chatsReducer(state.chats, action),
    chatMessages: chatMessagesReducer(
      state.chatMessages,
      action,
    ),
    isConnected: action is SetConnectionStatusAction
        ? action.isConnected
        : state.isConnected,
    isMessageSending: action is SetIsMessageSendingAction
        ? action.isSending
        : state.isMessageSending,
  );
}
