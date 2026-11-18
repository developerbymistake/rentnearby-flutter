import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

typedef PushTokenSender = Future<void> Function(String token);
typedef PushTokenFetcher = Future<String?> Function();
typedef PushTimerFactory = void Function() Function(Duration delay, void Function() run);

void Function() _realTimer(Duration delay, void Function() run) => Timer(delay, run).cancel;

class PushTokenRegistrar with WidgetsBindingObserver {
  PushTokenRegistrar({
    required this.send,
    required this.isLoggedIn,
    required this.isDriver,
    this.fetchToken,
    this.onRegistered,
    PushTimerFactory? timer,
    Stream<List<ConnectivityResult>> Function()? connectivity,
  })  : _timer = timer ?? _realTimer,
        _connectivity = connectivity ?? (() => Connectivity().onConnectivityChanged);

  static const List<Duration> backoff = [
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];
  static const Duration steadyInterval = Duration(minutes: 30);

  final PushTokenSender send;
  final bool Function() isLoggedIn;
  final bool Function() isDriver;
  final PushTokenFetcher? fetchToken;
  final Future<void> Function(String token)? onRegistered;
  final PushTimerFactory _timer;
  final Stream<List<ConnectivityResult>> Function() _connectivity;

  String? _pending;
  String? _registered;
  int _failures = 0;
  bool _inFlight = false;
  bool _started = false;
  void Function()? _cancelTimer;
  StreamSubscription<List<ConnectivityResult>>? _netSub;

  Object? lastFailure;

  String? get pendingToken => _pending;
  bool get hasPending => _pending != null;
  int get failureCount => _failures;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _netSub = _connectivity().listen(_onNetwork);
  }

  void dispose() {
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
    _netSub?.cancel();
    _netSub = null;
    _cancelPending();
  }

  Future<void> register(String token) async {
    if (!isLoggedIn()) return;
    if (token != _pending) _failures = 0;
    _pending = token;
    _cancelPending();
    await _attempt();
  }

  void clear() {
    _pending = null;
    _registered = null;
    _failures = 0;
    lastFailure = null;
    _cancelPending();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(onResume());
  }

  Future<void> onResume() async {
    if (!isLoggedIn()) return;
    if (_pending != null) {
      _cancelPending();
      await _attempt();
      return;
    }
    if (isDriver()) await _reregister();
  }

  void _onNetwork(List<ConnectivityResult> results) {
    if (_pending == null || !isLoggedIn()) return;
    if (results.every((r) => r == ConnectivityResult.none)) return;
    _cancelPending();
    unawaited(_attempt());
  }

  Future<void> _reregister() async {
    final token = _registered ?? await _safeFetch();
    if (token == null) return;
    _pending = token;
    await _attempt();
  }

  Future<String?> _safeFetch() async {
    try {
      return await fetchToken?.call();
    } catch (e) {
      lastFailure = e;
      return null;
    }
  }

  Future<void> _attempt() async {
    final token = _pending;
    if (token == null || _inFlight) return;
    _inFlight = true;
    try {
      await send(token);
      if (_pending == token) {
        _pending = null;
        _registered = token;
        _failures = 0;
        lastFailure = null;
        _cancelPending();
        await onRegistered?.call(token);
      }
    } catch (e) {
      lastFailure = e;
      if (_pending == token && isLoggedIn()) {
        final delay = _failures < backoff.length ? backoff[_failures] : steadyInterval;
        _failures++;
        _cancelPending();
        _cancelTimer = _timer(delay, () {
          _cancelTimer = null;
          unawaited(_attempt());
        });
      }
    } finally {
      _inFlight = false;
    }
    final next = _pending;
    if (next != null && next != token && isLoggedIn()) await _attempt();
  }

  void _cancelPending() {
    _cancelTimer?.call();
    _cancelTimer = null;
  }
}
