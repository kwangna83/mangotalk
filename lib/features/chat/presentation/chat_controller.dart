import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/chat_constants.dart';
import '../../../core/providers/repository_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/chat_message.dart';
import '../domain/chat_repository.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.roomId,
    this.loadingOlder = false,
    this.hasMore = true,
  });

  final List<ChatMessage> messages;
  final String? roomId;
  final bool loadingOlder;
  final bool hasMore;

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? roomId,
    bool? loadingOlder,
    bool? hasMore,
  }) => ChatState(
    messages: messages ?? this.messages,
    roomId: roomId ?? this.roomId,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    hasMore: hasMore ?? this.hasMore,
  );
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends AsyncNotifier<ChatState> {
  ChatRepository get _repository => ref.read(chatRepositoryProvider);
  ChatSubscription? _subscription;

  @override
  Future<ChatState> build() async {
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    final roomId = await _repository.joinPublicRoom();
    final messages = await _repository.fetchMessages(roomId: roomId);
    _subscription = await _repository.subscribe(
      roomId: roomId,
      onMessage: _merge,
      onConnected: () => unawaited(_catchUp(roomId)),
    );
    return ChatState(
      roomId: roomId,
      messages: _sortedUnique(messages),
      hasMore: messages.length == ChatConstants.pageSize,
    );
  }

  Future<void> loadOlder() async {
    final current = state.value;
    if (current == null || current.loadingOlder || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingOlder: true));
    try {
      final oldest = current.messages.firstOrNull;
      final older = await _repository.fetchMessages(
        roomId: current.roomId!,
        before: oldest == null ? null : MessageCursor.fromMessage(oldest),
      );
      state = AsyncData(
        current.copyWith(
          messages: _sortedUnique([...older, ...current.messages]),
          loadingOlder: false,
          hasMore: older.length == ChatConstants.pageSize,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingOlder: false));
      rethrow;
    }
  }

  Future<void> send(String body, {String? clientMessageId}) async {
    final current = state.value;
    final user = ref.read(authControllerProvider).value;
    final trimmed = body.trim();
    if (current?.roomId == null || user == null || trimmed.isEmpty) return;
    final clientId = clientMessageId ?? const Uuid().v4();
    final optimistic = ChatMessage(
      id: 'local:$clientId',
      roomId: current!.roomId!,
      senderId: user.id,
      senderNickname: user.nickname,
      clientMessageId: clientId,
      body: trimmed,
      createdAt: DateTime.now(),
      status: MessageSendStatus.sending,
    );
    _merge(optimistic);
    try {
      _merge(
        await _repository.sendMessage(
          roomId: current.roomId!,
          clientMessageId: clientId,
          body: trimmed,
        ),
      );
    } catch (_) {
      _replaceStatus(clientId, MessageSendStatus.failed);
    }
  }

  Future<void> retry(ChatMessage message) =>
      send(message.body, clientMessageId: message.clientMessageId);

  void _merge(ChatMessage message) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(messages: _sortedUnique([...current.messages, message])),
    );
  }

  void _replaceStatus(String clientId, MessageSendStatus status) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        messages: current.messages
            .map(
              (m) => m.clientMessageId == clientId
                  ? m.copyWith(status: status)
                  : m,
            )
            .toList(),
      ),
    );
  }

  Future<void> _catchUp(String roomId) async {
    final current = state.value;
    final latest = current?.messages.lastOrNull;
    if (current == null || latest == null) return;
    final missed = await _repository.fetchMessagesAfter(
      roomId: roomId,
      after: MessageCursor.fromMessage(latest),
    );
    for (final message in missed) {
      _merge(message);
    }
  }

  List<ChatMessage> _sortedUnique(Iterable<ChatMessage> values) {
    final byClientId = <String, ChatMessage>{};
    for (final message in values) {
      final previous = byClientId[message.clientMessageId];
      if (previous == null || message.status == MessageSendStatus.sent) {
        byClientId[message.clientMessageId] = message;
      }
    }
    final result = byClientId.values.toList();
    result.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return result;
  }
}
