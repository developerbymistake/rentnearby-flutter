import 'dart:convert';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final bool isMine;
  final String type; // quick_reply | contact_request | contact_response | schedule_proposal | schedule_response | system
  final String payloadJson;
  final DateTime? readAt;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.isMine,
    required this.type,
    required this.payloadJson,
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
        readAt: json['readAt'] != null ? DateTime.parse(json['readAt'] as String) : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
