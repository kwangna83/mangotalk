import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/chat_constants.dart';
import '../domain/chat_message.dart';
import '../domain/chat_repository.dart';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;
  static const _imageBucket = 'chat-images';

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
    return _messagesWithUrls(rows);
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
    return _messagesWithUrls(rows);
  }

  @override
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String clientMessageId,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('로그인이 필요합니다.');
    final row =
        await _client
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
  Future<ChatMessage> sendImage({
    required String roomId,
    required String clientMessageId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('로그인이 필요합니다.');
    final extension = _extensionFor(mimeType);
    final storagePath = '$roomId/${user.id}/$clientMessageId/image.$extension';
    var uploaded = false;
    try {
      await _client.storage
          .from(_imageBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );
      uploaded = true;
      final messageId = await _client.rpc(
        'create_image_message',
        params: {
          'p_room_id': roomId,
          'p_client_message_id': clientMessageId,
          'p_storage_path': storagePath,
          'p_mime_type': mimeType,
          'p_size_bytes': bytes.length,
        },
      );
      return _fetchMessage(messageId as String);
    } on StorageException catch (error) {
      if (error.statusCode == '409' ||
          error.message.contains('already exists')) {
        final messageId = await _client.rpc(
          'create_image_message',
          params: {
            'p_room_id': roomId,
            'p_client_message_id': clientMessageId,
            'p_storage_path': storagePath,
            'p_mime_type': mimeType,
            'p_size_bytes': bytes.length,
          },
        );
        return _fetchMessage(messageId as String);
      }
      rethrow;
    } catch (_) {
      if (uploaded) {
        try {
          await _client.storage.from(_imageBucket).remove([storagePath]);
        } catch (_) {
          // A periodic cleanup can remove an orphan if best-effort cleanup fails.
        }
      }
      rethrow;
    }
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
            final row =
                await _client
                    .from('messages')
                    .select(
                      '*, profiles!messages_sender_id_fkey(nickname), '
                      'message_attachments(*)',
                    )
                    .eq('id', id)
                    .single();
            onMessage(await _messageWithUrl(row));
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) onConnected();
        });
    return _SupabaseChatSubscription(_client, channel);
  }

  Future<List<ChatMessage>> _messagesWithUrls(dynamic rows) => Future.wait(
    (rows as List).map(
      (row) => _messageWithUrl(Map<String, dynamic>.from(row as Map)),
    ),
  );

  Future<ChatMessage> _fetchMessage(String id) async {
    final row =
        await _client
            .from('messages')
            .select(
              '*, profiles!messages_sender_id_fkey(nickname), '
              'message_attachments(*)',
            )
            .eq('id', id)
            .single();
    return _messageWithUrl(row);
  }

  Future<ChatMessage> _messageWithUrl(Map<String, dynamic> row) async {
    final attachments = row['message_attachments'];
    final Map<String, dynamic>? attachment;
    if (attachments is Map) {
      attachment = Map<String, dynamic>.from(attachments);
    } else if (attachments is List && attachments.isNotEmpty) {
      attachment = Map<String, dynamic>.from(attachments.first as Map);
    } else {
      attachment = null;
    }
    final path =
        (row['attachment_path'] ?? attachment?['storage_path']) as String?;
    String? imageUrl;
    if (path != null) {
      imageUrl = await _client.storage
          .from(
            (row['attachment_bucket'] ??
                    attachment?['storage_bucket'] ??
                    _imageBucket)
                as String,
          )
          .createSignedUrl(path, 3600);
    }
    return _message({
      ...row,
      'image_url': imageUrl,
      'attachment_mime_type':
          row['attachment_mime_type'] ?? attachment?['mime_type'],
    });
  }

  ChatMessage _message(Map<String, dynamic> row) {
    final profile = row['profiles'];
    return ChatMessage.fromJson({
      ...row,
      'sender_nickname': profile is Map ? profile['nickname'] : null,
    });
  }

  String _extensionFor(String mimeType) => switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => throw ArgumentError.value(mimeType, 'mimeType', '지원하지 않는 이미지 형식'),
  };
}

class _SupabaseChatSubscription implements ChatSubscription {
  _SupabaseChatSubscription(this._client, this._channel);

  final SupabaseClient _client;
  final RealtimeChannel _channel;

  @override
  Future<void> cancel() => _client.removeChannel(_channel);
}
