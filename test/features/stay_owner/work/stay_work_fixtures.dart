import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiries_controller.dart';
import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/stay_owner/enquiries_tab/stay_work_format.dart';
import 'package:bakhli/features/stay_owner/notices/stay_notice_copy.dart';
import 'package:bakhli/features/stay_owner/reminder/stay_reminder_row.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:get/get.dart';

final DateTime frameNow = DateTime(2026, 11, 21);

String iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> enquiryJson({
  required String id,
  required String name,
  String status = 'Asked',
  String display = 'asked',
  String checkIn = '2026-11-24',
  String checkOut = '2026-11-26',
  int adults = 3,
  int rooms = 1,
  String? phone = '9876543210',
  int? listed = 6000,
  List<Map<String, dynamic>>? breakdown,
  Duration? expiresIn = const Duration(hours: 2),
  Map<String, dynamic>? openOffer,
  Map<String, dynamic>? acceptedOffer,
  Map<String, dynamic>? pendingCounter,
  Map<String, dynamic>? pendingChange,
  Map<String, dynamic>? pendingRevised,
  int offerCount = 0,
  int counterCount = 0,
  int? agreedTotal,
  String? closedKind,
  String? cancelReason,
  String? calendarEntryId,
  bool problemReported = false,
  String? confirmedAt,
  String? cancelledAt,
  String city = 'Nainital',
}) =>
    {
      'id': id,
      'kind': 'Stay',
      'listingId': 'stay-1',
      'listingName': 'Deodar Heights Homestay',
      'checkIn': checkIn,
      'checkOut': checkOut,
      'tripStartDate': checkIn,
      'status': status,
      'displayStatus': display,
      'expiresAt': expiresIn == null ? null : iso(frameNow.add(expiresIn)),
      'conversationId': 'conv-$id',
      'traveller': {'id': 'trav-$id', 'name': name, 'phone': phone},
      'context': {'city': city, 'adults': adults, 'rooms': rooms},
      'offerCount': offerCount,
      'counterCount': counterCount,
      'agreedTotal': ?agreedTotal,
      'openOffer': ?openOffer,
      'acceptedOffer': ?acceptedOffer,
      'pendingCounter': ?pendingCounter,
      'pendingChange': ?pendingChange,
      'pendingRevised': ?pendingRevised,
      'cancelReason': ?cancelReason,
      'listedStayTotal': ?listed,
      'listedBreakdown': breakdown ?? [
        {'roomName': 'Deluxe Room', 'units': 1, 'nights': 2, 'perNight': 3000, 'specialLabel': null},
      ],
      'closedKind': ?closedKind,
      'calendarEntryId': ?calendarEntryId,
      'problemReported': problemReported,
      'confirmedAt': ?confirmedAt,
      'cancelledAt': ?cancelledAt,
    };

Map<String, dynamic> offerJson({
  String id = 'o1',
  String kind = 'Offer',
  String room = 'Deluxe Room',
  int perNight = 3000,
  int units = 1,
  int nights = 2,
  int? total,
  String? validUntil,
  String checkIn = '2026-11-27',
  String checkOut = '2026-11-29',
  int? adults,
  int? proposed,
  String? respondedAt,
}) =>
    {
      'id': id,
      'kind': kind,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'nights': nights,
      'lines': [
        {'roomName': room, 'units': units, 'guests': 2, 'pricePerNight': perNight},
      ],
      'total': total ?? perNight * units * nights,
      'validUntil': ?validUntil,
      'adults': ?adults,
      'proposedPerNight': ?proposed,
      'respondedAt': ?respondedAt,
      'status': 'Pending',
    };

Map<String, dynamic> pageJson(List<Map<String, dynamic>> items, {int newCount = 0, int offered = 0, int confirmed = 0, int changeRequests = 0}) => {
      'data': {
        'items': items,
        'hasMore': false,
        'counts': {'new': newCount, 'offered': offered, 'confirmed': confirmed, 'closed': 0, 'changeRequests': changeRequests},
      },
    };

final stayFixture = StayOwnerModel.fromJson({'id': 'stay-1', 'name': 'Deodar Heights Homestay', 'status': 'Approved'});

/// Fresh controller with a fake owner list; returns the controller.
StayEnquiriesController setUpEnquiries(Map<String, Map<String, dynamic>> byBucket, {MyPlanModel plan = const MyPlanModel(paymentEnabled: true, trialAvailable: true)}) {
  Get.reset();
  PlanGate.debugPlan = plan;
  StayNoticeCopy.debugPlan = plan;
  StayWorkFormat.now = () => frameNow;
  StayEnquiriesController.debugFetch = (status, page, size) async => byBucket[status] ?? pageJson(const []);
  final c = StayEnquiriesController.ensure();
  c.stay.value = stayFixture;
  return c;
}

void tearDownWork() {
  StayEnquiriesController.debugFetch = null;
  PlanGate.debugPlan = null;
  StayNoticeCopy.debugPlan = null;
  StayWorkFormat.now = DateTime.now;
  StayReminderState.reset();
  Get.reset();
}
