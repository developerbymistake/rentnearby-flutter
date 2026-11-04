import 'dart:convert';

/// A row from the consumer-facing notification inbox — GET /notifications. Mirrors
/// RentNearBy.Core.DTOs.Responses.NotificationDto field-for-field. [actionRoute]/[actionArguments]
/// together are the redirect target: actionRoute is a literal AppRoutes.* path, actionArguments is
/// exactly the map the target screen expects via Get.arguments — the tap handler is generic and
/// never needs a per-[type] switch to know where to navigate.
class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? actionRoute;
  final Map<String, dynamic>? actionArguments;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.actionRoute,
    required this.actionArguments,
    required this.isRead,
    required this.createdAt,
  });

  /// Used only by NotificationController.markRead() to optimistically flip a single already
  /// -loaded row in place — never constructed directly by a screen.
  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        type: type,
        title: title,
        body: body,
        actionRoute: actionRoute,
        actionArguments: actionArguments,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
        id: json['id'].toString(),
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        actionRoute: json['actionRoute'] as String?,
        actionArguments: parseArguments(json['actionArguments']),
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  static Map<String, dynamic>? parseArguments(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }
}
