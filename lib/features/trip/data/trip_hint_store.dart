import '../../../services/storage_service.dart';

class TripHintStore {
  static const String _prefix = 'trip_hint_dismissed_';
  static final _session = <String>{};

  static bool isDismissed(String tripId) =>
      _session.contains(tripId) || (tripId.isNotEmpty && StorageService.getTourSeen('$_prefix$tripId'));

  static void dismiss(String tripId) {
    _session.add(tripId);
    if (tripId.isNotEmpty) StorageService.saveTourSeen('$_prefix$tripId');
  }
}
