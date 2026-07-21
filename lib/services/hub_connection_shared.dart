import 'package:signalr_netcore/iretry_policy.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Retry-delay schedule shared by every hub that must never permanently give up reconnecting
/// (signalr_netcore's own DefaultRetryPolicy appends a final null delay, meaning it eventually
/// stops retrying for good) — previously hand-copied identically into 3 separate private classes.
class HubReconnectPolicy implements IRetryPolicy {
  const HubReconnectPolicy();
  static const _delaysMs = [0, 2000, 5000, 10000, 15000, 30000];

  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) {
    final i = retryContext.previousRetryCount;
    return i < _delaysMs.length ? _delaysMs[i] : _delaysMs.last;
  }
}

/// Single-flight connect() guard shared by every session-lifetime hub (chat/wallet/inquiry) —
/// previously hand-copied identically into each. Concurrent connect() callers (e.g.
/// MainScreen.initState() racing a fast-tapped screen open) await the same in-flight attempt
/// instead of each independently building and starting a HubConnection.
mixin SingleFlightHubConnect {
  Future<void>? _connecting;

  HubConnection? get currentConnection;
  Future<void> performConnect();

  Future<void> connect() {
    if (currentConnection?.state == HubConnectionState.Connected) return Future.value();
    return _connecting ??= performConnect().whenComplete(() => _connecting = null);
  }

  /// disconnect() calls this instead of writing `_connecting = null` directly, since that field
  /// now lives in this mixin rather than in each hub's own file.
  void resetConnecting() => _connecting = null;
}
