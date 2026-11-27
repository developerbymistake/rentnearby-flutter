import '../../../services/storage_service.dart';
import '../../owner_core/data/owner_api.dart';
import '../../owner_core/data/owner_result.dart';

class StayRingSettings {
  const StayRingSettings({this.ringOn = true, this.stayLive = false, this.hasValidToken = false, this.canRing = false});

  final bool ringOn;
  final bool stayLive;
  final bool hasValidToken;
  final bool canRing;

  static bool _flag(Object? v, bool fallback) => v is bool ? v : fallback;

  factory StayRingSettings.fromJson(Map<String, dynamic> j) => StayRingSettings(
        ringOn: _flag(j['ringOn'], true),
        stayLive: _flag(j['stayLive'], false),
        hasValidToken: _flag(j['hasValidToken'], false),
        canRing: _flag(j['canRing'], false),
      );
}

/// Server side of the stay enquiry ring. None of these calls reads or changes an enquiry.
abstract final class StayRingApi {
  static const String base = '/stays/me/enquiry-ring';
  static const String accepted = 'Accepted';

  static String answerPath(String enquiryId) => '$base/$enquiryId/answer';

  // No retry: a failed read shows the error line, it never waits on timers.
  static Future<OwnerResult<StayRingSettings>> load() =>
      OwnerApi.run(() async => StayRingSettings.fromJson(OwnerApi.dataOf(await OwnerApi.transport.get(base, null))));

  static Future<OwnerResult<StayRingSettings>> save(bool ringOn) => OwnerApi.put<StayRingSettings>(base, {'ringOn': ringOn}, StayRingSettings.fromJson);

  static Future<OwnerResult<void>> testRing() => OwnerApi.post<void>('$base/test', const {}, (_) {});

  /// Accept on the ring: the server stops the ring on the owner's other phones and drops the missed ring.
  static Future<OwnerResult<void>> sendAccepted(String enquiryId) {
    String? token;
    try {
      token = StorageService.getFcmToken();
    } catch (_) {}
    return OwnerApi.post<void>(answerPath(enquiryId), {'outcome': accepted, 'deviceToken': ?token}, (_) {});
  }
}
