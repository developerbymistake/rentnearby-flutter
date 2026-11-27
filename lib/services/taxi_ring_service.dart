import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_constants.dart';
import 'taxi_ring_session.dart';

class TripStringsTaxiRing {
  TripStringsTaxiRing._();
  static const String ringChannelName = 'Taxi requests';
  static const String ringChannelDescription = 'Rings when a traveller sends you a taxi request';
  static const String updatesChannelName = 'Taxi request updates';
  static const String updatesChannelDescription = 'When a taxi request closes or changes';
  static const String fallbackTitle = 'New taxi request';
  static const String testTitle = 'Test ring';
  static const String decline = 'Decline';
  static const String accept = 'Accept';
}

class StayRingStrings {
  StayRingStrings._();
  static const String ringChannelName = 'Stay enquiries';
  static const String ringChannelDescription = 'Rings when a traveller sends you a stay enquiry';
  static const String updatesChannelName = 'Stay enquiry updates';
  static const String updatesChannelDescription = 'When an enquiry ring ends or is missed';
  static const String fallbackTitle = 'New stay enquiry';
  static const String testTitle = 'Test ring';
}

enum TaxiRingKind { ring, test, end }

/// Who the ring is for: a Taxi Driver's request offer or a Stay Owner's new enquiry.
enum RingRole { taxi, stay }

/// Stay ring end reasons: the server sends Answered, Closed, Accepted, Declined; a missed ring ends with Missed; the app adds DeclinedHere.
abstract final class StayRingEnds {
  static const String missed = 'Missed';
  static const String declinedHere = 'DeclinedHere';
}

class TaxiRingPush {
  const TaxiRingPush({
    required this.kind,
    required this.offerId,
    required this.requestId,
    required this.expiresAt,
    required this.ackToken,
    required this.title,
    required this.lines,
    required this.reason,
    this.slots = const <String>[],
    this.sentAt,
    this.clockOffset = Duration.zero,
    this.driverUserId,
    this.role = RingRole.taxi,
    this.stay,
  });

  static const Duration maxRing = Duration(seconds: 300);
  static const String ringKind = 'taxi_ring';
  static const String testKind = 'taxi_ring_test';
  static const String endKind = 'taxi_ring_end';
  static const String version = '1';
  static const String ringRoute = '/taxi-request-ring';
  static const String stayRingKind = 'stay_ring';
  static const String stayTestKind = 'stay_ring_test';
  static const String stayEndKind = 'stay_ring_end';
  static const String stayMissedKind = 'stay_ring_missed';
  static const String stayRingRoute = '/stay-enquiry-ring';
  static const String stayTestTag = 'stay_ring_test';
  static const Set<String> stayKinds = {stayRingKind, stayTestKind, stayEndKind, stayMissedKind};

  final TaxiRingKind kind;
  final RingRole role;
  /// The ringing taxi offer, or the enquiry id of a stay ring.
  final String offerId;
  final String requestId;
  final DateTime? expiresAt;
  final String ackToken;
  final String title;
  final List<String> lines;
  final List<String> slots;
  final String? reason;
  final DateTime? sentAt;
  final Duration clockOffset;
  /// The user the ring is for (the driver, or the Stay Owner of a stay ring).
  final String? driverUserId;
  final StayRingInfo? stay;

  bool get isStay => role == RingRole.stay;

  String get tag => switch ((role, kind)) {
        (RingRole.taxi, TaxiRingKind.test) => 'taxi_ring_test',
        (RingRole.stay, TaxiRingKind.test) => stayTestTag,
        (RingRole.taxi, _) => TaxiRingNotification.tagFor(offerId),
        (RingRole.stay, _) => TaxiRingNotification.stayTagFor(offerId),
      };

  // FCM drops a ring after its TTL (time left at send), so arrival means the server clock now is sentAt.
  TaxiRingPush receivedAt(DateTime deviceNow) {
    final sent = sentAt;
    if (sent == null) return this;
    return TaxiRingPush(
      kind: kind,
      offerId: offerId,
      requestId: requestId,
      expiresAt: expiresAt,
      ackToken: ackToken,
      title: title,
      lines: lines,
      reason: reason,
      slots: slots,
      sentAt: sent,
      clockOffset: sent.difference(deviceNow.toUtc()),
      driverUserId: driverUserId,
      role: role,
      stay: stay,
    );
  }

  Duration timeLeft(DateTime now) {
    final at = expiresAt;
    if (at == null) return Duration.zero;
    final left = at.toUtc().difference(now.toUtc().add(clockOffset));
    if (left.isNegative) return Duration.zero;
    return left > maxRing ? maxRing : left;
  }

  bool isExpired(DateTime now) => timeLeft(now) <= Duration.zero;

  static bool isUnreadableRing(Map<String, dynamic> data) =>
      (data['kind'] == ringKind || data['kind'] == testKind || data['kind'] == stayRingKind || data['kind'] == stayTestKind) && tryParse(data) == null;

  static TaxiRingPush? tryParse(Map<String, dynamic> data) {
    if (stayKinds.contains(data['kind'])) return _tryParseStay(data);
    final kind = switch (data['kind']) {
      ringKind => TaxiRingKind.ring,
      testKind => TaxiRingKind.test,
      endKind => TaxiRingKind.end,
      _ => null,
    };
    if (kind == null || data['v']?.toString() != version) return null;
    final offerId = data['offerId']?.toString() ?? '';
    if (kind != TaxiRingKind.test && offerId.isEmpty) return null;
    DateTime? expiresAt;
    if (kind != TaxiRingKind.end) {
      expiresAt = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
      if (expiresAt == null) return null;
    }
    final ackToken = data['ackToken']?.toString() ?? '';
    if (kind == TaxiRingKind.ring && ackToken.isEmpty) return null;
    final title = data['title']?.toString() ?? '';
    return TaxiRingPush(
      kind: kind,
      offerId: offerId,
      requestId: data['requestId']?.toString() ?? '',
      expiresAt: expiresAt?.toUtc(),
      ackToken: ackToken,
      title: title.isNotEmpty
          ? title
          : (kind == TaxiRingKind.test ? TripStringsTaxiRing.testTitle : TripStringsTaxiRing.fallbackTitle),
      lines: [
        for (final key in const ['line1', 'line2', 'line3'])
          if ((data[key]?.toString() ?? '').isNotEmpty) data[key].toString(),
      ],
      reason: data['reason']?.toString(),
      slots: [for (final key in const ['line1', 'line2', 'line3']) data[key]?.toString() ?? ''],
      sentAt: DateTime.tryParse(data['sentAt']?.toString() ?? '')?.toUtc(),
      driverUserId: switch (data['driverUserId']?.toString()) { final String id when id.isNotEmpty => id, _ => null },
    );
  }

  // A missed ring ends the ring like a ring end; the server shows it with the ring's tag.
  static TaxiRingPush? _tryParseStay(Map<String, dynamic> data) {
    if (data['v']?.toString() != version) return null;
    final kind = switch (data['kind']) {
      stayRingKind => TaxiRingKind.ring,
      stayTestKind => TaxiRingKind.test,
      _ => TaxiRingKind.end,
    };
    final enquiryId = data['enquiryId']?.toString() ?? '';
    if (kind != TaxiRingKind.test && enquiryId.isEmpty) return null;
    DateTime? expiresAt;
    if (kind != TaxiRingKind.end) {
      expiresAt = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
      if (expiresAt == null) return null;
    }
    final title = data['title']?.toString() ?? '';
    final slots = [for (final key in const ['line1', 'line2', 'line3']) data[key]?.toString() ?? ''];
    return TaxiRingPush(
      kind: kind,
      role: RingRole.stay,
      offerId: kind == TaxiRingKind.test ? '' : enquiryId,
      requestId: '',
      expiresAt: expiresAt?.toUtc(),
      ackToken: '',
      title: title.isNotEmpty ? title : (kind == TaxiRingKind.test ? StayRingStrings.testTitle : StayRingStrings.fallbackTitle),
      lines: [for (final l in slots) if (l.isNotEmpty) l],
      reason: data['kind'] == stayMissedKind ? StayRingEnds.missed : data['reason']?.toString(),
      slots: slots,
      sentAt: DateTime.tryParse(data['sentAt']?.toString() ?? '')?.toUtc(),
      driverUserId: switch (data['ownerUserId']?.toString()) { final String id when id.isNotEmpty => id, _ => null },
      stay: kind == TaxiRingKind.ring ? StayRingInfo.fromData(data) : null,
    );
  }
}

/// What the stay ring shows: never a phone number or other contact.
class StayRingInfo {
  const StayRingInfo({
    this.travellerFirstName = '',
    this.stayName = '',
    this.checkIn,
    this.checkOut,
    this.guests,
    this.price,
  });

  final String travellerFirstName;
  final String stayName;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? guests;
  final int? price;

  static DateTime? day(Object? raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  static int? positive(Object? raw) => switch (int.tryParse(raw?.toString() ?? '')) { final int n when n > 0 => n, _ => null };

  static String firstName(Object? raw) {
    final name = raw?.toString().trim() ?? '';
    return name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
  }

  static int? _guests(Map<dynamic, dynamic> data) {
    final given = positive(data['guests']);
    if (given != null) return given;
    final adults = positive(data['adults']) ?? 0;
    final kids = positive(data['kids']) ?? 0;
    return adults + kids > 0 ? adults + kids : null;
  }

  // Push fields (guestName, adults, kids) and the ring screen arguments (guests) both read here.
  factory StayRingInfo.fromData(Map<dynamic, dynamic> data) => StayRingInfo(
        travellerFirstName: firstName(data['guestName']),
        stayName: data['stayName']?.toString().trim() ?? '',
        checkIn: day(data['checkIn']),
        checkOut: day(data['checkOut']),
        guests: _guests(data),
        price: positive(data['price']),
      );

  static String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toArgs() {
    final from = checkIn;
    final to = checkOut;
    return {
      if (travellerFirstName.isNotEmpty) 'guestName': travellerFirstName,
      if (stayName.isNotEmpty) 'stayName': stayName,
      if (from != null) 'checkIn': _ymd(from),
      if (to != null) 'checkOut': _ymd(to),
      'guests': ?guests,
      'price': ?price,
    };
  }

  List<String> get lines {
    final head = [if (travellerFirstName.isNotEmpty) travellerFirstName, if (stayName.isNotEmpty) stayName].join(' · ');
    return [if (head.isNotEmpty) head];
  }
}

class TaxiRingNotification {
  TaxiRingNotification._();

  static const int id = 0;
  static const String ringChannelId = 'taxi_requests_ring_v1';
  static const String updatesChannelId = 'taxi_request_updates_v1';
  static const String stayRingChannelId = 'stay_enquiry_ring_v1';
  static const String stayUpdatesChannelId = 'stay_enquiry_updates_v1';
  static const String ringtoneUri = 'content://settings/system/ringtone';
  static const String declineAction = 'decline';
  static const String acceptAction = 'accept';
  static const String tagKey = 'ring_tag';
  static const int flagInsistent = 4;

  static const AndroidNotificationChannel ringChannel = AndroidNotificationChannel(
    ringChannelId,
    TripStringsTaxiRing.ringChannelName,
    description: TripStringsTaxiRing.ringChannelDescription,
    importance: Importance.max,
    sound: UriAndroidNotificationSound(ringtoneUri),
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    enableVibration: true,
  );

  static const AndroidNotificationChannel stayRingChannel = AndroidNotificationChannel(
    stayRingChannelId,
    StayRingStrings.ringChannelName,
    description: StayRingStrings.ringChannelDescription,
    importance: Importance.max,
    sound: UriAndroidNotificationSound(ringtoneUri),
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    enableVibration: true,
  );

  static AndroidNotificationChannel ringChannelFor(RingRole role) => role == RingRole.stay ? stayRingChannel : ringChannel;

  static const AndroidNotificationChannel stayUpdatesChannel = AndroidNotificationChannel(
    stayUpdatesChannelId,
    StayRingStrings.updatesChannelName,
    description: StayRingStrings.updatesChannelDescription,
    importance: Importance.defaultImportance,
  );

  static const AndroidNotificationChannel updatesChannel = AndroidNotificationChannel(
    updatesChannelId,
    TripStringsTaxiRing.updatesChannelName,
    description: TripStringsTaxiRing.updatesChannelDescription,
    importance: Importance.defaultImportance,
  );

  static AndroidNotificationDetails android(TaxiRingPush push, DateTime now, {AndroidBitmap<Object>? largeIcon}) {
    final left = push.timeLeft(now).inMilliseconds;
    final lines = bodyLines(push);
    final channel = ringChannelFor(push.role);
    return AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
      timeoutAfter: left < 1 ? 1 : left,
      additionalFlags: Int32List.fromList(const <int>[flagInsistent]),
      visibility: NotificationVisibility.public,
      fullScreenIntent: push.kind == TaxiRingKind.ring,
      sound: const UriAndroidNotificationSound(ringtoneUri),
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
      enableVibration: true,
      styleInformation: lines.isEmpty ? null : BigTextStyleInformation(lines.join('\n')),
      largeIcon: largeIcon,
      tag: push.tag,
      actions: push.isStay ? stayActions : taxiActions,
    );
  }

  static const List<AndroidNotificationAction> taxiActions = <AndroidNotificationAction>[
    AndroidNotificationAction(declineAction, TripStringsTaxiRing.decline, showsUserInterface: true),
    AndroidNotificationAction(acceptAction, TripStringsTaxiRing.accept, showsUserInterface: true),
  ];

  // Decline on a stay ring only silences this phone: the system cancels the notification and the app stays closed.
  static const List<AndroidNotificationAction> stayActions = <AndroidNotificationAction>[
    AndroidNotificationAction(declineAction, TripStringsTaxiRing.decline, showsUserInterface: false, cancelNotification: true),
    AndroidNotificationAction(acceptAction, TripStringsTaxiRing.accept, showsUserInterface: true),
  ];

  static NotificationDetails details(TaxiRingPush push, DateTime now, {AndroidBitmap<Object>? largeIcon}) =>
      NotificationDetails(android: android(push, now, largeIcon: largeIcon));

  static List<String> bodyLines(TaxiRingPush push) {
    if (push.isStay) {
      final head = push.stay?.lines.firstOrNull ?? (push.slots.length > 1 ? push.slots[1] : '');
      return [for (final l in [head, if (push.slots.isNotEmpty) push.slots[0], if (push.slots.length > 2) push.slots[2]]) if (l.isNotEmpty) l];
    }
    String at(int i) => i < push.slots.length ? push.slots[i] : '';
    final seats = at(2).split(' · ').first;
    final second = [if (at(1).isNotEmpty) at(1), if (seats.isNotEmpty) seats].join(' · ');
    return [if (at(0).isNotEmpty) at(0), if (second.isNotEmpty) second];
  }

  static NotificationDetails endDetails(TaxiRingPush push) => NotificationDetails(
        android: AndroidNotificationDetails(
          push.isStay ? stayUpdatesChannelId : updatesChannelId,
          push.isStay ? StayRingStrings.updatesChannelName : TripStringsTaxiRing.updatesChannelName,
          channelDescription: push.isStay ? StayRingStrings.updatesChannelDescription : TripStringsTaxiRing.updatesChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          autoCancel: true,
          tag: push.tag,
        ),
      );

  static String tagFor(String offerId) => 'taxi_ring_$offerId';

  static String stayTagFor(String enquiryId) => 'stay_ring_$enquiryId';

  static Future<void> stopStay(TaxiRingNotifier notifier, String enquiryId) async {
    try {
      await notifier.cancel(id, stayTagFor(enquiryId));
    } catch (_) {}
  }

  static Future<void> stop(TaxiRingNotifier notifier, String offerId) async {
    try {
      await notifier.cancel(id, tagFor(offerId));
    } catch (_) {}
  }

  static String body(TaxiRingPush push) {
    if (push.isStay) return bodyLines(push).firstOrNull ?? '';
    return push.lines.isEmpty ? '' : push.lines.first;
  }

  static const String ringType = 'taxi_request_ring';
  static const String stayRingType = 'stay_enquiry_ring';

  static Map<String, dynamic> routeData(TaxiRingPush push, {String? action}) => push.isStay
      ? {
          'notification_type': stayRingType,
          'action_route': TaxiRingPush.stayRingRoute,
          'action_args_json': jsonEncode({
            'enquiryId': push.offerId,
            'action': ?action,
            'expiresAt': ?push.expiresAt?.toIso8601String(),
            ...?push.stay?.toArgs(),
          }),
          tagKey: push.tag,
        }
      : {
          'notification_type': ringType,
          'action_route': TaxiRingPush.ringRoute,
          'action_args_json': jsonEncode({'offerId': push.offerId, 'action': ?action, 'expiresAt': ?push.expiresAt?.toIso8601String()}),
          tagKey: push.tag,
        };

  static String? payload(TaxiRingPush push) => push.kind == TaxiRingKind.test ? null : jsonEncode(routeData(push));

  static bool stopsOnTap(String? actionId) => actionId == declineAction || actionId == acceptAction;

  static bool isRingPayload(Map<String, dynamic> data) =>
      (data['action_route'] == TaxiRingPush.ringRoute || data['action_route'] == TaxiRingPush.stayRingRoute) && data[tagKey] is String;

  static bool isStayRingPayload(Map<String, dynamic> data) =>
      data['action_route'] == TaxiRingPush.stayRingRoute && data[tagKey] is String;

  static Map<String, dynamic> withAction(Map<String, dynamic> data, String? actionId) {
    if (actionId != declineAction && actionId != acceptAction) return data;
    Map<String, dynamic> args;
    try {
      final decoded = jsonDecode(data['action_args_json']?.toString() ?? '{}');
      args = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      args = <String, dynamic>{};
    }
    return {...data, 'action_args_json': jsonEncode({...args, 'action': actionId})};
  }
}

abstract class TaxiRingNotifier {
  Future<void> show(int id, String title, String body, NotificationDetails details, String? payload);
  Future<void> cancel(int id, String tag);
}

class PluginTaxiRingNotifier implements TaxiRingNotifier {
  PluginTaxiRingNotifier(this.plugin);
  final FlutterLocalNotificationsPlugin plugin;

  @override
  Future<void> show(int id, String title, String body, NotificationDetails details, String? payload) =>
      plugin.show(id: id, title: title, body: body, notificationDetails: details, payload: payload);

  @override
  Future<void> cancel(int id, String tag) => plugin.cancel(id: id, tag: tag);
}

class TaxiRingDeviceState {
  const TaxiRingDeviceState({
    required this.notificationsOn,
    required this.ringChannelOn,
    required this.manufacturer,
    required this.androidSdk,
    required this.appBuild,
  });
  final bool notificationsOn;
  final bool ringChannelOn;
  final String? manufacturer;
  final int androidSdk;
  final int appBuild;
}

typedef TaxiRingDeviceProbe = Future<TaxiRingDeviceState> Function();
typedef TaxiAckSender = Future<void> Function(String offerId, Map<String, dynamic> body);

enum TaxiRingOutcome { shown, testShown, expired, ended, alreadyEnded, ignored }

class TaxiRingResult {
  const TaxiRingResult(this.outcome, this.push, this.ack);
  final TaxiRingOutcome outcome;
  final TaxiRingPush? push;
  final Future<void> ack;
}

class TaxiRingService {
  TaxiRingService({
    required this.notifier,
    required this.sendAck,
    required this.probe,
    DateTime Function()? clock,
    this.driverSession,
    this.stayOwnerSession,
    this.art,
    this.stayArt,
  }) : _clock = clock ?? DateTime.now;

  factory TaxiRingService.withPlugin(FlutterLocalNotificationsPlugin plugin) => TaxiRingService(
        notifier: PluginTaxiRingNotifier(plugin),
        sendAck: TaxiRingAckClient.send,
        probe: () => TaxiRingDevice.read(plugin),
        driverSession: TaxiRingSession.accepts,
        stayOwnerSession: TaxiRingSession.acceptsStay,
        art: TaxiRingArt.load,
        stayArt: TaxiRingArt.loadStay,
      );

  final TaxiRingNotifier notifier;
  final Future<Uint8List?> Function()? art;
  final TaxiAckSender sendAck;
  final TaxiRingDeviceProbe probe;
  final DateTime Function() _clock;
  final Future<bool> Function(String? driverUserId)? driverSession;
  final Future<bool> Function(String? ownerUserId)? stayOwnerSession;
  final Future<Uint8List?> Function()? stayArt;

  // A stay ring needs an explicit Stay Owner check; a taxi ring keeps its old default.
  Future<bool> _isDriverSession(String? driverUserId, RingRole role) async {
    final check = role == RingRole.stay ? stayOwnerSession : driverSession;
    if (check == null) return role == RingRole.taxi;
    try {
      return await check(driverUserId);
    } catch (_) {
      return false;
    }
  }

  static DateTime? lastTestRingShownAt;
  static Completer<DateTime> _testRing = Completer<DateTime>();

  static Future<DateTime> get testRingShown => _testRing.future;

  static void _markTestRingShown(DateTime at) {
    lastTestRingShownAt = at;
    final waiters = _testRing;
    _testRing = Completer<DateTime>();
    if (!waiters.isCompleted) waiters.complete(at);
  }

  static void resetTestRingMarker() {
    lastTestRingShownAt = null;
    _testRing = Completer<DateTime>();
  }

  Future<TaxiRingResult> handle(Map<String, dynamic> data) async {
    final now = _clock().toUtc();
    final push = TaxiRingPush.tryParse(data)?.receivedAt(now);
    if (push == null) return TaxiRingResult(TaxiRingOutcome.ignored, null, Future<void>.value());
    if (push.kind != TaxiRingKind.end && !await _isDriverSession(push.driverUserId, push.role)) {
      return TaxiRingResult(TaxiRingOutcome.ignored, push, Future<void>.value());
    }
    switch (push.kind) {
      case TaxiRingKind.end:
        TaxiRingSession.ended.value = TaxiRingEnd(push.offerId, push.reason, role: push.role);
        await TaxiRingEndedLog.record(push.offerId, now);
        await _safe(() => notifier.cancel(TaxiRingNotification.id, push.tag));
        return TaxiRingResult(TaxiRingOutcome.ended, push, Future<void>.value());
      case TaxiRingKind.test:
        if (push.isExpired(now)) return TaxiRingResult(TaxiRingOutcome.expired, push, Future<void>.value());
        final shown = await _show(push, now);
        if (shown) _markTestRingShown(now);
        return TaxiRingResult(shown ? TaxiRingOutcome.testShown : TaxiRingOutcome.ignored, push, Future<void>.value());
      case TaxiRingKind.ring:
        if (TaxiRingEndedLog.contains(push.offerId, now)) {
          return TaxiRingResult(TaxiRingOutcome.alreadyEnded, push, _lateAck(push, now));
        }
        if (push.isExpired(now)) {
          return TaxiRingResult(TaxiRingOutcome.expired, push, _lateAck(push, now));
        }
        final shown = await _show(push, now);
        if (push.isStay) return TaxiRingResult(TaxiRingOutcome.shown, push, Future<void>.value());
        return TaxiRingResult(TaxiRingOutcome.shown, push, _ack(push, now, shown: shown, late: false));
    }
  }

  // The stay ring has no ack endpoint.
  Future<void> _lateAck(TaxiRingPush push, DateTime now) =>
      push.isStay ? Future<void>.value() : _ack(push, now, shown: false, late: true);

  Future<bool> _show(TaxiRingPush push, DateTime now) async {
    Uint8List? bytes;
    try {
      bytes = await (push.isStay ? stayArt : art)?.call();
    } catch (_) {}
    return _safe(() => notifier.show(
          TaxiRingNotification.id,
          push.title,
          TaxiRingNotification.body(push),
          TaxiRingNotification.details(push, now, largeIcon: bytes == null ? null : ByteArrayAndroidBitmap(bytes)),
          TaxiRingNotification.payload(push),
        ));
  }

  Future<void> _ack(TaxiRingPush push, DateTime receivedAt, {required bool shown, required bool late}) async {
    try {
      final device = await probe();
      await sendAck(push.offerId, ackBody(push, receivedAt, device, shown: shown, late: late));
    } catch (_) {}
  }

  static Map<String, dynamic> ackBody(
    TaxiRingPush push,
    DateTime receivedAt,
    TaxiRingDeviceState device, {
    required bool shown,
    required bool late,
  }) =>
      {
        'ackToken': push.ackToken,
        'receivedAt': '${receivedAt.toUtc().toIso8601String().substring(0, 19)}Z',
        'shown': shown,
        'late': late,
        'notificationsOn': device.notificationsOn,
        'ringChannelOn': device.ringChannelOn,
        'manufacturer': device.manufacturer,
        'androidSdk': device.androidSdk,
        'appBuild': device.appBuild,
      };

  static Future<bool> _safe(Future<void> Function() run) async {
    try {
      await run();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class TaxiRingArt {
  TaxiRingArt._();

  static const String asset = 'assets/images/design/travel3d/taxi.png';
  static const String stayAsset = 'assets/images/design/travel3d/camping.png';
  static Uint8List? _cached;
  static Uint8List? _cachedStay;

  static Future<Uint8List?> loadStay() async {
    final hit = _cachedStay;
    if (hit != null) return hit;
    try {
      final data = await rootBundle.load(stayAsset);
      return _cachedStay = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> load() async {
    final hit = _cached;
    if (hit != null) return hit;
    try {
      final data = await rootBundle.load(asset);
      return _cached = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }
}

typedef TaxiRingIdentity =({String? manufacturer, int androidSdk});
typedef TaxiRingIdentitySource = Future<TaxiRingIdentity?> Function();

abstract class TaxiRingDeviceStore {
  String? readString(String key);
  int? readInt(String key);
  Future<void> write(String key, Object? value);
}

class GetStorageTaxiRingDeviceStore implements TaxiRingDeviceStore {
  const GetStorageTaxiRingDeviceStore();

  @override
  String? readString(String key) => GetStorage().read<String>(key);

  @override
  int? readInt(String key) => GetStorage().read<int>(key);

  @override
  Future<void> write(String key, Object? value) => GetStorage().write(key, value);
}

class TaxiRingEndedLog {
  TaxiRingEndedLog._();

  static const String _key = 'taxi_ring_ended_offers';
  static const Duration keepFor = Duration(hours: 1);
  static const int maxEntries = 50;

  static TaxiRingDeviceStore store = const GetStorageTaxiRingDeviceStore();

  static Map<String, int> _read() {
    try {
      final decoded = jsonDecode(store.readString(_key) ?? '{}');
      if (decoded is! Map) return <String, int>{};
      return {
        for (final e in decoded.entries)
          if (e.value is int) e.key.toString(): e.value as int,
      };
    } catch (_) {
      return <String, int>{};
    }
  }

  static bool contains(String offerId, DateTime now) {
    final at = _read()[offerId];
    return at != null && now.toUtc().millisecondsSinceEpoch - at < keepFor.inMilliseconds;
  }

  static Future<void> record(String offerId, DateTime now) async {
    if (offerId.isEmpty) return;
    final nowMs = now.toUtc().millisecondsSinceEpoch;
    final kept = _read()
      ..removeWhere((_, at) => nowMs - at >= keepFor.inMilliseconds)
      ..remove(offerId);
    final entries = kept.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final recent = entries.length >= maxEntries ? entries.sublist(entries.length - maxEntries + 1) : entries;
    try {
      await store.write(_key, jsonEncode({for (final e in recent) e.key: e.value, offerId: nowMs}));
    } catch (_) {}
  }
}

class TaxiRingDevice {
  TaxiRingDevice._();

  static const String channelName = 'bakhli/system_settings';
  static const String deviceInfoMethod = 'deviceInfo';
  static const MethodChannel channel = MethodChannel(channelName);
  static const String _manufacturerKey = 'taxi_ring_device_manufacturer';
  static const String _sdkKey = 'taxi_ring_device_sdk';

  static TaxiRingDeviceStore store = const GetStorageTaxiRingDeviceStore();
  static TaxiRingIdentitySource source = channelIdentity;

  static Future<TaxiRingIdentity?> channelIdentity() async {
    final raw = await channel.invokeMapMethod<String, dynamic>(deviceInfoMethod);
    if (raw == null) return null;
    final manufacturer = raw['manufacturer']?.toString();
    final sdk = raw['androidSdk'];
    return (
      manufacturer: manufacturer == null || manufacturer.isEmpty ? null : manufacturer,
      androidSdk: sdk is int ? sdk : int.tryParse(sdk?.toString() ?? '') ?? 0,
    );
  }

  static Future<void> remember({required String? manufacturer, required int androidSdk}) async {
    await store.write(_manufacturerKey, manufacturer);
    await store.write(_sdkKey, androidSdk);
  }

  static TaxiRingIdentity stored() {
    try {
      return (manufacturer: store.readString(_manufacturerKey), androidSdk: store.readInt(_sdkKey) ?? 0);
    } catch (_) {
      return (manufacturer: null, androidSdk: 0);
    }
  }

  // The background isolate has no app method channel, so the foreground run caches the values.
  static Future<bool> refresh() async {
    try {
      final live = await source();
      if (live == null || live.androidSdk <= 0) return false;
      await remember(manufacturer: live.manufacturer, androidSdk: live.androidSdk);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<TaxiRingIdentity> identity() async {
    final cached = stored();
    if (cached.androidSdk > 0) return cached;
    return await refresh() ? stored() : cached;
  }

  // Below high the ring makes no sound and shows no heads-up.
  static bool ringChannelReady(Iterable<AndroidNotificationChannel> channels, {String channelId = TaxiRingNotification.ringChannelId}) {
    for (final c in channels) {
      if (c.id == channelId) {
        return c.importance == Importance.high || c.importance == Importance.max;
      }
    }
    return false;
  }

  static Future<TaxiRingDeviceState> read(FlutterLocalNotificationsPlugin plugin, {RingRole role = RingRole.taxi}) async {
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    var notificationsOn = false;
    var ringChannelOn = false;
    try {
      notificationsOn = await android?.areNotificationsEnabled() ?? false;
      ringChannelOn = ringChannelReady(
        await android?.getNotificationChannels() ?? const <AndroidNotificationChannel>[],
        channelId: TaxiRingNotification.ringChannelFor(role).id,
      );
    } catch (_) {}
    var appBuild = 0;
    try {
      appBuild = int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
    } catch (_) {}
    final id = await identity();
    return TaxiRingDeviceState(
      notificationsOn: notificationsOn,
      ringChannelOn: ringChannelOn,
      manufacturer: id.manufacturer,
      androidSdk: id.androidSdk,
      appBuild: appBuild,
    );
  }
}

class TaxiRingAckClient {
  TaxiRingAckClient._();

  static const Duration timeout = Duration(seconds: 5);
  static const Duration overallTimeout = Duration(seconds: 9);

  static Future<void> within(Future<void> ack, {Duration limit = overallTimeout}) =>
      ack.timeout(limit, onTimeout: () {});

  static Dio _dio() => Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        contentType: Headers.jsonContentType,
      ));

  static String path(String offerId) => '/taxi-requests/offers/$offerId/ack';

  static Future<void> send(String offerId, Map<String, dynamic> body, {Dio? dio}) async {
    final client = dio ?? _dio();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await client.post<void>(path(offerId), data: body);
        return;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status != null && status < 500) return;
      } catch (_) {
        return;
      }
    }
  }
}
