import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/services/push_token_registrar.dart';

class _Harness {
  final timers = <({Duration delay, void Function() run, bool cancelled})>[];
  final sent = <String>[];
  bool fail = true;
  bool loggedIn = true;
  bool driver = false;
  String? fetched = 'fresh';
  final gates = <String, Completer<void>>{};
  final net = StreamController<List<ConnectivityResult>>.broadcast();
  late final PushTokenRegistrar registrar;

  _Harness() {
    registrar = PushTokenRegistrar(
      send: (t) async {
        sent.add(t);
        final gate = gates.remove(t);
        if (gate != null) {
          await gate.future;
          return;
        }
        if (fail) throw Exception('offline');
      },
      isLoggedIn: () => loggedIn,
      isDriver: () => driver,
      fetchToken: () async => fetched,
      timer: (delay, run) {
        final i = timers.length;
        timers.add((delay: delay, run: run, cancelled: false));
        return () => timers[i] = (delay: delay, run: run, cancelled: true);
      },
      connectivity: () => net.stream,
    );
  }

  Iterable<({Duration delay, void Function() run, bool cancelled})> get live => timers.where((t) => !t.cancelled);

  Future<void> fireLast() async {
    final i = timers.lastIndexWhere((t) => !t.cancelled);
    final t = timers[i];
    timers[i] = (delay: t.delay, run: t.run, cancelled: true);
    t.run();
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failure_is_retried_with_backoff', () async {
    final h = _Harness();
    await h.registrar.register('t1');
    final delays = <Duration>[h.live.last.delay];
    for (var i = 0; i < 5; i++) {
      await h.fireLast();
      delays.add(h.live.last.delay);
    }
    expect(delays, const [
      Duration(seconds: 5),
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10),
      Duration(minutes: 30),
      Duration(minutes: 30),
    ]);
    expect(h.registrar.hasPending, isTrue);
    expect(h.registrar.lastFailure, isNotNull);
  });

  test('success_stops_retries', () async {
    final h = _Harness();
    await h.registrar.register('t1');
    h.fail = false;
    await h.fireLast();
    expect(h.registrar.hasPending, isFalse);
    expect(h.registrar.lastFailure, isNull);
    expect(h.live, isEmpty);
    expect(h.sent, ['t1', 't1']);
  });

  test('resume_retries_now', () async {
    final h = _Harness();
    await h.registrar.register('t1');
    h.fail = false;
    await h.registrar.onResume();
    expect(h.sent.length, 2);
    expect(h.registrar.hasPending, isFalse);
    expect(h.live, isEmpty);
  });

  test('logout_clears_the_pending_token', () async {
    final h = _Harness();
    await h.registrar.register('t1');
    h.loggedIn = false;
    h.registrar.clear();
    expect(h.registrar.hasPending, isFalse);
    expect(h.live, isEmpty);
    await h.registrar.onResume();
    expect(h.sent, ['t1']);
  });

  test('driver_registers_on_resume', () async {
    final h = _Harness()
      ..fail = false
      ..driver = true;
    await h.registrar.register('t1');
    await h.registrar.onResume();
    expect(h.sent, ['t1', 't1']);

    final seeker = _Harness()..fail = false;
    await seeker.registrar.register('t1');
    await seeker.registrar.onResume();
    expect(seeker.sent, ['t1']);
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  for (final ok in [true, false]) {
    test('new_token_during_send_is_sent_after_${ok ? 'success' : 'failure'}', () async {
      final h = _Harness()..fail = false;
      final g = Completer<void>();
      h.gates['t1'] = g;
      final first = h.registrar.register('t1');
      await flush();
      await h.registrar.register('t2');
      expect(h.sent, ['t1']);
      ok ? g.complete() : g.completeError(Exception('offline'));
      await first;
      expect(h.sent, ['t1', 't2']);
      expect(h.registrar.hasPending, isFalse);
      expect(h.live, isEmpty);
    });
  }

  test('new_token_during_send_is_retried_when_it_fails_too', () async {
    final h = _Harness();
    final g = Completer<void>();
    h.gates['t1'] = g;
    final first = h.registrar.register('t1');
    await flush();
    await h.registrar.register('t2');
    g.completeError(Exception('offline'));
    await first;
    expect(h.sent, ['t1', 't2']);
    expect(h.registrar.pendingToken, 't2');
    expect(h.live.single.delay, PushTokenRegistrar.backoff.first);
  });

  test('new_token_resets_backoff', () async {
    final h = _Harness();
    await h.registrar.register('t1');
    for (var i = 0; i < 4; i++) {
      await h.fireLast();
    }
    expect(h.live.last.delay, PushTokenRegistrar.steadyInterval);
    await h.registrar.register('t2');
    expect(h.live.single.delay, PushTokenRegistrar.backoff.first);
    expect(h.registrar.failureCount, 1);
  });

  for (final ok in [true, false]) {
    test('send_${ok ? 'success' : 'failure'}_after_clear_leaves_nothing', () async {
      final h = _Harness()..fail = false;
      final g = Completer<void>();
      h.gates['t1'] = g;
      final first = h.registrar.register('t1');
      await flush();
      h.loggedIn = false;
      h.registrar.clear();
      ok ? g.complete() : g.completeError(Exception('offline'));
      await first;
      expect(h.registrar.hasPending, isFalse);
      expect(h.live, isEmpty);
      expect(h.sent, ['t1']);
    });
  }

  test('network_return_retries_now', () async {
    final h = _Harness();
    h.registrar.start();
    addTearDown(h.registrar.dispose);
    await h.registrar.register('t1');
    h.net.add([ConnectivityResult.none]);
    await flush();
    expect(h.sent, ['t1']);
    h.fail = false;
    h.net.add([ConnectivityResult.wifi]);
    await flush();
    expect(h.sent, ['t1', 't1']);
    expect(h.registrar.hasPending, isFalse);
    expect(h.live, isEmpty);
  });

  test('network_change_without_pending_does_nothing', () async {
    final h = _Harness()..fail = false;
    h.registrar.start();
    addTearDown(h.registrar.dispose);
    await h.registrar.register('t1');
    h.net.add([ConnectivityResult.mobile]);
    await flush();
    expect(h.sent, ['t1']);
  });

  test('lifecycle_resume_retries_and_dispose_unhooks', () async {
    final binding = TestWidgetsFlutterBinding.instance;
    final h = _Harness();
    h.registrar.start();
    await h.registrar.register('t1');
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await flush();
    expect(h.sent, ['t1']);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flush();
    expect(h.sent, ['t1', 't1']);

    h.registrar.dispose();
    expect(h.live, isEmpty);
    expect(h.net.hasListener, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    h.fail = false;
    h.net.add([ConnectivityResult.wifi]);
    await flush();
    expect(h.sent, ['t1', 't1']);
  });
}
