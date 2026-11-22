import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../utils/app_toast.dart';
import '../../buddy_error_types.dart';
import '../../buddy_limits.dart';
import '../../shared/buddy_result.dart';
import '../../shared/strings_shared.dart';
import '../buddies_strings.dart';
import '../buddy_feedback.dart';
import '../data/buddies_api.dart';
import '../models/buddy_models.dart';
import 'buddy_summary_controller.dart';

enum FindState { idle, searching, found, notFound, failed, limited, self }

abstract final class BuddyUsername {
  static final RegExp pattern = RegExp(r'^Bakhli#[0-9]{8}$');
  static final RegExp _prefix = RegExp(r'^bakhli#', caseSensitive: false);

  static String normalize(String raw) {
    final t = raw.trim();
    return _prefix.hasMatch(t) ? '${BuddyLimits.usernamePrefix}${t.substring(BuddyLimits.usernamePrefix.length)}' : t;
  }

  static bool isValid(String text) => pattern.hasMatch(text);
}

class BuddyFindController extends GetxController {
  BuddyFindController({this.api = const BuddiesApi(), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static DateTime? _restUntil;

  final BuddiesApi api;
  final DateTime Function() _clock;
  final text = TextEditingController();
  final focus = FocusNode();
  final state = FindState.idle.obs;
  final person = Rx<FoundPerson?>(null);
  final sentHere = false.obs;
  final busy = false.obs;
  String _source = BuddySource.search;
  String? _query;
  String? _clientRequestId;
  String? _requestFor;
  Timer? _restTimer;
  BuddyNoteSink? onNote;

  String get source => _source;

  static void debugResetRest() => _restUntil = null;

  @override
  void onInit() {
    super.onInit();
    _resumeRest();
  }

  void _resumeRest() {
    final until = _restUntil;
    if (until == null) return;
    final left = until.difference(_clock());
    if (left <= Duration.zero) {
      _restUntil = null;
      return;
    }
    _enterRest(left);
  }

  void _enterRest(Duration left) {
    state.value = FindState.limited;
    person.value = null;
    text.clear();
    _restTimer?.cancel();
    _restTimer = Timer(left, () {
      _restUntil = null;
      if (state.value == FindState.limited) state.value = FindState.idle;
    });
  }

  bool get boxEnabled => state.value != FindState.limited;

  Future<void> search({String? raw, String source = BuddySource.search}) async {
    if (state.value == FindState.limited || state.value == FindState.searching) return;
    final q = BuddyUsername.normalize(raw ?? text.text);
    if (q.isEmpty) return;
    if (q.length > 40) return;
    if (text.text != q) text.text = q;
    _source = source;
    _query = q;
    sentHere.value = false;
    if (!BuddyUsername.isValid(q)) {
      person.value = null;
      state.value = FindState.notFound;
      return;
    }
    state.value = FindState.searching;
    final r = await api.find(q, source: source);
    switch (r) {
      case BuddyOk(:final value):
        final p = value.person;
        if (!value.found || p == null) {
          person.value = null;
          state.value = FindState.notFound;
        } else if (p.relation == BuddyRelation.self) {
          person.value = null;
          state.value = FindState.self;
        } else {
          if (_requestFor != p.userId) _clientRequestId = null;
          person.value = p;
          state.value = FindState.found;
        }
      case BuddyRefused(:final statusCode, :final retryAfterSeconds):
        if (statusCode == 429) {
          final left = Duration(seconds: retryAfterSeconds ?? 60);
          _restUntil = _clock().add(left);
          _enterRest(left);
        } else {
          person.value = null;
          state.value = FindState.notFound;
        }
      case BuddyOffline() || BuddyFailed():
        person.value = null;
        state.value = FindState.failed;
    }
  }

  Future<void> retry() => search(raw: _query ?? text.text, source: _source);

  Future<void> searchScanned(String username) => search(raw: username, source: BuddySource.qr);

  void _setRelation(BuddyRelation relation, {String? requestId}) {
    final p = person.value;
    if (p == null) return;
    person.value = FoundPerson(
      userId: p.userId,
      name: p.name,
      username: p.username,
      initial: p.initial,
      photoUrl: p.photoUrl,
      relation: relation,
      requestId: requestId,
      expiresAt: relation == BuddyRelation.requestedByMe ? p.expiresAt : null,
    );
  }

  void _note(String text, {bool danger = false}) => onNote?.call(text, danger: danger);

  Future<void> add() async {
    final p = person.value;
    if (p == null || busy.value) return;
    if (_requestFor != p.userId || _clientRequestId == null) {
      _clientRequestId = const Uuid().v4();
      _requestFor = p.userId;
    }
    busy.value = true;
    final r = await api.sendRequest(p.userId, source: _source, clientRequestId: _clientRequestId!);
    busy.value = false;
    switch (r) {
      case BuddyOk(:final value):
        _clientRequestId = null;
        if (value.accepted) {
          _setRelation(BuddyRelation.buddy);
          sentHere.value = false;
          _note(BuddiesStrings.nowYourBuddy(p.name));
        } else {
          _setRelation(BuddyRelation.requestedByMe, requestId: value.requestId);
          sentHere.value = true;
          _note(BuddiesStrings.requestSentTo(p.name));
        }
        BuddySummaryController.maybe?.load();
      case BuddyRefused(:final statusCode, :final type):
        _clientRequestId = null;
        if (statusCode == 429) {
          _note(BuddiesStrings.dayLimit, danger: true);
          return;
        }
        switch (type) {
          case BuddyErrorTypes.waitingLimit:
            _note(BuddiesStrings.waitingLimit, danger: true);
          case BuddyErrorTypes.buddyLimit:
            _note(BuddiesStrings.buddyLimit, danger: true);
          case BuddyErrorTypes.cannotAddNow:
            _note(BuddiesStrings.cannotAddNow, danger: true);
          case BuddyErrorTypes.tryLater:
            _setRelation(BuddyRelation.cooldown);
          case BuddyErrorTypes.alreadyBuddies:
            await _researchSame();
          case BuddyErrorTypes.personNotFound:
            person.value = null;
            state.value = FindState.notFound;
          case BuddyErrorTypes.buddyRequestsOnHold:
            _note(BuddiesStrings.onHold, danger: true);
          case BuddyErrorTypes.selfRequest:
            _note(BuddiesStrings.selfRequest, danger: true);
          default:
            AppToast.error(BuddySharedStrings.somethingWrong);
        }
      case BuddyOffline() || BuddyFailed():
        BuddyFeedback.writeFailed(r);
    }
  }

  Future<void> cancelRequest() async {
    final p = person.value;
    final id = p?.requestId;
    if (p == null || id == null || busy.value) return;
    busy.value = true;
    final r = await api.cancel(id);
    busy.value = false;
    if (r is BuddyOk) {
      sentHere.value = false;
      _setRelation(BuddyRelation.none);
      BuddySummaryController.maybe?.load();
    } else if (r is BuddyRefused<void> && r.type == BuddyErrorTypes.alreadyBuddies) {
      await _researchSame();
    } else {
      BuddyFeedback.writeFailed(r);
    }
  }

  Future<void> accept() async {
    final p = person.value;
    final id = p?.requestId;
    if (p == null || id == null || busy.value) return;
    busy.value = true;
    final r = await api.accept(id);
    busy.value = false;
    switch (r) {
      case BuddyOk():
        _setRelation(BuddyRelation.buddy);
        _note(BuddiesStrings.nowYourBuddy(p.name));
        BuddySummaryController.maybe?.load();
      case BuddyRefused(:final type):
        final line = BuddyFeedback.acceptLine(type);
        if (line != null) {
          _note(line, danger: true);
        } else if (type == BuddyErrorTypes.requestEnded) {
          await _researchSame();
        } else {
          BuddyFeedback.writeFailed(r);
        }
      case BuddyOffline() || BuddyFailed():
        BuddyFeedback.writeFailed(r);
    }
  }

  Future<void> _researchSame() async {
    final q = _query;
    if (q == null) return;
    state.value = FindState.idle;
    await search(raw: q, source: _source);
  }

  void personBlocked(String userId) {
    if (person.value?.userId != userId) return;
    person.value = null;
    state.value = FindState.notFound;
  }

  void personRemoved(String userId) {
    if (person.value?.userId == userId) _setRelation(BuddyRelation.none);
  }

  @override
  void onClose() {
    _restTimer?.cancel();
    text.dispose();
    focus.dispose();
    super.onClose();
  }
}
