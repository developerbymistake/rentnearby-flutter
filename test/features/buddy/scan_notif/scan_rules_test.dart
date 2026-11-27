import 'package:bakhli/features/buddy/scan/controllers/scan_controller.dart';
import 'package:bakhli/features/buddy/scan/scan_rules.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGate implements ScanPermissionGate {
  FakeGate(this.statuses, {this.requests = const []});
  List<CameraAccess> statuses;
  List<CameraAccess> requests;
  int requested = 0;
  int settings = 0;

  @override
  Future<CameraAccess> status() async => statuses.first;

  @override
  Future<CameraAccess> request() async => requests[requested++ % requests.length];

  @override
  Future<void> openSettings() async => settings++;
}

void main() {
  test('normalize trims and fixes the Bakhli# prefix case, other text is only trimmed', () {
    expect(ScanRules.normalize('  bakhli#12345678 '), 'Bakhli#12345678');
    expect(ScanRules.normalize('BAKHLI#12345678'), 'Bakhli#12345678');
    expect(ScanRules.isBakhliUsername(ScanRules.normalize('Bakhli#1234567')), isFalse);
    expect(ScanRules.normalize(' hello '), 'hello');
  });

  group('ScanRules', () {
    test('accepts exactly Bakhli# and 8 ASCII digits', () {
      expect(ScanRules.isBakhliUsername('Bakhli#12345678'), isTrue);
    });

    const bad = <String>[
      'Bakhli#12345678\n',
      ' Bakhli#12345678',
      'Bakhli#12345678 ',
      'bakhli#12345678',
      'Bakhli#123456789',
      'Bakhli#1234567',
      'https://x.com/Bakhli#12345678',
      'Bakhli#１２３４５６７８',
      'Bakhli#1234567a',
      'upi://pay?pa=a@b',
      '',
    ];
    for (var i = 0; i < bad.length; i++) {
      test('rejects bad sample $i', () => expect(ScanRules.isBakhliUsername(bad[i]), isFalse));
    }

    test('null is not a Bakhli QR', () => expect(ScanRules.classify(null, 'Bakhli#12345678'), ScanVerdict.notBakhli));
    test('own username', () => expect(ScanRules.classify('Bakhli#12345678', 'Bakhli#12345678'), ScanVerdict.own));
    test('other username', () => expect(ScanRules.classify('Bakhli#87654321', 'Bakhli#12345678'), ScanVerdict.other));
    test('regex runs before own check', () => expect(ScanRules.classify('x', 'x'), ScanVerdict.notBakhli));

    test('debounce window of 2 seconds', () {
      var now = DateTime(2026, 1, 1);
      final d = ScanDebounce(clock: () => now);
      expect(d.open, isTrue);
      d.mark();
      expect(d.open, isFalse);
      now = now.add(const Duration(milliseconds: 1999));
      expect(d.open, isFalse);
      now = now.add(const Duration(milliseconds: 1));
      expect(d.open, isTrue);
    });
  });

  group('ScanController', () {
    ScanController make(FakeGate gate, {List<String>? found, DateTime Function()? clock, List<int>? haptics}) => ScanController(
          ownUsername: () => 'Bakhli#11111111',
          onFound: (u) => found?.add(u),
          permission: gate,
          clock: clock,
          haptic: () async => haptics?.add(1),
        );

    test('granted starts scanning without asking', () async {
      final gate = FakeGate([CameraAccess.granted]);
      final c = make(gate);
      await c.start();
      expect(c.state.value, ScanState.scanning);
      expect(gate.requested, 0);
    });

    test('camera that cannot start shows camera off', () async {
      final c = make(FakeGate([CameraAccess.granted]));
      await c.start();
      c.cameraFailed();
      expect(c.state.value, ScanState.cameraOff);
    });

    test('first open asks; refused shows camera off', () async {
      final gate = FakeGate([CameraAccess.denied], requests: [CameraAccess.denied]);
      final c = make(gate);
      await c.start();
      expect(gate.requested, 1);
      expect(c.state.value, ScanState.cameraOff);
      expect(c.settingsNeeded.value, isFalse);
    });

    test('allow asks again, second refusal becomes Open settings', () async {
      final gate = FakeGate([CameraAccess.denied], requests: [CameraAccess.denied, CameraAccess.permanentlyDenied]);
      final c = make(gate);
      await c.start();
      await c.allow();
      expect(c.settingsNeeded.value, isTrue);
      await c.allow();
      expect(gate.settings, 1);
      expect(c.state.value, ScanState.cameraOff);
    });

    test('allow granted moves to scanning', () async {
      final gate = FakeGate([CameraAccess.denied], requests: [CameraAccess.denied, CameraAccess.granted]);
      final c = make(gate);
      await c.start();
      await c.allow();
      expect(c.state.value, ScanState.scanning);
    });

    test('recheck on resume starts the camera when allowed in settings', () async {
      final gate = FakeGate([CameraAccess.permanentlyDenied], requests: [CameraAccess.permanentlyDenied]);
      final c = make(gate);
      await c.start();
      gate.statuses = [CameraAccess.granted];
      await c.recheck();
      expect(c.state.value, ScanState.scanning);
    });

    test('good read: haptic, one callback, further reads ignored for 2 s', () async {
      var now = DateTime(2026, 1, 1);
      final found = <String>[];
      final haptics = <int>[];
      final c = make(FakeGate([CameraAccess.granted]), found: found, clock: () => now, haptics: haptics);
      await c.start();
      c.onRead('Bakhli#22222222');
      c.onRead('Bakhli#33333333');
      expect(found, ['Bakhli#22222222']);
      expect(haptics.length, 1);
      now = now.add(const Duration(seconds: 3));
      c.onRead('Bakhli#33333333');
      expect(found.length, 2);
    });

    test('other QR shows not-Bakhli, scan again resumes, nothing is kept', () async {
      var now = DateTime(2026, 1, 1);
      final found = <String>[];
      final c = make(FakeGate([CameraAccess.granted]), found: found, clock: () => now);
      await c.start();
      c.onRead('https://evil.example');
      expect(c.state.value, ScanState.notBakhli);
      c.scanAgain();
      expect(c.state.value, ScanState.scanning);
      now = now.add(const Duration(seconds: 3));
      c.onRead('Bakhli#11111111');
      expect(c.state.value, ScanState.ownQr);
      expect(found, isEmpty);
    });

    test('reads are ignored before permission and when camera is off', () async {
      final found = <String>[];
      final c = make(FakeGate([CameraAccess.denied], requests: [CameraAccess.denied]), found: found);
      c.onRead('Bakhli#22222222');
      await c.start();
      c.onRead('Bakhli#22222222');
      expect(found, isEmpty);
    });
  });
}
