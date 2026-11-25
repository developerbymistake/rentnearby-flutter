import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_stay_owner.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay/setup/stay_basic_details_screen.dart';
import 'package:bakhli/features/stay/setup/stay_onboarding_screen.dart';
import 'package:bakhli/features/stay/setup/stay_rooms_form.dart';
import 'package:bakhli/features/stay/setup/stay_rules_form.dart';
import 'package:bakhli/features/stay/setup/stay_setup_controller.dart';
import 'package:bakhli/features/stay_owner/widgets/stay_widgets.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:dio/dio.dart' hide Response;
import 'package:dio/dio.dart' as dio show Response;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import 'stay_setup_fixtures.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _open(WidgetTester t, {Widget home = const StayBasicDetailsScreen(onboarding: true)}) async {
  final view = t.view;
  view.devicePixelRatio = 1;
  view.physicalSize = const Size(360, 1500);
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });
  await t.pumpWidget(GetMaterialApp(
    theme: AppTheme.theme,
    home: home,
    getPages: [
      GetPage(name: AppRoutes.roleSelect, page: () => const Scaffold(body: Text('role page'))),
      GetPage(name: AppRoutes.main, page: () => const Scaffold(body: Text('main page'))),
    ],
    builder: (context, c) => Stack(fit: StackFit.expand, children: [Positioned.fill(child: c!), Overlay(key: AppToast.overlayKey)]),
  ));
  await _settle(t);
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 15));
}

void main() {
  setUpAll(() => initTestStorage('stay_onboarding_wizard_test'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  void expectNoPlanRows() {
    expect(find.byType(StayLockedAddRow), findsNothing);
    expect(find.byType(StayPlusBanner), findsNothing);
    expect(find.byKey(GateKeys.softRow), findsNothing);
    expect(find.textContaining('Plus'), findsNothing);
    expect(find.textContaining('Upgrade'), findsNothing);
    expect(find.text('Optional'), findsNothing);
    expect(find.text('OPTIONAL'), findsNothing);
  }

  void expectRoomFormRequiredTag() {
    expect(find.descendant(of: find.byType(FormSectionCard), matching: find.text('REQUIRED')), findsOneWidget);
    expectNoPlanRows();
  }

  testWidgets('a resumed draft opens on Rooms with 0 or 1 saved room and on Rules with 2', (t) async {
    setupFor(stayModel(draftJson(step1: true)));
    await _open(t);
    expect(find.text('Step 5 of 6'), findsOneWidget);
    expect(find.byType(FormSectionCard), findsNothing);
    expect(find.byType(RoomCard3D), findsNothing);
    expect(find.text('Add room'), findsOneWidget);
    expect(find.text('Next: Rules'), findsNothing);
    expect(find.byType(DashedAddRow3D), findsNothing);
    expectNoPlanRows();
    await _close(t);

    setupFor(stayModel(draftJson(step1: true, roomCount: 1)));
    await _open(t);
    expect(find.text('Step 5 of 6'), findsOneWidget);
    expect(find.text('Deluxe'), findsOneWidget);
    expect(find.byType(RoomCard3D), findsOneWidget);
    expect(find.byType(FormSectionCard), findsNothing);
    expect(find.text('Add room'), findsOneWidget);
    expect(find.text('Next: Rules'), findsNothing);
    expect(find.byType(DashedAddRow3D), findsNothing);
    expect(find.text('Add room type'), findsNothing);
    expectNoPlanRows();
    await _close(t);

    setupFor(stayModel(draftJson(step1: true, rooms: true)));
    await _open(t);
    expect(find.text('Step 6 of 6'), findsOneWidget);
    await _close(t);
  });

  testWidgets('Rooms Next saves rooms, Back returns and keeps input without a second save', (t) async {
    setupFor(stayModel(draftJson(step1: true, rooms: true)));
    await _open(t);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text('Step 5 of 6'), findsOneWidget);
    expect(find.byType(RoomCard3D), findsNWidgets(2));
    expect(find.text('Next: Rules'), findsOneWidget);
    expect(find.text('Add room'), findsNothing);
    expect(find.byType(DashedAddRow3D), findsNothing);
    expectNoPlanRows();
    await t.tap(find.byIcon(Icons.edit_rounded).last);
    await _settle(t);
    expect(find.text('Room 2'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Next: Rules'), findsNothing);
    expectRoomFormRequiredTag();
    await t.enterText(find.byType(TextField).last, '5000');
    await t.pump();
    await t.tap(find.text('Save'));
    await _settle(t);
    expect(FakeStayRepo.last!.calls, isEmpty);
    expect(find.byType(RoomCard3D), findsNWidgets(2));
    await t.tap(find.text('Next: Rules'));
    await _settle(t);
    expect(FakeStayRepo.last!.calls, ['rooms']);
    expect(FakeStayRepo.last!.lastRooms!.last['pricePerNight'], 5000);
    expect(find.text('Step 6 of 6'), findsOneWidget);
    await t.tap(find.text('Pets allowed'));
    await t.pump();
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text('Step 5 of 6'), findsOneWidget);
    expect(find.text('Deluxe'), findsOneWidget);
    expect(find.text('Family Room'), findsOneWidget);
    expect(find.byType(DashedAddRow3D), findsNothing);
    expect(find.text('Room 3'), findsNothing);
    expect(find.text('Add room'), findsNothing);
    await t.tap(find.text('Next: Rules'));
    await _settle(t);
    expect(FakeStayRepo.last!.calls, ['rooms']);
    await t.tap(find.text('Submit').last);
    await _settle(t);
    expect(FakeStayRepo.last!.lastRules?['petsAllowed'], isTrue);
    await _close(t);
  });

  testWidgets('Submit saves rules then submits and opens main', (t) async {
    setupFor(stayModel(draftJson(step1: true, rooms: true)));
    await _open(t);
    expect(find.text('Step 6 of 6'), findsOneWidget);
    expect(find.text('Dashboard opens after submit'), findsOneWidget);
    await t.tap(find.text('Submit').last);
    await _settle(t);
    expect(FakeStayRepo.last!.calls, ['rules', 'submit']);
    expect(find.text('main page'), findsOneWidget);
    await _close(t);
  });

  testWidgets('a failed rules save keeps the page and input; retry submits', (t) async {
    setupFor(stayModel(draftJson(step1: true, rooms: true)));
    FakeStayRepo.last!.failOnce.add('rules');
    await _open(t);
    await t.tap(find.text('Pets allowed'));
    await t.pump();
    await t.tap(find.text('Submit').last);
    await _settle(t);
    expect(FakeStayRepo.last!.calls, ['rules']);
    expect(find.text('Step 6 of 6'), findsOneWidget);
    await t.tap(find.text('Submit').last);
    await _settle(t);
    expect(FakeStayRepo.last!.calls, ['rules', 'rules', 'submit']);
    expect(FakeStayRepo.last!.lastRules?['petsAllowed'], isTrue);
    await _close(t);
  });

  testWidgets('Back on page 1 opens role correction only when allowed', (t) async {
    setupFor(null, canCorrect: false);
    await _open(t);
    expect(find.text('Step 1 of 6'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text('role page'), findsNothing);
    expect(find.text('Step 1 of 6'), findsOneWidget);
    await _close(t);

    setupFor(null);
    await _open(t);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text('role page'), findsOneWidget);
    await _close(t);
  });

  testWidgets('a Submit retry after a lost response (409 StayLocked, server under review) opens main', (t) async {
    setupFor(stayModel(draftJson(step1: true, rooms: true, rules: true)));
    final repo = FakeStayRepo.last!
      ..model = stayModel(draftJson(step1: true, rooms: true, rules: true, status: 'PendingReview'))
      ..error = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: dio.Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 409,
          data: {
            'error': {'type': 'StayLocked', 'message': 'Your stay is under review.'},
          },
        ),
        type: DioExceptionType.badResponse,
      );
    await _open(t);
    await t.tap(find.text('Submit').last);
    await _settle(t);
    expect(repo.calls, ['submit']);
    expect(find.text('main page'), findsOneWidget);
    await _close(t);
  });

  testWidgets('gate: a Rejected stay opened without My Stays below goes to main, not the wizard', (t) async {
    setupFor(stayModel(draftJson(step1: true, rooms: true, rules: true, status: 'Rejected')));
    await _open(t, home: const StayOnboardingScreen());
    expect(find.text('main page'), findsOneWidget);
    expect(find.byType(StayBasicDetailsScreen), findsNothing);
    await _close(t);
  });

  Future<void> fillRoom(WidgetTester t, {required String name, required String price, required String guests, required String meals}) async {
    await t.tap(find.text('Select'));
    await _settle(t);
    await t.tap(find.text(name).last);
    await _settle(t);
    await t.enterText(find.byType(TextField).last, price);
    await t.tap(find.descendant(of: find.byKey(const ValueKey('stay-room-guests')), matching: find.text(guests)));
    await t.tap(find.descendant(of: find.byKey(const ValueKey('stay-room-meals')), matching: find.text(meals)));
    await t.pump();
  }

  testWidgets('a new stay: Add room, Save, Add room, Save, then Next: Rules saves both rooms', (t) async {
    setupFor(stayModel(draftJson(step1: true)));
    await _open(t);
    expect(find.text('Add room'), findsOneWidget);
    expect(find.byType(FormSectionCard), findsNothing);

    await t.tap(find.text('Add room'));
    await _settle(t);
    expect(find.text('Room 1'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Add room'), findsNothing);
    expectRoomFormRequiredTag();

    await fillRoom(t, name: 'Standard', price: '1500', guests: '2', meals: 'Breakfast');
    await t.tap(find.text('Save'));
    await _settle(t);
    expect(find.byType(RoomCard3D), findsOneWidget);
    expect(find.byType(FormSectionCard), findsNothing);
    expect(find.text('Add room'), findsOneWidget);
    expect(find.text('Next: Rules'), findsNothing);
    expect(FakeStayRepo.last!.calls, isEmpty);

    await t.tap(find.text('Add room'));
    await _settle(t);
    expect(find.text('Room 2'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    await fillRoom(t, name: 'Suite', price: '3800', guests: '4+', meals: 'All meals');
    await t.tap(find.text('Save'));
    await _settle(t);
    expect(find.byType(RoomCard3D), findsNWidgets(2));
    expect(find.text('Add room'), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Next: Rules'), findsOneWidget);
    expect(find.byType(DashedAddRow3D), findsNothing);
    expectNoPlanRows();
    expect(FakeStayRepo.last!.calls, isEmpty);

    await t.tap(find.text('Next: Rules'));
    await _settle(t);
    expect(FakeStayRepo.last!.calls, ['rooms']);
    expect([for (final r in FakeStayRepo.last!.lastRooms!) r['roomName']], ['Standard', 'Suite']);
    expect(find.text('Step 6 of 6'), findsOneWidget);
    await _close(t);
  });

  testWidgets('one saved room: Add room opens Room 2; deleting rooms goes back to Add room with no form', (t) async {
    setupFor(stayModel(draftJson(step1: true, roomCount: 1)));
    await _open(t);
    expect(find.text('Deluxe'), findsOneWidget);
    expect(find.text('Next: Rules'), findsNothing);
    await t.tap(find.text('Add room'));
    await _settle(t);
    expect(find.text('Room 2'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Next: Rules'), findsNothing);
    expect(FakeStayRepo.last!.calls, isEmpty);
    await _close(t);

    setupFor(stayModel(draftJson(step1: true, rooms: true)));
    await _open(t);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text('Next: Rules'), findsOneWidget);
    await t.tap(find.descendant(of: find.byType(RoomCard3D), matching: find.byIcon(Icons.close_rounded)).last);
    await _settle(t);
    expect(find.byType(RoomCard3D), findsOneWidget);
    expect(find.byType(FormSectionCard), findsNothing);
    expect(find.text('Add room'), findsOneWidget);
    expect(find.text('Next: Rules'), findsNothing);
    await t.tap(find.descendant(of: find.byType(RoomCard3D), matching: find.byIcon(Icons.close_rounded)).last);
    await _settle(t);
    expect(find.byType(RoomCard3D), findsNothing);
    expect(find.byType(FormSectionCard), findsNothing);
    expect(find.text('Add room'), findsOneWidget);
    expect(FakeStayRepo.last!.calls, isEmpty);
    expectNoPlanRows();
    await _close(t);
  });

  testWidgets('Back on page 1 of a clean Fix-and-resubmit leaves without a discard dialog', (t) async {
    final c = setupFor(stayModel(draftJson(step1: true, rooms: true, rules: true, status: 'Rejected')), stayStatus: 'Rejected');
    c.mainBelow = true;
    await _open(t, home: const Scaffold(body: Text('below')));
    Get.to<void>(() => const StayBasicDetailsScreen(onboarding: true));
    await _settle(t);
    expect(find.text('Step 1 of 6'), findsOneWidget);
    await t.binding.handlePopRoute();
    await _settle(t);
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('below'), findsOneWidget);
    await _close(t);
  });

  StayRoomsFormController rooms() => StayRoomsFormController(onboarding: true, ctrl: StaySetupController(repo: FakeStayRepo(null)));

  void fill(StayRoomsFormController c) => c
    ..roomName = 'Deluxe'
    ..priceCtrl.text = '1500'
    ..guests = 2
    ..meals = 'Breakfast';

  void fillSecond(StayRoomsFormController c) => c
    ..roomName = 'Family Room'
    ..priceCtrl.text = '2500'
    ..guests = 4
    ..meals = 'AllMeals';

  test('onboarding rooms: no form first, Add opens Room 1, Save, Add opens Room 2, Save, then Next; a third is impossible', () {
    final c = rooms()..seed(null);
    expect(c.max, 2);
    expect(c.formOpen, isFalse);
    expect(c.action, StayRoomsAction.add);
    expect(c.count, 0);
    c.openForm();
    expect(c.formOpen, isTrue);
    expect(c.action, StayRoomsAction.save);
    expect(c.commitForm(), isFalse);
    expect(c.rooms, isEmpty);
    expect(c.formOpen, isTrue);
    fill(c);
    expect(c.commitForm(), isTrue);
    expect(c.rooms.length, 1);
    expect(c.formOpen, isFalse);
    expect(c.action, StayRoomsAction.add);
    expect(c.validate(), isFalse);
    c.openForm();
    expect(c.action, StayRoomsAction.save);
    expect(c.count, 2);
    fillSecond(c);
    expect(c.commitForm(), isTrue);
    expect(c.action, StayRoomsAction.next);
    expect(c.validate(), isTrue);
    expect(c.payload().length, 2);
    c.openForm();
    c.addAnother();
    expect(c.formOpen, isFalse);
    expect(c.count, 2);
    expect(c.action, StayRoomsAction.next);
    c.dispose();
  });

  test('onboarding rooms: one saved room shows Add room, not a form', () {
    final c = rooms()..seed(stayModel(draftJson(step1: true, roomCount: 1)));
    expect(c.rooms.length, 1);
    expect(c.formOpen, isFalse);
    expect(c.action, StayRoomsAction.add);
    expect(c.validate(), isFalse);
    expect(c.rooms.length, 1);
    c.openForm();
    fillSecond(c);
    expect(c.commitForm(), isTrue);
    expect(c.validate(), isTrue);
    expect(c.payload().length, 2);
    c.dispose();
  });

  test('onboarding rooms: removing a room goes back to Add room, removing both opens no form', () {
    final c = rooms()..seed(stayModel(draftJson(step1: true, rooms: true)));
    expect(c.formOpen, isFalse);
    expect(c.action, StayRoomsAction.next);
    c.removeRoom(1);
    expect(c.formOpen, isFalse);
    expect(c.action, StayRoomsAction.add);
    c.removeRoom(0);
    expect(c.formOpen, isFalse);
    expect(c.action, StayRoomsAction.add);
    c.dispose();
  });

  test('onboarding rooms: edit opens the form with Save and keeps the room count', () {
    final c = rooms()..seed(stayModel(draftJson(step1: true, rooms: true)));
    c.editRoom(0);
    expect(c.action, StayRoomsAction.save);
    expect(c.rooms.length, 1);
    expect(c.commitForm(), isTrue);
    expect(c.rooms.first.name, 'Deluxe');
    expect(c.action, StayRoomsAction.next);
    c.dispose();
  });

  test('onboarding rooms cap is the fixed Free value with the plan not loaded or on Plus', () {
    setupFor(null);
    PlanGate.debugPlan = null;
    final a = rooms()..seed(null);
    expect(a.max, 2);
    PlanGate.debugPlan = OwnerPlans.plus;
    final b = rooms()..seed(null);
    expect(b.max, 2);
    expect(StayRoomsFormController(onboarding: false, ctrl: StaySetupController(repo: FakeStayRepo(null))).max, greaterThan(2));
    a.dispose();
    b.dispose();
  });

  test('changedSince: saved rooms and rules are clean, a typed room or a rule edit is a change', () {
    final c = rooms()..seed(stayModel(draftJson(step1: true, rooms: true)));
    final saved = c.key;
    expect(c.changedSince(saved), isFalse);
    c.editRoom(1);
    expect(c.changedSince(saved), isTrue);
    expect(c.validate(), isTrue);
    expect(c.changedSince(saved), isFalse);
    final fresh = rooms()..seed(null);
    expect(fresh.changedSince(null), isFalse);
    fresh.setGuests(2);
    expect(fresh.changedSince(null), isTrue);
    c.dispose();
    fresh.dispose();

    final r = StayRulesFormController()..seed(stayModel(draftJson(rules: true)));
    final rules = r.key;
    expect(r.changedSince(rules), isFalse);
    r.update(() => r.pets = true);
    expect(r.changedSince(rules), isTrue);
    r.update(() => r.pets = false);
    expect(r.changedSince(rules), isFalse);
  });
}
