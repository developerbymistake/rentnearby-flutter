import 'package:get/get.dart';

import '../../../../utils/app_toast.dart';
import '../../buddy_error_types.dart';
import '../../buddy_live.dart';
import '../../shared/buddy_result.dart';
import '../../shared/models/person_models.dart';
import '../buddies_strings.dart';
import '../buddy_feedback.dart';
import '../data/buddies_api.dart';
import '../models/buddy_models.dart';
import 'buddy_summary_controller.dart';
import 'buddies_controller.dart';

class BuddyRequestsController extends GetxController {
  BuddyRequestsController({this.api = const BuddiesApi()});

  final BuddiesApi api;
  final state = BuddyListState.loading.obs;
  final received = <ReceivedRequest>[].obs;
  final sent = <SentRequest>[].obs;
  final busy = <String>{}.obs;
  final loadingMore = false.obs;
  String? _receivedCursor;
  String? _sentCursor;
  Worker? _live;
  int _gen = 0;
  BuddyNoteSink? onNote;
  void Function(BuddyPerson person)? onAccepted;

  bool get isEmpty => received.isEmpty && sent.isEmpty;

  @override
  void onInit() {
    super.onInit();
    _live = ever<int>(BuddyLive.buddies, (_) => load());
    load();
  }

  Future<void> load() async {
    final gen = ++_gen;
    if (isEmpty) state.value = BuddyListState.loading;
    final (r, s) = await (api.received(), api.sent()).wait;
    if (gen != _gen) return;
    if (r is BuddyOk<BuddyCursorPage<ReceivedRequest>> && s is BuddyOk<BuddyCursorPage<SentRequest>>) {
      received.assignAll(r.value.items);
      sent.assignAll(s.value.items);
      _receivedCursor = r.value.nextCursor;
      _sentCursor = s.value.nextCursor;
      state.value = BuddyListState.ready;
    } else if (isEmpty) {
      state.value = BuddyListState.failed;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value) return;
    final rc = _receivedCursor;
    final sc = _sentCursor;
    if (rc == null && sc == null) return;
    loadingMore.value = true;
    final gen = _gen;
    if (rc != null) {
      final r = await api.received(cursor: rc);
      if (gen == _gen && r is BuddyOk<BuddyCursorPage<ReceivedRequest>>) {
        final known = received.map((e) => e.requestId).toSet();
        received.addAll(r.value.items.where((e) => !known.contains(e.requestId)));
        _receivedCursor = r.value.nextCursor;
      }
    }
    if (sc != null) {
      final s = await api.sent(cursor: sc);
      if (gen == _gen && s is BuddyOk<BuddyCursorPage<SentRequest>>) {
        final known = sent.map((e) => e.requestId).toSet();
        sent.addAll(s.value.items.where((e) => !known.contains(e.requestId)));
        _sentCursor = s.value.nextCursor;
      }
    }
    loadingMore.value = false;
  }

  void _dropReceived(String requestId) => received.removeWhere((e) => e.requestId == requestId);

  Future<void> accept(ReceivedRequest req) async {
    if (!busy.add(req.requestId)) return;
    busy.refresh();
    final r = await api.accept(req.requestId);
    busy.remove(req.requestId);
    switch (r) {
      case BuddyOk():
        _dropReceived(req.requestId);
        BuddySummaryController.maybe?.load();
        onAccepted?.call(req.person);
      case BuddyRefused(:final type):
        final line = BuddyFeedback.acceptLine(type);
        if (line != null) {
          onNote?.call(line, danger: true);
        } else if (type == BuddyErrorTypes.requestEnded) {
          _dropReceived(req.requestId);
          BuddySummaryController.maybe?.load();
          AppToast.info(BuddiesStrings.requestGone);
        } else {
          BuddyFeedback.writeFailed(r);
        }
      case BuddyOffline() || BuddyFailed():
        BuddyFeedback.writeFailed(r);
    }
  }

  Future<void> decline(ReceivedRequest req) async {
    if (!busy.add(req.requestId)) return;
    busy.refresh();
    final r = await api.decline(req.requestId);
    busy.remove(req.requestId);
    if (r is BuddyOk || (r is BuddyRefused<void> && r.type == BuddyErrorTypes.requestEnded)) {
      _dropReceived(req.requestId);
      BuddySummaryController.maybe?.load();
    } else {
      BuddyFeedback.writeFailed(r);
    }
  }

  Future<void> cancel(SentRequest req) async {
    if (!busy.add(req.requestId)) return;
    busy.refresh();
    final r = await api.cancel(req.requestId);
    busy.remove(req.requestId);
    if (r is BuddyOk || (r is BuddyRefused<void> && r.type == BuddyErrorTypes.requestEnded)) {
      sent.removeWhere((e) => e.requestId == req.requestId);
      BuddySummaryController.maybe?.load();
    } else if (r is BuddyRefused<void> && r.type == BuddyErrorTypes.alreadyBuddies) {
      sent.removeWhere((e) => e.requestId == req.requestId);
      BuddyLive.buddies.value++;
    } else {
      BuddyFeedback.writeFailed(r);
    }
  }

  void personBlocked(String userId) {
    received.removeWhere((e) => e.person.userId == userId);
    sent.removeWhere((e) => e.person.userId == userId);
  }

  @override
  void onClose() {
    _live?.dispose();
    super.onClose();
  }
}
