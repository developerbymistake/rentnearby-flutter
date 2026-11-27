import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../buddy/shared/buddy_json.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import 'data/social_chat_api.dart';
import 'dm_hub_bridge.dart';
import 'models/chat_models.dart';
import 'open_room_tracker.dart';
import 'rooms_controller.dart';

enum RoomView { loading, ready, failed, offline, gone }

class RoomController extends GetxController {
  RoomController({
    this.roomId,
    this.userId,
    this.tripId,
    SocialChatApi api = const SocialChatApi(),
    DmTransport? transport,
    String? Function()? myId,
    DateTime Function()? now,
    String Function()? newId,
    bool Function()? foreground,
  })  : _api = api,
        _transport = transport ?? DmHubBridge.instance,
        _myId = myId ?? _authId,
        _now = now ?? _utcNow,
        _newId = newId ?? _uuid,
        _foreground = foreground ?? _appResumed;

  static const int maxLength = 500;
  static const int counterFrom = 100;
  static const int counterWarn = 20;
  static const int pageSize = 50;
  static const int pageMax = 100;

  final String? roomId;
  final String? userId;
  final String? tripId;
  final SocialChatApi _api;
  final DmTransport _transport;
  final String? Function() _myId;
  final DateTime Function() _now;
  final String Function() _newId;
  final bool Function() _foreground;

  final room = Rxn<ChatRoomModel>();
  final preflight = Rxn<ChatPreflight>();
  final messages = <ChatMessageModel>[].obs;
  final view = RoomView.loading.obs;
  final peerLastReadSeq = 0.obs;
  final refusal = Rxn<BuddyRefused<Object?>>();
  final cannotMessageNow = false.obs;
  final plusLocked = false.obs;
  Future<bool> Function(bool group)? guidelinesPrompt;
  Completer<bool>? _guidelinesAsk;
  final bounced = Rxn<String>();
  final repliedFree = false.obs;
  final hasOlder = false.obs;
  final loadingOlder = false.obs;
  int lastSeq = 0;
  int _readSent = 0;
  int _gen = 0;
  bool _filling = false;
  final List<ChatMessageModel> _pending = [];
  Timer? _expiry;
  StreamSubscription<DmEvent>? _sub;
  AppLifecycleListener? _lifecycle;
  Worker? _plusWorker;
  Worker? _topWorker;

  static String? _authId() => Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;

  static DateTime _utcNow() => DateTime.now().toUtc();

  static String _uuid() => const Uuid().v4();

  static bool _appResumed() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  String? get currentRoomId => room.value?.roomId;

  bool get isTrip => room.value?.isTrip ?? tripId != null;

  String get lock => room.value?.lock ?? preflight.value?.lock ?? RoomLock.none;

  bool get canMessage => room.value != null || (preflight.value?.canMessage ?? false);

  /// A Free sender after his one message in this room (direct or trip group): the Plus bar replaces the composer.
  bool get plusLockShown => plusLocked.value || lock == RoomLock.plus;

  bool get canSend {
    if (view.value != RoomView.ready || !canMessage || cannotMessageNow.value || plusLockShown) return false;
    final r = room.value;
    if (r != null) return r.canSend && r.lock == RoomLock.none && r.status != RoomStatus.declined;
    return lock == RoomLock.none;
  }

  bool get needsGuidelines => SocialMeController.maybe?.guidelinesMissing ?? false;

  /// Shows the community guidelines once. Resolves true when the server holds the acceptance,
  /// false when there is no screen to ask on or the person closed the sheet.
  Future<bool> askGuidelines() {
    final running = _guidelinesAsk;
    if (running != null) return running.future;
    final prompt = guidelinesPrompt;
    if (prompt == null) return Future.value(false);
    final done = Completer<bool>();
    _guidelinesAsk = done;
    prompt(isTrip).then((ok) => ok, onError: (_) => false).then((ok) {
      _guidelinesAsk = null;
      done.complete(ok);
    });
    return done.future;
  }

  /// First entry to a trip chat: ask once, then open the room if the server had refused the entry.
  Future<void> ensureGuidelinesOnEntry() async {
    if (!needsGuidelines) return;
    final ok = await askGuidelines();
    if (ok && view.value == RoomView.failed) unawaited(open());
  }

  static bool _isGuidelines(BuddyResult<Object?> r) => r is BuddyRefused<Object?> && r.type == SocialErrorTypes.guidelinesNotAccepted;

  bool isMine(ChatMessageModel m) => m.senderId != null && m.senderId == _myId();

  @override
  void onInit() {
    super.onInit();
    _sub = _transport.events.listen(onEvent);
    _lifecycle = AppLifecycleListener(onResume: markRead);
    _topWorker = ever<String?>(OpenRoomTracker.top, (id) {
      if (id != null && id == currentRoomId) markRead();
    });
    final me = SocialMeController.maybe;
    if (me != null) {
      var wasPlus = me.me.value?.limits.isPlus ?? false;
      _plusWorker = ever<SocialMe?>(me.me, (v) {
        final plus = v?.limits.isPlus ?? false;
        if (plus && !wasPlus) unawaited(refreshLock());
        wasPlus = plus;
      });
    }
    open();
  }

  @override
  void onClose() {
    _gen++;
    _sub?.cancel();
    _expiry?.cancel();
    _lifecycle?.dispose();
    _plusWorker?.dispose();
    _topWorker?.dispose();
    guidelinesPrompt = null;
    super.onClose();
  }

  Future<void> open() async {
    final gen = ++_gen;
    view.value = RoomView.loading;
    cannotMessageNow.value = false;
    final id = roomId;
    final trip = tripId;
    final user = userId;
    if (id != null) {
      final r = await _roomOrGuidelines(() => _api.room(id), gen);
      if (r == null) return;
      _onRoom(r, gen);
    } else if (trip != null) {
      final r = await _roomOrGuidelines(() => _api.tripRoom(trip), gen);
      if (r == null) return;
      _onRoom(r, gen);
    } else if (user != null) {
      final r = await _api.withUser(user);
      if (gen != _gen) return;
      switch (r) {
        case BuddyOk(:final value):
          preflight.value = value;
          final existing = value.room;
          if (existing == null) {
            view.value = RoomView.ready;
          } else {
            room.value = existing;
            await loadMessages();
          }
        default:
          _fail(r);
      }
      return;
    } else {
      view.value = RoomView.gone;
      return;
    }
    if (gen == _gen && room.value != null) await loadMessages();
  }

  /// A group entry the server refuses until the guidelines are accepted: ask once, then fetch again.
  /// Returns null when this open was replaced meanwhile.
  Future<BuddyResult<ChatRoomModel>?> _roomOrGuidelines(Future<BuddyResult<ChatRoomModel>> Function() fetch, int gen) async {
    var r = await fetch();
    if (gen != _gen) return null;
    if (_isGuidelines(r)) {
      SocialMeController.maybe?.applyGuidelinesAccepted(false);
      if (await askGuidelines()) {
        if (gen != _gen) return null;
        r = await fetch();
        if (gen != _gen) return null;
      }
    }
    return r;
  }

  void _onRoom(BuddyResult<ChatRoomModel> r, int gen) {
    if (gen != _gen) return;
    if (r case BuddyOk(:final value)) {
      room.value = value;
    } else {
      _fail(r);
    }
  }

  void _fail(BuddyResult<Object?> r) {
    view.value = switch (r) {
      BuddyOffline() => RoomView.offline,
      BuddyRefused(:final statusCode) when statusCode == 404 => RoomView.gone,
      _ => RoomView.failed,
    };
  }

  Future<void> loadMessages() async {
    final id = currentRoomId;
    if (id == null) return;
    final gen = _gen;
    final r = await _api.messages(id);
    if (gen != _gen) return;
    switch (r) {
      case BuddyOk(:final value):
        final locals = messages.where((m) => m.isLocal).toList();
        final server = value.items.where((m) => m.seq > 0).toList()..sort((a, b) => a.seq.compareTo(b.seq));
        messages.assignAll([...server, ...locals]);
        hasOlder.value = server.length >= pageSize;
        lastSeq = _maxSeq(value.lastSeq);
        _bumpPeerRead(value.peerLastReadSeq ?? room.value?.peerLastReadSeq ?? 0);
        view.value = RoomView.ready;
        _scheduleExpiry();
        markRead();
      default:
        if (messages.isEmpty) _fail(r);
    }
  }

  int _maxSeq(int floor) {
    var top = floor;
    for (final m in messages) {
      if (m.seq > top) top = m.seq;
    }
    return top;
  }

  void _bumpPeerRead(int seq) {
    if (seq > peerLastReadSeq.value) peerLastReadSeq.value = seq;
  }

  Future<bool> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || text.length > maxLength || !canSend) return false;
    if (needsGuidelines && guidelinesPrompt != null && !await askGuidelines()) return false;
    if (!canSend) return false;
    final cid = _newId();
    messages.add(ChatMessageModel(seq: 0, senderId: _myId(), text: text, createdAt: _now(), clientMessageId: cid, sending: true));
    await _deliver(cid, text);
    return true;
  }

  Future<void> retry(String clientMessageId) async {
    final i = messages.indexWhere((m) => m.clientMessageId == clientMessageId && m.isLocal);
    if (i < 0) return;
    final m = messages[i];
    if (m.sending) return;
    messages[i] = m.copyWith(sending: true, failed: false);
    await _deliver(clientMessageId, m.text);
  }

  Future<void> _deliver(String cid, String text, {bool retried = false}) async {
    final gen = _gen;
    final current = room.value;
    final user = userId;
    if (current == null) {
      if (user == null) return;
      final r = await _api.start(toUserId: user, clientMessageId: cid, text: text);
      if (gen != _gen) return;
      switch (r) {
        case BuddyOk(:final value):
          room.value = value.room;
          _confirm(value.message);
        case BuddyRefused():
          if (await _askAgain(r, retried) && gen == _gen) {
            await _deliver(cid, text, retried: true);
            return;
          }
          _refused(cid, text, r);
        default:
          _markFailed(cid);
      }
      return;
    }
    final hub = await _transport.send(current.roomId, cid, text);
    if (gen != _gen) return;
    if (hub != null) {
      if (BuddyJson.boolean(hub['ok'])) {
        _sent(current, ChatMessageModel.fromJson(BuddyJson.map(hub['message'])));
      } else {
        final refused = BuddyRefused<Object?>(
            type: BuddyJson.strOrNull(hub['type']), statusCode: _statusOf(BuddyJson.strOrNull(hub['type'])), message: BuddyJson.strOrNull(hub['message']), data: BuddyJson.map(hub['data']));
        if (await _askAgain(refused, retried) && gen == _gen) {
          await _deliver(cid, text, retried: true);
          return;
        }
        _refused(cid, text, refused);
      }
      return;
    }
    final r = await _api.send(current.roomId, clientMessageId: cid, text: text);
    if (gen != _gen) return;
    switch (r) {
      case BuddyOk(:final value):
        _sent(current, value);
      case BuddyRefused():
        if (await _askAgain(r, retried) && gen == _gen) {
          await _deliver(cid, text, retried: true);
          return;
        }
        _refused(cid, text, r);
      default:
        _markFailed(cid);
    }
  }

  /// The server refused because the guidelines are not accepted yet: show the sheet and, once accepted,
  /// send the same message again (once). Declined: the caller bounces the text back to the composer.
  Future<bool> _askAgain(BuddyRefused<Object?> r, bool retried) async {
    if (retried || !_isGuidelines(r)) return false;
    SocialMeController.maybe?.applyGuidelinesAccepted(false);
    return askGuidelines();
  }

  static int _statusOf(String? type) => switch (type) {
        SocialErrorTypes.newChatLimit || SocialErrorTypes.tooManyRequests => 429,
        SocialErrorTypes.roomNotFound || SocialErrorTypes.personNotFound => 404,
        SocialErrorTypes.cannotMessage || SocialErrorTypes.seekerOnly || SocialErrorTypes.guidelinesNotAccepted => 403,
        SocialErrorTypes.textTooLong => 400,
        _ => 409,
      };

  void _sent(ChatRoomModel before, ChatMessageModel m) {
    _confirm(m);
    if (before.isIncomingRequest) {
      room.value = room.value?.copyWith(status: RoomStatus.active, lock: RoomLock.none, canSend: true);
      repliedFree.value = true;
    }
    if (!(SocialMeController.maybe?.me.value?.limits.isPlus ?? false) || before.isRequest && before.iStarted) unawaited(_refreshRoom());
  }

  Future<void> _refreshRoom() async {
    final id = currentRoomId;
    if (id == null) return;
    final gen = _gen;
    final r = await _api.room(id);
    if (gen != _gen) return;
    if (r case BuddyOk(:final value)) room.value = value;
  }

  Future<void> refreshLock() async {
    plusLocked.value = false;
    if (currentRoomId != null) return _refreshRoom();
    final user = userId;
    if (user == null) return;
    final gen = _gen;
    final r = await _api.withUser(user);
    if (gen != _gen) return;
    if (r case BuddyOk(:final value)) {
      preflight.value = value;
      final existing = value.room;
      if (existing != null && room.value == null) {
        room.value = existing;
        await loadMessages();
      }
    }
  }

  void _confirm(ChatMessageModel m) {
    final i = messages.indexWhere((x) => x.isLocal && x.clientMessageId != null && x.clientMessageId == m.clientMessageId);
    if (i >= 0) messages.removeAt(i);
    if (m.seq > 0 && !messages.any((x) => x.seq == m.seq)) _insertSorted(m);
    if (m.seq > lastSeq) lastSeq = m.seq;
    _readSent = lastSeq > _readSent ? lastSeq : _readSent;
    _scheduleExpiry();
  }

  void _insertSorted(ChatMessageModel m) {
    var at = messages.length;
    for (var i = 0; i < messages.length; i++) {
      final x = messages[i];
      if (x.isLocal || x.seq > m.seq) {
        at = i;
        break;
      }
    }
    messages.insert(at, m);
  }

  void _refused(String cid, String text, BuddyRefused<Object?> r) {
    final type = r.type;
    final bounce = type == SocialErrorTypes.awaitingReply ||
        type == SocialErrorTypes.newChatLimit ||
        type == SocialErrorTypes.cannotMessage ||
        type == SocialErrorTypes.guidelinesNotAccepted ||
        type == SocialErrorTypes.textTooLong ||
        type == SocialErrorTypes.roomNotFound ||
        type == SocialErrorTypes.personNotFound ||
        type == SocialErrorTypes.plusRequired;
    if (!bounce) {
      _markFailed(cid);
      refusal.value = r;
      return;
    }
    messages.removeWhere((m) => m.isLocal && m.clientMessageId == cid);
    bounced.value = text;
    final current = room.value;
    if (type == SocialErrorTypes.awaitingReply) {
      room.value = current?.copyWith(lock: RoomLock.awaitingReply, canSend: false);
    } else if (type == SocialErrorTypes.newChatLimit) {
      final p = preflight.value;
      if (p != null) preflight.value = ChatPreflight(room: p.room, peer: p.peer, canMessage: p.canMessage, lock: RoomLock.limit, newChats: p.newChats, isFree: p.isFree);
    } else if (type == SocialErrorTypes.cannotMessage) {
      cannotMessageNow.value = true;
      final p = preflight.value;
      if (p != null) preflight.value = ChatPreflight(room: p.room, peer: p.peer, canMessage: false, lock: p.lock, newChats: p.newChats, isFree: p.isFree);
    } else if (type == SocialErrorTypes.plusRequired) {
      plusLocked.value = true;
      SocialMeController.maybe?.refreshQuiet();
    } else if (type == SocialErrorTypes.roomNotFound || type == SocialErrorTypes.personNotFound) {
      view.value = RoomView.gone;
    }
    refusal.value = r;
  }

  void _markFailed(String cid) {
    final i = messages.indexWhere((m) => m.isLocal && m.clientMessageId == cid);
    if (i >= 0) messages[i] = messages[i].copyWith(sending: false, failed: true);
  }

  void onEvent(DmEvent e) {
    final id = currentRoomId;
    switch (e) {
      case final DmMessageEvent m when m.roomId == id:
        unawaited(applyIncoming(m.message, roomStatus: m.roomStatus));
      case final DmReadEvent r when r.roomId == id && r.userId != _myId():
        _bumpPeerRead(r.seq);
      case final DmRoomChangedEvent c when c.roomId == id:
        room.value = room.value?.copyWith(status: c.status, lock: c.lock, canSend: c.lock == RoomLock.none);
      case DmReconnectedEvent():
        if (id != null && view.value == RoomView.ready) unawaited(fillGap());
      default:
        break;
    }
  }

  Future<void> applyIncoming(ChatMessageModel m, {String? roomStatus}) async {
    final cid = m.clientMessageId;
    if (cid != null && messages.any((x) => x.isLocal && x.clientMessageId == cid)) {
      _confirm(m);
      return;
    }
    if (roomStatus != null && room.value?.status != roomStatus) room.value = room.value?.copyWith(status: roomStatus);
    if (m.seq <= lastSeq || messages.any((x) => x.seq == m.seq)) return;
    if (_filling || lastSeq > 0 && m.seq > lastSeq + 1) {
      if (!_pending.any((x) => x.seq == m.seq)) _pending.add(m);
      await fillGap();
      return;
    }
    _accept(m);
  }

  void _accept(ChatMessageModel m) {
    if (m.seq <= 0 || messages.any((x) => x.seq == m.seq)) return;
    _insertSorted(m);
    if (m.seq > lastSeq) lastSeq = m.seq;
    _scheduleExpiry();
    markRead();
  }

  Future<void> fillGap() async {
    final id = currentRoomId;
    if (id == null || _filling) return;
    _filling = true;
    final gen = _gen;
    var filled = false;
    var cursor = lastSeq;
    try {
      while (true) {
        final r = await _api.messages(id, afterSeq: cursor, limit: pageMax);
        if (gen != _gen) return;
        if (r is! BuddyOk<MessagesPage>) break;
        final page = r.value;
        var top = cursor;
        for (final m in page.items) {
          final cid = m.clientMessageId;
          if (cid != null && messages.any((x) => x.isLocal && x.clientMessageId == cid)) {
            _confirm(m);
          } else if (m.seq > 0 && !messages.any((x) => x.seq == m.seq)) {
            _insertSorted(m);
          }
          if (m.seq > top) top = m.seq;
        }
        _bumpPeerRead(page.peerLastReadSeq ?? 0);
        final advanced = top > cursor;
        cursor = top;
        if (page.items.length < pageMax || !advanced || cursor >= page.lastSeq) {
          filled = true;
          break;
        }
      }
      lastSeq = math.max(lastSeq, math.max(cursor, _maxSeq(0)));
    } finally {
      _filling = false;
    }
    if (gen != _gen) return;
    if (filled) _drainPending();
    _scheduleExpiry();
    markRead();
  }

  void _drainPending() {
    if (_pending.isEmpty) return;
    final queued = [..._pending]..sort((a, b) => a.seq.compareTo(b.seq));
    _pending.clear();
    for (final m in queued) {
      if (m.seq > lastSeq && !messages.any((x) => x.seq == m.seq)) {
        _insertSorted(m);
        lastSeq = m.seq;
      }
    }
  }

  Future<void> loadOlder() async {
    final id = currentRoomId;
    if (id == null || loadingOlder.value || !hasOlder.value) return;
    int? first;
    for (final m in messages) {
      if (m.seq > 0 && (first == null || m.seq < first)) first = m.seq;
    }
    if (first == null) {
      hasOlder.value = false;
      return;
    }
    final gen = _gen;
    loadingOlder.value = true;
    try {
      final r = await _api.messages(id, beforeSeq: first, limit: pageSize);
      if (gen != _gen) return;
      if (r case BuddyOk(:final value)) {
        final older = value.items.where((m) => m.seq > 0 && !messages.any((x) => x.seq == m.seq)).toList()..sort((a, b) => a.seq.compareTo(b.seq));
        if (older.isNotEmpty) messages.insertAll(0, older);
        hasOlder.value = value.items.length >= pageSize;
        _scheduleExpiry();
      }
    } finally {
      if (gen == _gen) loadingOlder.value = false;
    }
  }

  void markRead() {
    final id = currentRoomId;
    if (id == null || lastSeq <= _readSent || !_foreground()) return;
    final top = OpenRoomTracker.current;
    if (top != null && top != id) return;
    _readSent = lastSeq;
    _transport.read(id, lastSeq);
    RoomsController.maybe?.applyRead(id, lastSeq);
  }

  void removeExpired() {
    final now = _now();
    messages.removeWhere((m) {
      final at = m.expiresAt;
      return at != null && !m.isLocal && !at.isAfter(now);
    });
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    _expiry = null;
    DateTime? first;
    for (final m in messages) {
      final at = m.expiresAt;
      if (at == null || m.isLocal) continue;
      if (first == null || at.isBefore(first)) first = at;
    }
    if (first == null) return;
    final wait = first.difference(_now());
    _expiry = Timer(wait.isNegative ? Duration.zero : wait, removeExpired);
  }

  Future<BuddyResult<void>> deleteRoom() async {
    final id = currentRoomId;
    if (id == null) return const BuddyFailed<void>(message: '');
    final r = await _api.deleteRoom(id);
    if (r.isOk) RoomsController.maybe?.removeRoom(id);
    return r;
  }

  int? latestOtherSeq() {
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (!m.isLocal && !m.isSystem && !isMine(m)) return m.seq;
    }
    return null;
  }

  LimitUse get newChats => preflight.value?.newChats ?? LimitUse.none;

  bool get isFreeChat => preflight.value?.isFree ?? false;
}
