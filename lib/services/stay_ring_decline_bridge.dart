import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'taxi_ring_service.dart';

/// Stay ring Decline has no UI, so the plugin runs it in the background isolate; this tells the running app.
abstract final class StayRingDeclineBridge {
  static const String portName = 'stay_ring_decline_v1';

  /// The enquiry id when the response is Decline on a stay ring, else null.
  static String? declinedEnquiry(String? actionId, String? payload) {
    if (actionId != TaxiRingNotification.declineAction || payload == null) return null;
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic> || !TaxiRingNotification.isStayRingPayload(data)) return null;
      final raw = data['action_args_json'];
      final args = raw is String ? jsonDecode(raw) : raw;
      final id = args is Map ? args['enquiryId']?.toString() ?? '' : '';
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  /// Background isolate: true when the running app was told.
  static bool forward(String? actionId, String? payload, {SendPort? Function(String name)? lookup}) {
    final id = declinedEnquiry(actionId, payload);
    if (id == null) return false;
    try {
      final port = (lookup ?? IsolateNameServer.lookupPortByName)(portName);
      if (port == null) return false;
      port.send(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static ReceivePort? _port;

  /// Main isolate: one listener at a time.
  static void listen(void Function(String enquiryId) onDecline) {
    try {
      _port?.close();
      IsolateNameServer.removePortNameMapping(portName);
      final port = ReceivePort();
      IsolateNameServer.registerPortWithName(port.sendPort, portName);
      port.listen((message) {
        if (message is String && message.isNotEmpty) onDecline(message);
      });
      _port = port;
    } catch (_) {}
  }
}
