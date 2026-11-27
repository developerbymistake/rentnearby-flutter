import '../../buddy/shared/buddy_result.dart';
import 'data/social_me_api.dart';

/// Sends the traveller's current district (id only, never coordinates) for the nearby trips digest.
abstract final class SocialAreaSync {
  static const Duration resendAfter = Duration(hours: 6);

  static SocialMeApi api = const SocialMeApi();
  static DateTime Function() clock = DateTime.now;

  static String? _sentId;
  static DateTime? _sentAt;
  static String? _pending;
  static bool _running = false;

  static Future<void> sync(String? districtId) async {
    final id = districtId?.trim() ?? '';
    if (id.isEmpty) return;
    if (_running) {
      _pending = id;
      return;
    }
    final at = _sentAt;
    if (id == _sentId && at != null && clock().difference(at) < resendAfter) return;
    _running = true;
    try {
      final r = await api.updateArea(id);
      if (r is BuddyOk<void> || r is BuddyRefused<void>) {
        _sentId = id;
        _sentAt = clock();
      }
    } finally {
      _running = false;
    }
    final next = _pending;
    _pending = null;
    if (next != null && next != _sentId) await sync(next);
  }

  static void reset() {
    _sentId = null;
    _sentAt = null;
    _pending = null;
    _running = false;
    api = const SocialMeApi();
    clock = DateTime.now;
  }
}
