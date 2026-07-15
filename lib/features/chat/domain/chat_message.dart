enum MessageSendStatus { sending, sent, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderNickname,
    required this.clientMessageId,
    required this.body,
    required this.createdAt,
    this.status = MessageSendStatus.sent,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String senderNickname;
  final String clientMessageId;
  final String body;
  final DateTime createdAt;
  final MessageSendStatus status;

  ChatMessage copyWith({
    String? id,
    DateTime? createdAt,
    MessageSendStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId,
      senderId: senderId,
      senderNickname: senderNickname,
      clientMessageId: clientMessageId,
      body: body,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      roomId: (json['room_id'] ?? json['roomId']) as String,
      senderId: (json['sender_id'] ?? json['senderId']) as String,
      senderNickname:
          (json['sender_nickname'] ?? json['senderNickname'] ?? '알 수 없음')
              as String,
      clientMessageId:
          (json['client_message_id'] ?? json['clientMessageId']) as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(
        (json['created_at'] ?? json['createdAt']) as String,
      ).toLocal(),
    );
  }
}

class MessageCursor {
  const MessageCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;

  factory MessageCursor.fromMessage(ChatMessage message) =>
      MessageCursor(createdAt: message.createdAt, id: message.id);
}
