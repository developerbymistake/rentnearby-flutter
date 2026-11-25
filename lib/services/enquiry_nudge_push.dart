import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class EnquiryNudgeStrings {
  EnquiryNudgeStrings._();
  static const String reply = 'Reply';
  static const String notAvailable = 'Not available';
  static const String channelName = 'Stay enquiry reminders';
  static const String channelDescription = 'Reminders to answer a waiting traveller';
}

class EnquiryNudgePush {
  const EnquiryNudgePush({required this.enquiryId, required this.title, required this.body, required this.data});

  final String enquiryId;
  final String title;
  final String body;
  final Map<String, dynamic> data;

  static const String channelId = 'stay_enquiry_nudges_v1';
  static const String replyAction = 'enquiry_reply';
  static const String notAvailableAction = 'enquiry_not_available';
  static const String payloadKey = 'enquiry_nudge';
  static const String route = '/stay-enquiries';

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    channelId,
    EnquiryNudgeStrings.channelName,
    description: EnquiryNudgeStrings.channelDescription,
    importance: Importance.high,
  );

  static Map<String, dynamic> _args(Map<String, dynamic> data) {
    try {
      final decoded = jsonDecode(data['action_args_json']?.toString() ?? '{}');
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static EnquiryNudgePush? tryParse(Map<String, dynamic> data, {String? title, String? body}) {
    if (data['action_route'] != route) return null;
    final args = _args(data);
    final id = args['enquiryId']?.toString() ?? '';
    final actions = args['actions'];
    if (id.isEmpty || actions is! List || !actions.contains('notAvailable')) return null;
    final t = title ?? data['title']?.toString() ?? '';
    if (t.isEmpty) return null;
    return EnquiryNudgePush(enquiryId: id, title: t, body: body ?? data['body']?.toString() ?? '', data: Map<String, dynamic>.from(data));
  }

  static int idFor(String enquiryId) {
    var h = 0;
    for (final c in enquiryId.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }

  static NotificationDetails details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          EnquiryNudgeStrings.channelName,
          channelDescription: EnquiryNudgeStrings.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(replyAction, EnquiryNudgeStrings.reply, showsUserInterface: true),
            AndroidNotificationAction(notAvailableAction, EnquiryNudgeStrings.notAvailable, showsUserInterface: true),
          ],
        ),
      );

  static String payload(EnquiryNudgePush push) => jsonEncode({...push.data, payloadKey: '1'});

  static Future<void> show(FlutterLocalNotificationsPlugin plugin, EnquiryNudgePush push) =>
      plugin.show(id: idFor(push.enquiryId), title: push.title, body: push.body, notificationDetails: details(), payload: payload(push));

  static bool isPayload(Map<String, dynamic> decoded) => decoded[payloadKey] == '1';

  static Map<String, dynamic> tapData(Map<String, dynamic> decoded, String? actionId) {
    final id = _args(decoded)['enquiryId']?.toString() ?? '';
    return {
      'notification_type': decoded['notification_type'],
      'action_route': route,
      'action_args_json': jsonEncode({
        'enquiryId': id,
        'bucket': 'New',
        if (actionId == notAvailableAction) 'action': 'notAvailable',
      }),
    };
  }
}
