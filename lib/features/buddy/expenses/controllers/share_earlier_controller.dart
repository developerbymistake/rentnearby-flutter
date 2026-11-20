import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../utils/trip_expense_engine.dart';
import '../../buddy_error_types.dart';
import '../../shared/buddy_json.dart';
import '../../shared/buddy_result.dart';
import '../../shared/models/person_models.dart';
import '../../shared/strings_shared.dart';
import '../data/expenses_api.dart';
import '../expense_deps.dart';
import '../expense_strings.dart';
import '../models/expense_models.dart';

enum ShareEnd { none, shared, needsAck, frozen }

class SharePreviewRow {
  const SharePreviewRow({required this.person, required this.before, required this.after});

  final MoneyPerson person;
  final int before;
  final int after;
}

class ShareEarlierController extends GetxController {
  ShareEarlierController({required this.tripId, required this.prompt, required this.travellers, this._api});

  final String tripId;
  final LatePrompt prompt;
  final List<MoneyPerson> travellers;
  final ExpensesApi? _api;
  final RxList<String> ticked = <String>[].obs;
  final Rx<String?> error = Rx<String?>(null);
  final RxBool busy = false.obs;
  final RxSet<String> removed = <String>{}.obs;
  String? _opId;

  ExpensesApi get api => _api ?? ExpenseDeps.api;

  List<String> get canonical => [for (final p in travellers) p.userId];

  List<LateCandidate> get items => [for (final i in prompt.items) if (!removed.contains(i.expenseId)) i];

  MoneyPerson? person(String id) {
    for (final p in travellers) {
      if (p.userId == id) return p;
    }
    return null;
  }

  String nameOf(String id) => person(id)?.name ?? BuddySharedStrings.someone;

  void toggle(String expenseId) {
    if (!ticked.remove(expenseId)) ticked.add(expenseId);
    _opId = null;
    error.value = null;
  }

  LateCandidate? get previewItem {
    if (ticked.isEmpty) return null;
    for (final i in items) {
      if (i.expenseId == ticked.last) return i;
    }
    return null;
  }

  ExpenseSplit? _split(LateCandidate c) {
    try {
      return TripExpenseEngine.shareWith(c.amount, canonical, [for (final s in c.shares) SplitShare(s.userId, s.share)], c.paidByUserId, prompt.userId);
    } on ArgumentError {
      return null;
    }
  }

  List<SharePreviewRow> previewOf(LateCandidate c) {
    final split = _split(c);
    if (split == null) return const [];
    int old(String id) => c.shares.where((s) => s.userId == id).fold(0, (a, s) => a + s.share);
    return [
      for (final s in split.shares)
        if (person(s.userId) != null) SharePreviewRow(person: person(s.userId)!, before: old(s.userId), after: s.share),
    ];
  }

  List<String> get noticeNames {
    final ids = <String>{};
    for (final id in ticked) {
      for (final c in items.where((i) => i.expenseId == id)) {
        for (final r in previewOf(c)) {
          if (!r.person.isMe && r.before != r.after) ids.add(r.person.userId);
        }
      }
    }
    return [for (final p in travellers) if (ids.contains(p.userId)) p.name];
  }

  Future<ShareEnd> submit({bool ack = false}) async {
    if (busy.value || ticked.isEmpty) return ShareEnd.none;
    busy.value = true;
    error.value = null;
    final opId = ack || _opId == null ? const Uuid().v4() : _opId!;
    _opId = opId;
    try {
      final body = ShareWithRequest(
        opId: opId,
        userId: prompt.userId,
        items: [
          for (final i in items)
            if (ticked.contains(i.expenseId)) ShareWithItem(expenseId: i.expenseId, baseVersion: i.version),
        ],
        paymentsAcknowledged: ack,
      );
      final r = await api.shareWith(tripId, body);
      if (isClosed) return ShareEnd.none;
      switch (r) {
        case BuddyOk<ShareWithResponse>():
          return ShareEnd.shared;
        case BuddyOffline<ShareWithResponse>():
          ExpenseDeps.offline();
        case BuddyFailed<ShareWithResponse>():
          error.value = BuddySharedStrings.somethingWrong;
        case BuddyRefused<ShareWithResponse>(:final type, :final message, :final data, :final rateLimited):
          if (rateLimited) {
            ExpenseDeps.toast(BuddySharedStrings.tooManyTries);
            return ShareEnd.none;
          }
          switch (type) {
            case BuddyErrorTypes.paymentsNotAcknowledged:
              return ShareEnd.needsAck;
            case BuddyErrorTypes.tripExpensesFrozen:
              return ShareEnd.frozen;
            case BuddyErrorTypes.expenseVersionConflict:
              final raw = data['conflicts'];
              final ids = <String>[
                ...BuddyJson.strings(raw),
                ...BuddyJson.list(raw, (m) => BuddyJson.str(m['expenseId'])).where((s) => s.isNotEmpty),
              ];
              ticked.removeWhere(ids.contains);
              removed.addAll(ids);
              _opId = null;
              error.value = ExpenseStrings.conflict;
            default:
              error.value = message ?? BuddySharedStrings.somethingWrong;
          }
      }
      return ShareEnd.none;
    } finally {
      if (!isClosed) busy.value = false;
    }
  }
}
