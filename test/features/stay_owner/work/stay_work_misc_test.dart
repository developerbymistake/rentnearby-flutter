import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/owner_core/calendar/calendar_api.dart';
import 'package:bakhli/features/owner_core/calendar/models/calendar_models.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/session/owner_notice_registry.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiry_owner_view.dart';
import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/stay/setup/stay_setup_controller.dart';
import 'package:bakhli/features/stay/setup/stay_share_details_screen.dart';
import 'package:bakhli/features/stay_owner/notices/stay_notice_copy.dart';
import 'package:bakhli/features/stay_owner/reminder/stay_reminder_row.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/plan_model.dart';
import 'package:bakhli/features/owner_core/plan/plan_keys.dart';
import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/screens/profile/profile_rows.dart';
import 'package:bakhli/utils/notification_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';

const _free = MyPlanModel(paymentEnabled: true, trialAvailable: true);

class _FakeSetup extends StaySetupController {
  _FakeSetup(StayOwnerModel s) {
    stay.value = s;
  }

  final saved = <String>[];

  @override
  Future<bool> load() async {
    hasLoaded.value = true;
    return true;
  }

  @override
  Future<bool> saveShareDetails({String? upiId, String? whatsAppNumber}) async {
    saved.add('$upiId|$whatsAppNumber');
    return true;
  }
}

PlanModel _plan({required bool isDefault, int trialDays = 0, int photos = 2, int roomTypes = 2}) => PlanModel(
      id: isDefault ? 'free' : 'plus',
      featureKey: 'Stay',
      code: isDefault ? 'FREE' : 'PLUS',
      name: isDefault ? 'Free' : 'Plus',
      tagline: null,
      isDefault: isDefault,
      trialDays: trialDays,
      features: isDefault ? {PlanKey.photos.wire: photos, PlanKey.roomTypes.wire: roomTypes} : const {},
      prices: const [],
    );

Notice _n(String kind, {String? refTitle, String? refId, Map<String, dynamic> args = const {}}) =>
    Notice(id: 'n1', kind: kind, count: 1, isRead: false, refTitle: refTitle, refId: refId, args: args);

Widget _rowHost() => const Scaffold(backgroundColor: Color(0xFFD8EEDA), body: SafeArea(child: Column(children: [StayReminderRow()])));

void main() {
  setUpAll(() => initTestStorage('a3_misc'));
  tearDown(() {
    PlanGate.debugPlan = null;
    StayNoticeCopy.debugPlan = null;
    StayNoticeCopy.debugCatalog = null;
    StayReminderState.reset();
    OwnerNoticeRegistry.reset();
    OwnerApi.debugReset();
    Get.reset();
  });

  group('owner view model', () {
    final sample = {
      'id': 'e1',
      'listedStayTotal': 9600,
      'listedBreakdown': [
        {'roomName': 'Deluxe Room', 'units': 1, 'nights': 2, 'perNight': 3000, 'specialLabel': null},
        {'roomName': 'Deluxe Room', 'units': 1, 'nights': 1, 'perNight': 3600, 'specialLabel': 'Diwali price'},
      ],
      'calendarEntryId': 'cal-1',
      'closedKind': 'Expired',
      'problemReported': true,
      'confirmedAt': '2026-11-21T09:00:00Z',
      'cancelledAt': '2026-11-21T09:00:00Z',
    };

    test('parse never throws over jsonVariants', () {
      for (final v in jsonVariants(sample)) {
        expect(() => StayEnquiryOwnerView.fromJson(v), returnsNormally);
      }
      final v = StayEnquiryOwnerView.fromJson(sample);
      expect(v.listedStayTotal, 9600);
      expect(v.listedBreakdown.length, 2);
      expect(v.listedBreakdown.last.specialLabel, 'Diwali price');
    });

    test('closed kind from status when the server sends none, unknown stays unknown', () {
      const v = StayEnquiryOwnerView.empty;
      expect(v.closedKind(const TripEnquiryModel(id: 'a', status: 'Expired')), StayClosedKind.expired);
      expect(v.closedKind(const TripEnquiryModel(id: 'a', status: 'Expired', offerCount: 1)), StayClosedKind.offerExpired);
      expect(v.closedKind(const TripEnquiryModel(id: 'a', status: 'CancelledByOwner')), StayClosedKind.cancelledByOwner);
      expect(v.closedKind(const TripEnquiryModel(id: 'a', status: 'BookedByTraveller')), StayClosedKind.bookedByPhone);
      expect(StayEnquiryOwnerView.fromJson(const {'closedKind': 'Weird'}).closedKind(const TripEnquiryModel(id: 'a')), StayClosedKind.unknown);
    });
  });

  group('o_st_68 notice copy and routes', () {
    test('o_st_68_stayEditApproved and rejected copy, open My Stay', () {
      final a = StayNoticeCopy.of(_n('StayEditApproved', refTitle: 'Deodar Heights Mountain Homestay'))!;
      expect(a.title, 'Your change is live');
      expect(a.body, 'Name updated to Deodar Heights Mountain Homestay');
      expect(a.tag, 'STAY');
      expect(a.route, '/my-stays');
      final r = StayNoticeCopy.of(_n('StayEditRejected', refTitle: 'The name must match your registration.'))!;
      expect(r.title, 'Change not approved');
      expect(r.body, 'The name must match your registration.');
    });

    test('o_st_22_festivalRowFixedText_notPushTitle and opens Special price sheet with dates', () {
      final f = StayNoticeCopy.of(_n('FestivalReminder', refTitle: 'Diwali', refId: 'f1', args: {'dateFrom': '2026-11-06', 'dateTo': '2026-11-12'}))!;
      expect(f.title, 'Diwali week starts 6 Nov');
      expect(f.body, 'Set your price for those days.');
      expect(f.tag, 'PRICE');
      expect(f.route, '/stay-special-prices');
      expect(f.args, {'festivalId': 'f1', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12'});
      expect(StayNoticeCopy.of(_n('FestivalReminder')), isNull);
    });

    test('o_st_68_planLimitsChanged uses hidden counts, opens Choose what stays', () {
      StayNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true, hidden: PlanHiddenModel(photos: 4, roomTypes: 2));
      final p = StayNoticeCopy.of(_n('PlanLimitsChanged'))!;
      expect(p.title, 'Plans have started');
      expect(p.body, '4 photos and 2 room types are hidden on Free. Nothing is deleted.');
      expect(p.route, '/stay-plan-visible');
      StayNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true);
      expect(StayNoticeCopy.of(_n('PlanLimitsChanged')), isNull);
    });

    test('PlansStarting copy, trial sentence only while trialAvailable', () {
      StayNoticeCopy.debugCatalog = [_plan(isDefault: true), _plan(isDefault: false, trialDays: 7)];
      StayNoticeCopy.debugPlan = MyPlanModel(paymentEnabled: false, trialAvailable: true, paymentStartsOn: DateTime(2027, 2, 1));
      final s = StayNoticeCopy.of(_n('PlansStarting'))!;
      expect(s.title, 'Plans start on 1 Feb');
      expect(s.body, 'Free keeps 2 photos and 2 room types. Try Plus free for 7 days.');
      expect(s.route, '/plans');
      StayNoticeCopy.debugPlan = MyPlanModel(paymentEnabled: false, paymentStartsOn: DateTime(2027, 2, 1));
      expect(StayNoticeCopy.of(_n('PlansStarting'))!.body, 'Free keeps 2 photos and 2 room types.');
    });

    test('FS-18 PlansStarting numbers come from the catalog; no paid trial plan, no trial sentence', () {
      StayNoticeCopy.debugCatalog = [_plan(isDefault: true, photos: 3, roomTypes: 1), _plan(isDefault: false, trialDays: 14)];
      StayNoticeCopy.debugPlan = MyPlanModel(paymentEnabled: false, trialAvailable: true, paymentStartsOn: DateTime(2027, 2, 1));
      expect(StayNoticeCopy.of(_n('PlansStarting'))!.body, 'Free keeps 3 photos and 1 room type. Try Plus free for 14 days.');
      StayNoticeCopy.debugCatalog = [_plan(isDefault: true, photos: 3, roomTypes: 1), _plan(isDefault: false)];
      expect(StayNoticeCopy.of(_n('PlansStarting'))!.body, 'Free keeps 3 photos and 1 room type.');
    });

    test('FS-18 PlanLimitsChanged with only paused special prices opens the Special prices list', () {
      StayNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true, hidden: PlanHiddenModel(specialPrices: 2));
      final p = StayNoticeCopy.of(_n('PlanLimitsChanged'))!;
      expect(p.body, '2 special prices are paused on Free. Nothing is deleted.');
      expect(p.route, '/stay-special-prices');
    });

    test('PlanLimitsChanged with only inactive jobs opens My jobs', () {
      StayNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true, pausedByPlanCount: 1);
      final p = StayNoticeCopy.of(_n('PlanLimitsChanged'))!;
      expect(p.title, 'Jobs inactive');
      expect(p.body, 'Some jobs are inactive on Free.');
      expect(p.route, '/my-jobs');
      StayNoticeCopy.debugPlan = const MyPlanModel(paymentEnabled: true, pausedByPlanCount: 3, hidden: PlanHiddenModel(specialPrices: 2));
      expect(StayNoticeCopy.of(_n('PlanLimitsChanged'))!.route, '/stay-special-prices');
    });

    test('registry: registered kinds render, unknown kind hidden, no money or calendar edit kinds', () {
      StayNoticeCopy.register();
      for (final k in StayNoticeKinds.all) {
        expect(OwnerNoticeRegistry.knows(k), isTrue, reason: k);
      }
      expect(OwnerNoticeRegistry.of(_n('SomethingNew')), isNull);
      for (final k in StayNoticeKinds.all) {
        expect(k.toLowerCase().contains('money') || k.toLowerCase().contains('block') || k.toLowerCase().contains('advance'), isFalse);
      }
    });

    test('o_st_22 inbox kind labels by route and type', () {
      expect(NotificationVisuals.listingKind('/stay-enquiries'), 'ENQUIRY');
      expect(NotificationVisuals.listingKind('/plans'), 'PLAN');
      expect(NotificationVisuals.listingKind('/stay-special-prices'), 'PRICE');
      expect(NotificationVisuals.listingKind('/stay-enquiries', type: 'TripChangeRequest'), 'CHANGE REQUEST');
      expect(NotificationVisuals.listingKind('/stay-enquiries', type: 'trip_problem_reported'), 'BOOKING');
      expect(NotificationVisuals.listingKind('/my-stays'), 'STAY');
    });
  });

  group('o_st_66 reminder row', () {
    testWidgets('o_st_66_a_plusSwitchRowTexts', (t) async {
      PlanGate.debugPlan = OwnerPlans.plus;
      StayReminderState.value.value = const CalendarReminder(allowed: true, on: true);
      await pumpPhone(t, _rowHost());
      expect(find.text('Morning reminder'), findsOneWidget);
      expect(find.text('8:00 am on days with a check-in'), findsOneWidget);
      expect(find.text('Needs notifications on this phone.'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byKey(GateKeys.softRow), findsNothing);
    });

    testWidgets('o_st_66_c_freeLockedRow_seePlusNoSheet', (t) async {
      PlanGate.debugPlan = _free;
      StayReminderState.value.value = const CalendarReminder(allowed: false, on: false);
      await pumpPhone(t, _rowHost());
      expect(find.text('Plus sends it at 8:00 am'), findsOneWidget);
      expect(find.text('See Plus'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('o_st_66_paymentOff_openNoLockNoPlusPill_guardKeys', (t) async {
      PlanGate.debugPlan = OwnerPlans.paymentOff;
      StayReminderState.value.value = const CalendarReminder(allowed: false, on: false);
      await pumpPhone(t, _rowHost());
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
      expect(find.textContaining('Plus'), findsNothing);
    });

    testWidgets('FS-02 tap on with the real server body: the switch stays on', (t) async {
      PlanGate.debugPlan = OwnerPlans.plus;
      StayReminderState.value.value = const CalendarReminder(allowed: true, on: false);
      OwnerApi.transport = FakeTransport((m, p, b) async => {
            'data': {
              'reminder': {'allowed': true, 'on': b?['on'] == true},
            },
          });
      StayReminderState.api = const CalendarApi('/stays/me/calendar');
      await pumpPhone(t, _rowHost(), toastHost: true);
      await t.tap(find.byType(Switch));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      expect(StayReminderState.value.value?.on, isTrue);
      expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('o_st_66_a_toggleOptimisticRollback on refusal', (t) async {
      PlanGate.debugPlan = OwnerPlans.plus;
      StayReminderState.value.value = const CalendarReminder(allowed: true, on: false);
      OwnerApi.transport = FakeTransport((m, p, b) async => throw Exception('down'));
      StayReminderState.api = const CalendarApi('/stays/me/calendar');
      await pumpPhone(t, _rowHost(), toastHost: true);
      await t.tap(find.byType(Switch));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      expect(StayReminderState.value.value?.on, isFalse);
      await t.pump(const Duration(seconds: 5));
    });

    testOwnerSizes('reminder row', _rowHost, setUpEach: () {
      PlanGate.debugPlan = _free;
      StayReminderState.value.value = const CalendarReminder(allowed: false, on: false);
    });

    testWidgets('render o_st_66_a', (t) async {
      PlanGate.debugPlan = OwnerPlans.plus;
      StayReminderState.value.value = const CalendarReminder(allowed: true, on: true);
      await renderOwnerFrame(t, 'o_st_66', _rowHost(), part: 'A');
    });

    testWidgets('render o_st_66_c', (t) async {
      PlanGate.debugPlan = _free;
      StayReminderState.value.value = const CalendarReminder(allowed: false, on: false);
      await renderOwnerFrame(t, 'o_st_66', _rowHost(), part: 'C');
    });
  });

  group('o_st_38 share details', () {
    final stay = StayOwnerModel.fromJson({'id': 's', 'name': 'Deodar Heights', 'status': 'Approved', 'upiId': 'meena.bisht@okaxis', 'whatsAppNumber': '9837041122'});

    test('validators', () {
      expect(_validUpi('meena.bisht@okaxis'), isNull);
      expect(_validUpi(''), isNull);
      expect(_validUpi('a@b'), 'Enter a valid UPI ID, like name@bank.');
      expect(_validUpi('meena.bisht'), 'Enter a valid UPI ID, like name@bank.');
      expect(_validUpi('${'a' * 58}@ok'), 'Enter a valid UPI ID, like name@bank.');
      expect(_validWa('9837041122'), isNull);
      expect(_validWa(''), isNull);
      expect(_validWa('98370'), 'Enter a 10-digit WhatsApp number.');
    });

    testWidgets('o_st_38 page texts, no payment words', (t) async {
      Get.put<StaySetupController>(_FakeSetup(stay));
      await pumpPhone(t, const StayShareDetailsScreen());
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('UPI and WhatsApp'), findsOneWidget);
      expect(find.text('Your contact details'), findsOneWidget);
      expect(find.text('Contact details'), findsOneWidget);
      expect(find.text('Shared with a guest only when you choose'), findsOneWidget);
      expect(find.text('UPI ID'), findsOneWidget);
      expect(find.text('WhatsApp number'), findsOneWidget);
      expect(find.text('Optional'), findsNWidgets(2));
      expect(find.text('You share these from a confirmed booking, one tap. Nobody sees them before that.'), findsOneWidget);
      expect(find.text('The app does not take, hold or track payments. Settle money with the guest directly.'), findsOneWidget);
      expect(find.text('Remove my details'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.textContaining('dvance'), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
    });

    testWidgets('o_st_38_removeMyDetailsClearsBoth', (t) async {
      final fake = _FakeSetup(stay);
      Get.put<StaySetupController>(fake);
      await pumpPhone(t, const StayShareDetailsScreen(), toastHost: true);
      await t.pump(const Duration(milliseconds: 300));
      await t.ensureVisible(find.text('Remove my details'));
      await t.tap(find.text('Remove my details'));
      await t.pump(const Duration(milliseconds: 300));
      expect(fake.saved, ['|']);
      await t.pump(const Duration(seconds: 5));
    });

    testOwnerSizes('share details page', () => const StayShareDetailsScreen(), setUpEach: () {
      Get.reset();
      Get.put<StaySetupController>(_FakeSetup(stay));
    });

    testWidgets('render o_st_38', (t) async {
      Get.put<StaySetupController>(_FakeSetup(stay));
      await renderOwnerFrame(t, 'o_st_38', const StayShareDetailsScreen());
    });
  });

  group('o_st_23 profile rows', () {
    test('o_st_23_noJobsFeedRow for owner shells, kept for Seeker', () {
      expect(ProfileRows.showsJobsFeed(ShellKind.stayOwner), isFalse);
      expect(ProfileRows.showsJobsFeed(ShellKind.taxiDriver), isFalse);
      expect(ProfileRows.showsJobsFeed(ShellKind.seeker), isTrue);
    });
  });
}

String? _validUpi(String v) => StayShareDetailsScreenValidators.upi(v);
String? _validWa(String v) => StayShareDetailsScreenValidators.whatsApp(v);
