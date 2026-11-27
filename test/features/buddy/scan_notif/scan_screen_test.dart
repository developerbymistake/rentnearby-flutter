import 'package:bakhli/features/buddy/scan/controllers/scan_controller.dart';
import 'package:bakhli/features/buddy/scan/scan_outcome.dart';
import 'package:bakhli/features/buddy/scan/screens/scan_qr_screen.dart';
import 'package:bakhli/features/buddy/scan/scan_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/buddy_render.dart';
import '../../../support/five_sizes.dart';
import '../../../support/real_phone.dart';
import 'scan_rules_test.dart';

void Function(String?)? _read;
void scanRead(String? raw) => _read!(raw);
const _cameraKey = ValueKey('fake_camera');

Widget screenFor(FakeGate gate, List<ScanOutcome?> pops, {DateTime Function()? clock}) => ScanQrScreen(
      permission: gate,
      ownUsername: () => 'Bakhli#11111111',
      clock: clock,
      haptic: () async {},
      onPop: pops.add,
      cameraBuilder: (context, onRead) {
        _read = onRead;
        return const SizedBox.expand(key: _cameraKey);
      },
    );

Future<void> _open(WidgetTester t, FakeGate gate, List<ScanOutcome?> pops, {DateTime Function()? clock}) async {
  await pumpPhone(t, screenFor(gate, pops, clock: clock));
  await t.pump();
  await t.pump();
}

void main() {
  useBuddyRenderScale();
  FakeGate granted() => FakeGate([CameraAccess.granted]);

  testWidgets('scanning: texts, camera mounted, back pops null', (t) async {
    final pops = <ScanOutcome?>[];
    await _open(t, granted(), pops);
    expect(find.text(ScanStrings.title), findsOneWidget);
    expect(find.text(ScanStrings.subtitle), findsOneWidget);
    expect(find.text(ScanStrings.hint), findsOneWidget);
    expect(find.text(ScanStrings.typeUsername), findsOneWidget);
    expect(find.byKey(_cameraKey), findsOneWidget);
    await t.tap(find.bySemanticsLabel(ScanStrings.back));
    expect(pops, [null]);
  });

  testWidgets('scanning: Type username pops the type-instead outcome', (t) async {
    final pops = <ScanOutcome?>[];
    await _open(t, granted(), pops);
    await t.tap(find.text(ScanStrings.typeUsername));
    expect(pops, [const ScanTypeInstead()]);
  });

  testWidgets('good read pops the username once', (t) async {
    final pops = <ScanOutcome?>[];
    await _open(t, granted(), pops);
    _read!('Bakhli#22222222');
    _read!('Bakhli#33333333');
    await t.pump();
    expect(pops, [const ScanFound('Bakhli#22222222')]);
  });

  testWidgets('not a Bakhli QR: card, camera gone, text never shown, scan again resumes', (t) async {
    final pops = <ScanOutcome?>[];
    await _open(t, granted(), pops);
    _read!('https://secret.example/pay');
    await t.pump();
    expect(find.text(ScanStrings.notBakhliTitle), findsOneWidget);
    expect(find.text(ScanStrings.notBakhliBody), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.byKey(_cameraKey), findsNothing);
    await t.tap(find.text(ScanStrings.scanAgain));
    await t.pump();
    expect(find.byKey(_cameraKey), findsOneWidget);
    expect(find.text(ScanStrings.notBakhliTitle), findsNothing);
    expect(pops, isEmpty);
  });

  testWidgets('not a Bakhli QR: Type username pops the type-instead outcome', (t) async {
    final pops = <ScanOutcome?>[];
    await _open(t, granted(), pops);
    _read!('hello');
    await t.pump();
    await t.tap(find.text(ScanStrings.typeUsername));
    expect(pops, [const ScanTypeInstead()]);
  });

  testWidgets('own QR card and scan again', (t) async {
    final pops = <ScanOutcome?>[];
    await _open(t, granted(), pops);
    _read!('Bakhli#11111111');
    await t.pump();
    expect(find.text(ScanStrings.ownTitle), findsOneWidget);
    expect(find.text(ScanStrings.ownBody), findsOneWidget);
    expect(pops, isEmpty);
    await t.tap(find.text(ScanStrings.scanAgain));
    await t.pump();
    expect(find.byKey(_cameraKey), findsOneWidget);
  });

  testWidgets('camera off: no preview, Allow camera asks again then Open settings', (t) async {
    final gate = FakeGate([CameraAccess.denied], requests: [CameraAccess.denied, CameraAccess.permanentlyDenied]);
    final pops = <ScanOutcome?>[];
    await _open(t, gate, pops);
    expect(find.text(ScanStrings.cameraOffTitle), findsOneWidget);
    expect(find.text(ScanStrings.cameraOffBody), findsOneWidget);
    expect(find.byKey(_cameraKey), findsNothing);
    expect(find.text(ScanStrings.allowCamera), findsOneWidget);
    await t.tap(find.text(ScanStrings.allowCamera));
    await t.pump();
    await t.pump();
    expect(find.text(ScanStrings.openSettings), findsOneWidget);
    await t.tap(find.text(ScanStrings.openSettings));
    await t.pump();
    expect(gate.settings, 1);
    await t.tap(find.text(ScanStrings.typeUsername));
    expect(pops, [const ScanTypeInstead()]);
  });

  testWidgets('camera off then allowed starts scanning', (t) async {
    final gate = FakeGate([CameraAccess.denied], requests: [CameraAccess.denied, CameraAccess.granted]);
    await _open(t, gate, []);
    await t.tap(find.text(ScanStrings.allowCamera));
    await t.pump();
    await t.pump();
    expect(find.byKey(_cameraKey), findsOneWidget);
    expect(find.text(ScanStrings.hint), findsOneWidget);
  });

  testFiveSizes('camera-off card has no overflow at 1.3 text', () => screenFor(FakeGate([CameraAccess.denied], requests: [CameraAccess.denied]), []), textScale: 1.3);
  testFiveSizes('scanning has no overflow', () => screenFor(FakeGate([CameraAccess.granted]), []));
}
