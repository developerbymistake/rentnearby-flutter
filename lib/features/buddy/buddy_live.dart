import 'dart:async';

import 'package:get/get.dart';

abstract final class BuddyLive {
  static final RxInt buddies = 0.obs;
  static final RxInt notices = 0.obs;
  static final RxInt sharedTrips = 0.obs;
  static final Rx<String?> goneTrip = Rx<String?>(null);
  static final Map<String, RxInt> _tripView = {};
  static final Map<String, RxInt> _expenses = {};
  static final Map<String, int> _balancesVersion = {};

  static RxInt tripView(String tripId) => _tripView.putIfAbsent(tripId, () => 0.obs);

  static RxInt expenses(String tripId) => _expenses.putIfAbsent(tripId, () => 0.obs);

  static void seenBalancesVersion(String tripId, int version) {
    final known = _balancesVersion[tripId] ?? -1;
    if (version > known) _balancesVersion[tripId] = version;
  }

  static int? knownBalancesVersion(String tripId) => _balancesVersion[tripId];

  static void onResume() {
    buddies.value++;
    notices.value++;
  }

  static void reset() {
    _balancesVersion.clear();
    goneTrip.value = null;
  }
}

abstract final class BuddyWireTypes {
  static const String buddyRequestReceived = 'buddy_request_received';
  static const String buddyRequestAccepted = 'buddy_request_accepted';
  static const String tripInvite = 'trip_invite';
  static const String tripMemberJoined = 'trip_member_joined';
  static const String tripPlanUpdated = 'trip_plan_updated';
  static const String tripMemberRemoved = 'trip_member_removed';
  static const String tripDeletedForViewer = 'trip_deleted_for_viewer';
  static const String tripExpensesUpdated = 'trip_expenses_updated';
  static const String tripSettleReminder = 'trip_settle_reminder';
  static const String tripPaymentSaidPaid = 'trip_payment_said_paid';
  static const String tripPaymentReceived = 'trip_payment_received';
  static const String tripPaymentWithdrawn = 'trip_payment_withdrawn';
  static const String tripPaymentNotReceived = 'trip_payment_not_received';

  static const Set<String> all = {
    buddyRequestReceived,
    buddyRequestAccepted,
    tripInvite,
    tripMemberJoined,
    tripPlanUpdated,
    tripMemberRemoved,
    tripDeletedForViewer,
    tripExpensesUpdated,
    tripSettleReminder,
    tripPaymentSaidPaid,
    tripPaymentReceived,
    tripPaymentWithdrawn,
    tripPaymentNotReceived,
  };

  static const Set<String> money = {
    tripExpensesUpdated,
    tripSettleReminder,
    tripPaymentSaidPaid,
    tripPaymentReceived,
    tripPaymentWithdrawn,
    tripPaymentNotReceived,
  };
}

abstract final class BuddyHubEvents {
  static const String buddiesChanged = 'BuddiesChanged';
  static const String tripViewChanged = 'TripViewChanged';
  static const String tripExpensesChanged = 'TripExpensesChanged';

  static const List<String> all = [buddiesChanged, tripViewChanged, tripExpensesChanged];
}

abstract final class BuddyPushSync {
  static const Duration debounce = Duration(milliseconds: 600);
  static Timer? _timer;
  static bool _buddies = false;
  static bool _notices = false;
  static bool _shared = false;
  static final Set<String> _views = {};
  static final Set<String> _expenses = {};
  static final Set<String> _gone = {};

  static bool isBuddyType(String? type) => type != null && (BuddyWireTypes.all.contains(type) || BuddyHubEvents.all.contains(type));

  static String? _tripId(Map<String, dynamic>? args) {
    final id = args?['tripId'] ?? args?['deletedTripId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  static void onPush(String? type, String? route, Map<String, dynamic>? args) {
    if (type == null || !BuddyWireTypes.all.contains(type)) return;
    final tripId = _tripId(args);
    switch (type) {
      case BuddyWireTypes.buddyRequestReceived:
      case BuddyWireTypes.buddyRequestAccepted:
        _buddies = true;
        _notices = true;
      case BuddyWireTypes.tripInvite:
        _shared = true;
        _notices = true;
      case BuddyWireTypes.tripMemberJoined:
        if (tripId != null) _views.add(tripId);
      case BuddyWireTypes.tripPlanUpdated:
        if (tripId != null) _views.add(tripId);
        _shared = true;
      case BuddyWireTypes.tripMemberRemoved:
      case BuddyWireTypes.tripDeletedForViewer:
        if (tripId != null) {
          _views.add(tripId);
          _gone.add(tripId);
        }
        _shared = true;
        _notices = true;
      default:
        if (tripId != null) _expenses.add(tripId);
        _notices = true;
        _shared = true;
    }
    _schedule();
  }

  static void onHubEvent(String name, Map<String, dynamic> data) {
    final tripId = _tripId(data);
    switch (name) {
      case BuddyHubEvents.buddiesChanged:
        _buddies = true;
      case BuddyHubEvents.tripViewChanged:
        if (tripId != null) _views.add(tripId);
        _shared = true;
      case BuddyHubEvents.tripExpensesChanged:
        if (tripId == null) return;
        final v = data['balancesVersion'];
        final known = BuddyLive.knownBalancesVersion(tripId);
        if (v is num && known != null && v.toInt() <= known) return;
        _expenses.add(tripId);
      default:
        return;
    }
    _schedule();
  }

  static void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  static void flush() {
    _timer?.cancel();
    _timer = null;
    if (_buddies) BuddyLive.buddies.value++;
    if (_notices) BuddyLive.notices.value++;
    if (_shared) BuddyLive.sharedTrips.value++;
    for (final id in _views) {
      BuddyLive.tripView(id).value++;
    }
    for (final id in _expenses) {
      BuddyLive.expenses(id).value++;
    }
    for (final id in _gone) {
      BuddyLive.goneTrip.value = id;
    }
    _buddies = _notices = _shared = false;
    _views.clear();
    _expenses.clear();
    _gone.clear();
  }

  static int localNotificationId(Map<String, dynamic> data) =>
      '${data['notification_type']}|${data['action_args_json']}'.hashCode;

  static bool isBuddyPush(Map<String, dynamic> data) => data['feature'] == 'buddy';
}
