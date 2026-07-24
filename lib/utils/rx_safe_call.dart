import 'app_toast.dart';

/// GetX's Rx stream dispatch (get_rx/rx_stream/mini_stream.dart, FastList._notifyData)
/// has no exception isolation between listeners on the same stream — an uncaught
/// throw from one ever()/listen() callback silently skips every listener
/// registered after it, for that notification. Wrap any callback registered on a
/// stream this app doesn't fully own (tabIndex, user, etc.) with this so it can
/// never take down sibling listeners.
void Function(T) rxSafe<T>(String debugLabel, void Function(T) callback) {
  return (value) {
    try {
      callback(value);
    } catch (e) {
      AppToast.error('[$debugLabel] worker threw: $e');
    }
  };
}
