import 'dart:convert';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final bool isMine;
  final String type; // quick_reply | contact_request | contact_response | schedule_proposal | schedule_response
  final String payloadJson;
  // Which message this one answers — only set on quick_reply answers, so an answer can be
  // paired with its own question regardless of how many other questions are pending.
  final String? respondsToMessageId;
  final DateTime? readAt;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.isMine,
    required this.type,
    required this.payloadJson,
    this.respondsToMessageId,
    this.readAt,
    required this.createdAt,
  });

  Map<String, dynamic> get payload {
    try {
      return jsonDecode(payloadJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  factory MessageModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) => MessageModel(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        senderId: json['senderId'] as String,
        isMine: json['isMine'] as bool? ?? (currentUserId != null && json['senderId'] == currentUserId),
        type: json['type'] as String,
        payloadJson: json['payloadJson'] as String? ?? '{}',
        respondsToMessageId: json['respondsToMessageId'] as String?,
        // tryParse, not parse: a malformed/missing timestamp should drop this one field to
        // null/now rather than throw and take the whole message list down with it (a single
        // bad row previously meant every message in the conversation vanished behind the
        // framework's release-mode error placeholder, not just the one row).
        readAt: (json['readAt'] as String?) != null ? DateTime.tryParse(json['readAt'] as String) : null,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  MessageModel copyWith({DateTime? readAt}) => MessageModel(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        isMine: isMine,
        type: type,
        payloadJson: payloadJson,
        respondsToMessageId: respondsToMessageId,
        readAt: readAt ?? this.readAt,
        createdAt: createdAt,
      );
}
