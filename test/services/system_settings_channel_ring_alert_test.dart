import 'package:bakhli/services/system_settings_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/ring_alert');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late int fallbacks;

  SystemSettingsChannel make() => SystemSettingsChannel(channel: channel, fallback: () async => fallbacks++);

  setUp(() {
    calls = [];
    fallbacks = 0;
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('hold and end send the method, tag, ms and unlock', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    final s = make();
    expect(await s.ringAlertHold('taxi_ring_o1', const Duration(seconds: 90)), isTrue);
    expect(await s.ringAlertEnd('taxi_ring_o1', unlock: true), isTrue);
    expect(await s.ringAlertEnd('taxi_ring_o1'), isTrue);
    expect(calls.map((c) => c.method), ['ringAlertHold', 'ringAlertEnd', 'ringAlertEnd']);
    expect(calls[0].arguments, {'tag': 'taxi_ring_o1', 'ms': 90000});
    expect(calls[1].arguments, {'tag': 'taxi_ring_o1', 'unlock': true});
    expect(calls[2].arguments, {'tag': 'taxi_ring_o1', 'unlock': false});
    expect(fallbacks, 0);
  });

  test('a false answer is false', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => false);
    expect(await make().ringAlertHold('t', Duration.zero), isFalse);
    expect(fallbacks, 0);
  });

  test('missing plugin gives false and never opens a settings page', () async {
    final s = make();
    expect(await s.ringAlertHold('t', const Duration(seconds: 1)), isFalse);
    expect(await s.ringAlertEnd('t', unlock: true), isFalse);
    expect(fallbacks, 0);
  });

  test('platform error gives false and never opens a settings page', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'x'));
    final s = make();
    expect(await s.ringAlertHold('t', const Duration(seconds: 1)), isFalse);
    expect(await s.ringAlertEnd('t'), isFalse);
    expect(fallbacks, 0);
  });
}
