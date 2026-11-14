import 'dart:async';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../utils/app_toast.dart';
import '../../taxi/ways/models/ask_models.dart';
import '../../../utils/dio_error_mapper.dart';
import '../data/trip_shortlist_repository.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_shortlist_model.dart';
import '../trip_strings.dart';
import '../trip_strings_shortlist.dart';
import '../data/trip_enquiry_repository.dart';
import '../trip_strings_v2_find.dart';
import 'trip_enquiry_controller.dart';
import 'trip_plan_controller.dart';

class TripShortlistController extends GetxController {
  TripShortlistController({
    TripShortlistRepository? repo,
    Future<String?> Function()? tripId,
    bool Function()? offline,
    void Function(String message)? warn,
    String Function()? newId,
  })  : _repo = repo ?? const TripShortlistRepository(),
        _tripIdOf = tripId ?? _planTripId,
        _offline = offline ?? _planOffline,
        _warn = warn ?? AppToast.warning,
        _newId = newId ?? (() => const Uuid().v4());

  static TripShortlistController get to => Get.isRegistered<TripShortlistController>()
      ? Get.find<TripShortlistController>()
      : Get.put(TripShortlistController(), permanent: true);

  final TripShortlistRepository _repo;
  final Future<String?> Function() _tripIdOf;
  final bool Function() _offline;
  final void Function(String) _warn;
  final String Function() _newId;

  final items = <ShortlistItem>[].obs;
  final busy = <String>{}.obs;
  final sending = <String>{}.obs;
  final notes = <String, String>{}.obs;
  final reasons = <String, String>{}.obs;
  final doneHint = <String>{}.obs;
  int max = 3;

  String? _loadedTrip;
  final _requests = <String, String>{};

  static Future<String?> _planTripId() async {
    final plan = TripPlanController.to;
    final ok = await plan.flushPendingSave();
    final id = plan.trip.value?.id;
    if (!ok || id == null) {
      plan.toastNotSaved();
      return null;
    }
    return id;
  }

  static bool _planOffline() => Get.isRegistered<TripPlanController>() && TripPlanController.to.netOff;

  static String _busyKey(String step, String id) => '$step|$id';

  List<ShortlistItem> activeOf(String step) => [
        for (final i in items)
          if (i.stepKey == step && i.isActive) i,
      ];

  int countOf(String step) => activeOf(step).length;

  bool has(String step, String listingId) => activeOf(step).any((i) => i.listingId == listingId);

  bool isBusy(String step, String listingId) => busy.contains(_busyKey(step, listingId));

  bool isSending(String step) => sending.contains(step);

  bool beginSend(String step) {
    if (sending.contains(step)) return false;
    sending.add(step);
    return true;
  }

  void endSend(String step) => sending.remove(step);

  String? noteOf(String step) => notes[step];

  String? reasonOf(String step, String listingId) => reasons[_busyKey(step, listingId)];

  Future<bool> remove(String step, String listingId) async {
    if (isBusy(step, listingId)) return false;
    final key = _busyKey(step, listingId);
    busy.add(key);
    final before = List<ShortlistItem>.of(items);
    items.removeWhere((i) => i.stepKey == step && i.listingId == listingId && i.isActive);
    reasons.remove(key);
    try {
      final tripId = await _tripIdOf();
      if (tripId == null) {
        items.assignAll(before);
        return false;
      }
      await _repo.remove(tripId, step, listingId);
      return true;
    } catch (e) {
      items.assignAll(before);
      _failToast(e);
      return false;
    } finally {
      busy.remove(key);
    }
  }

  Set<String> noReplyIds(String step) => {
        for (final i in items)
          if (i.stepKey == step && i.isNoReply) i.listingId,
      };

  Map<String, String> namesOf(String step) => {
        for (final i in items)
          if (i.stepKey == step) i.listingId: i.name,
      };

  void clear() {
    items.clear();
    _loadedTrip = null;
    _requests.clear();
    sending.clear();
    notes.clear();
    reasons.clear();
    doneHint.clear();
  }

  void _adopt(String tripId) {
    if (_loadedTrip != null && _loadedTrip != tripId) {
      items.clear();
      _requests.clear();
    }
    _loadedTrip = tripId;
  }

  Future<bool> load({bool force = false}) async {
    try {
      final tripId = await _tripIdOf();
      if (tripId == null) return false;
      if (!force && _loadedTrip == tripId && items.isNotEmpty) return true;
      final res = await _repo.list(tripId);
      _adopt(tripId);
      max = res.max;
      items.assignAll(res.items);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _failToast(Object e) {
    if (DioErrorMapper.errorType(e) == TripShortlistErrorTypes.full) {
      _warn(TripStringsShortlist.full);
    } else if (DioErrorMapper.isNetworkError(e)) {
      _warn(TripStrings.noNetwork);
    } else {
      _warn(DioErrorMapper.toMessage(e, TripStrings.couldNotLoad, showRawMessageForStatusCodes: {400, 403, 409, 422}));
    }
  }

  Future<bool> toggle({
    required String step,
    required String kind,
    required String listingId,
    required String name,
    String? journeyId,
    int? legIndex,
  }) async {
    if (isBusy(step, listingId)) return false;
    final on = has(step, listingId);
    if (!on && countOf(step) >= max) {
      _warn(TripStringsShortlist.full);
      return false;
    }
    if (_offline()) {
      _warn(TripStringsV2Find.offlineAsk);
      return false;
    }
    final key = _busyKey(step, listingId);
    busy.add(key);
    final before = List<ShortlistItem>.of(items);
    final item = ShortlistItem(
      stepKey: step,
      kind: kind,
      listingId: listingId,
      name: name,
      journeyId: journeyId,
      legIndex: legIndex,
      addedAt: DateTime.now().toUtc(),
    );
    if (on) {
      items.removeWhere((i) => i.stepKey == step && i.listingId == listingId && i.isActive);
    } else {
      items.removeWhere((i) => i.stepKey == step && i.listingId == listingId);
      items.add(item);
    }
    try {
      final tripId = await _tripIdOf();
      if (tripId == null) {
        items.assignAll(before);
        return false;
      }
      _adopt(tripId);
      if (on) {
        await _repo.remove(tripId, step, listingId);
      } else {
        final server = await _repo.add(tripId, step, listingId, item);
        final ids = {for (final s in server) s.listingId};
        items.removeWhere((i) => i.stepKey == step && (i.isActive || ids.contains(i.listingId)));
        items.addAll(server);
      }
      return true;
    } catch (e) {
      items.assignAll(before);
      if (DioErrorMapper.errorType(e) == TripShortlistErrorTypes.full) unawaited(load(force: true));
      _failToast(e);
      return false;
    } finally {
      busy.remove(key);
    }
  }

  Future<bool> closeStep(String step, {required String reason}) async {
    final before = List<ShortlistItem>.of(items);
    items.removeWhere((i) => i.stepKey == step && i.isActive);
    try {
      final tripId = await _tripIdOf();
      if (tripId == null) {
        items.assignAll(before);
        return false;
      }
      await _repo.close(tripId, step, reason: reason);
      return true;
    } catch (e) {
      items.assignAll(before);
      _failToast(e);
      return false;
    }
  }

  Future<MarkBookedResult?> markBooked(String step, {String? listingId}) async {
    try {
      final tripId = await _tripIdOf();
      if (tripId == null) return null;
      final res = await _repo.markBooked(tripId, step, listingId: listingId);
      items.removeWhere((i) => i.stepKey == step && (i.isActive || i.isNoReply));
      return res;
    } catch (e) {
      _failToast(e);
      return null;
    }
  }

  String _signature(String step, List<String> ids) => '$step|${(List.of(ids)..sort()).join(',')}';

  String requestIdFor(String step, List<String> ids) => _requests.putIfAbsent(_signature(step, ids), _newId);

  void completeRequest(String step, List<String> ids) => _requests.remove(_signature(step, ids));

  void applyResults(String step, Iterable<TripSendResult> results) {
    final done = <String>{};
    for (final r in results) {
      final key = _busyKey(step, r.listingId);
      if (r.ok) {
        done.add(r.listingId);
        reasons.remove(key);
      } else if (r.gone) {
        done.add(r.listingId);
        reasons.remove(key);
      } else {
        reasons[key] = r.status;
      }
    }
    if (done.isEmpty) return;
    items.removeWhere((i) => i.stepKey == step && i.isActive && done.contains(i.listingId));
  }

  static String? limitText(String? type, {int? minutes}) {
    if (type == TripEnquiryErrorTypes.enquiryLimit) {
      return '${TripStrings.askLimitTitle}. ${TripStrings.askLimitBody(minutes ?? 1)}';
    }
    if (type == TripEnquiryErrorTypes.leadLimit) return TripStringsShortlist.leadLimit;
    return null;
  }

  void _noteFailure(String step) {
    final e = TripEnquiryController.to;
    final text = limitText(e.lastErrorType, minutes: e.lastRetryAfterMinutes);
    if (text == null) return;
    notes[step] = text;
    _warn(text);
  }

  List<String> sendIds(String step) => [for (final i in activeOf(step).take(max)) i.listingId];

  Future<TripEnquiryBatch?> sendStays({required String step, required int day, required int nights}) async {
    final ids = sendIds(step);
    if (ids.isEmpty) return null;
    if (_offline()) {
      _warn(TripStringsV2Find.offlineAsk);
      return null;
    }
    final batch = await TripEnquiryController.to.sendEnquiry(
      day: day,
      stayIds: ids,
      nights: nights,
      clientRequestId: requestIdFor(step, ids),
      stepKey: step,
    );
    if (batch != null) {
      _settle(step, ids, batch);
    } else {
      _noteFailure(step);
    }
    return batch;
  }

  Future<TripEnquiryBatch?> sendTaxis({required String step, required List<int> days}) async {
    final ids = sendIds(step);
    if (ids.isEmpty) return null;
    if (_offline()) {
      _warn(TripStringsV2Find.offlineAsk);
      return null;
    }
    final batch = await TripEnquiryController.to.sendLead(
      days: days,
      taxiIds: ids,
      clientRequestId: requestIdFor(step, ids),
      stepKey: step,
    );
    if (batch != null) {
      _settle(step, ids, batch);
    } else {
      _noteFailure(step);
    }
    return batch;
  }

  Future<TripEnquiryBatch?> sendCars({
    required String step,
    required Future<AskResult?> Function(List<String> ids, String requestId) ask,
  }) async {
    final ids = sendIds(step);
    if (ids.isEmpty) return null;
    if (_offline()) {
      _warn(TripStringsV2Find.offlineAsk);
      return null;
    }
    final res = await ask(ids, requestIdFor(step, ids));
    if (res == null) return null;
    final batch = carBatch(res, ids);
    _settle(step, ids, batch);
    return batch;
  }

  static TripEnquiryBatch carBatch(AskResult res, List<String> ids) {
    final results = res.results.isNotEmpty
        ? [...res.results]
        : [
            for (final i in res.items) TripSendResult(listingId: i.taxiId, status: 'Sent', enquiryId: i.enquiryId),
            for (final k in res.skipped) TripSendResult(listingId: k.taxiId, status: _skipStatus(k.reason), reason: k.reason),
          ];
    final seen = {for (final r in results) r.listingId};
    for (final id in ids) {
      if (!seen.contains(id)) results.add(TripSendResult(listingId: id, status: 'NotAvailable'));
    }
    return TripEnquiryBatch(items: const [], skipped: const [], veryShortNotice: res.veryShortNotice, results: results);
  }

  static String _skipStatus(String reason) => switch (reason) {
        TripSkipReasons.alreadyOpen => 'AlreadyOpen',
        TripSkipReasons.openInAnotherTrip => 'OpenInAnotherTrip',
        TripSkipReasons.notAvailable => 'NotAvailable',
        TripSkipReasons.blocked => 'Blocked',
        TripSkipReasons.limitReached => 'LimitReached',
        _ => 'Failed',
      };

  void _settle(String step, List<String> ids, TripEnquiryBatch batch) {
    completeRequest(step, ids);
    notes.remove(step);
    applyResults(step, batch.perRecipient);
    unawaited(load(force: true));
  }
}
