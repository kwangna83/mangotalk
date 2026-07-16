import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/chat_constants.dart';
import '../domain/chat_message.dart';
import '../domain/chat_repository.dart';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> joinPublicRoom() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('로그인이 필요합니다.');
    await _client
        .from('room_members')
        .upsert(
          {'room_id': ChatConstants.publicRoomId, 'user_id': user.id},
          onConflict: 'room_id,user_id',
          ignoreDuplicates: true,
        );
    return ChatConstants.publicRoomId;
  }

  @override
  Future<List<ChatMessage>> fetchMessages({
    required String roomId,
    MessageCursor? before,
    int limit = 50,
  }) async {
    final rows = await _client.rpc(
      'get_room_messages',
      params: {
        'p_room_id': roomId,
        'p_before_created_at': before?.createdAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
        'p_limit': limit,
      },
    );
    return _messages(rows);
  }

  @override
  Future<List<ChatMessage>> fetchMessagesAfter({
    required String roomId,
    required MessageCursor after,
  }) async {
    final rows = await _client.rpc(
      'get_room_messages_after',
      params: {
        'p_room_id': roomId,
        'p_after_created_at': after.createdAt.toUtc().toIso8601String(),
        'p_after_id': after.id,
      },
    );
    return _messages(rows);
  }

  @override
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String clientMessageId,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('로그인이 필요합니다.');
    final row = await _client
        .from('messages')
        .upsert({
          'room_id': roomId,
          'sender_id': user.id,
          'client_message_id': clientMessageId,
          'body': body.trim(),
        }, onConflict: 'sender_id,client_message_id')
        .select('*, profiles!messages_sender_id_fkey(nickname)')
        .single();
    return _message(row);
  }

  @override
  Future<ChatSubscription> subscribe({
    required String roomId,
    required MessageListener onMessage,
    required ConnectionListener onConnected,
  }) async {
    final channel = _client
        .channel('room:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) async {
            final id = payload.newRecord['id'] as String?;
            if (id == null) return;
            final row = await _client
                .from('messages')
                .select('*, profiles!messages_sender_id_fkey(nickname)')
                .eq('id', id)
                .single();
            onMessage(_message(row));
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) onConnected();
        });
    return _SupabaseChatSubscription(_client, channel);
  }

  List<ChatMessage> _messages(dynamic rows) => (rows as List)
      .map((row) => _message(Map<String, dynamic>.from(row as Map)))
      .toList();

  ChatMessage _message(Map<String, dynamic> row) {
    final profile = row['profiles'];
    return ChatMessage.fromJson({
      ...row,
      'sender_nickname': profile is Map ? profile['nickname'] : null,
    });
  }
}

class _SupabaseChatSubscription implements ChatSubscription {
  _SupabaseChatSubscription(this._client, this._channel);

  final SupabaseClient _client;
  final RealtimeChannel _channel;

  @override
  Future<void> cancel() => _client.removeChannel(_channel);
}
