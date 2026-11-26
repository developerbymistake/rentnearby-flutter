import 'dart:async';

import 'package:get/get.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import 'data/social_chat_api.dart';
import 'dm_hub_bridge.dart';
import 'models/chat_models.dart';
import 'open_room_tracker.dart';

enum RoomsLoad { idle, loading, ready, failed, offline }

class RoomsList {
  RoomsList(this.bucket);

  final String bucket;
  final items = <ChatRoomModel>[].obs;
  final state = RoomsLoad.idle.obs;
  final loadingMore = false.obs;
  String? nextCursor;
  int gen = 0;

  bool get hasMore => nextCursor != null;
}

class RoomsController extends GetxController {
  RoomsController({SocialChatApi api = const SocialChatApi(), DmTransport? transport, String? Function()? myId})
      : _api = api,
        _transport = transport ?? DmHubBridge.instance,
        _myId = myId ?? _authId;

  static RoomsController? get maybe => Get.isRegistered<RoomsController>() ? Get.find<RoomsController>() : null;

  static String? _authId() => Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;

  final SocialChatApi _api;
  final DmTransport _transport;
  final String? Function() _myId;
  final unread = ChatUnread.zero.obs;
  final people = RoomsList(RoomBucket.people);
  final trips = RoomsList(RoomBucket.trips);
  final requests = RoomsList(RoomBucket.requests);
  StreamSubscription<DmEvent>? _sub;
  Worker? _meWorker;

  List<RoomsList> get all => [people, trips, requests];

  RoomsList listOf(String bucket) => switch (bucket) {
        RoomBucket.trips => trips,
        RoomBucket.requests => requests,
        _ => people,
      };

  @override
  void onInit() {
    super.onInit();
    _sub = _transport.events.listen(onEvent);
    final me = SocialMeController.maybe;
    if (me != null) {
      _seedUnread(me.me.value);
      _meWorker = ever<SocialMe?>(me.me, _seedUnread);
    }
  }

  @override
  void onClose() {
    _sub?.cancel();
    _meWorker?.dispose();
    super.onClose();
  }

  void _seedUnread(SocialMe? m) {
    if (m != null) unread.value = m.chatUnread;
  }

  Future<void> reloadAll() => Future.wait([for (final l in all) load(l.bucket)]);

  Future<void> load(String bucket) async {
    final list = listOf(bucket);
    final gen = ++list.gen;
    if (list.items.isEmpty) list.state.value = RoomsLoad.loading;
    final r = await _api.rooms(bucket);
    if (gen != list.gen) return;
    switch (r) {
      case BuddyOk(:final value):
        list.items.assignAll(value.items);
        list.nextCursor = value.nextCursor;
        list.state.value = RoomsLoad.ready;
        _setUnread(value.unread);
      case BuddyOffline():
        if (list.items.isEmpty) list.state.value = RoomsLoad.offline;
      default:
        if (list.items.isEmpty) list.state.value = RoomsLoad.failed;
    }
  }

  Future<void> loadMore(String bucket) async {
    final list = listOf(bucket);
    final cursor = list.nextCursor;
    if (cursor == null || list.loadingMore.value) return;
    list.loadingMore.value = true;
    final gen = list.gen;
    final r = await _api.rooms(bucket, cursor: cursor);
    list.loadingMore.value = false;
    if (gen != list.gen) return;
    if (r case BuddyOk(:final value)) {
      final known = {for (final x in list.items) x.roomId};
      list.items.addAll(value.items.where((x) => !known.contains(x.roomId)));
      list.nextCursor = value.nextCursor;
      _setUnread(value.unread);
    }
  }

  void _setUnread(ChatUnread u) {
    unread.value = u;
    SocialMeController.maybe?.applyUnread(u);
  }

  void applyRead(String roomId, int seq) {
    for (final list in all) {
      final i = list.items.indexWhere((x) => x.roomId == roomId);
      if (i < 0) continue;
      final r = list.items[i];
      if (seq > r.lastReadSeq) list.items[i] = r.copyWith(lastReadSeq: seq, unread: 0);
    }
  }

  Future<bool> deleteRoom(String roomId) async {
    final r = await _api.deleteRoom(roomId);
    if (r.isOk) removeRoom(roomId);
    return r.isOk;
  }

  void removeRoom(String roomId) {
    for (final list in all) {
      list.items.removeWhere((x) => x.roomId == roomId);
    }
  }

  void onEvent(DmEvent e) {
    switch (e) {
      case final DmMessageEvent m:
        _onMessage(m);
      case DmUnreadEvent(:final unread):
        _setUnread(unread);
      case DmRoomChangedEvent(:final roomId, :final status, :final lock):
        _onRoomChanged(roomId, status, lock);
      case DmReadEvent():
        break;
      case DmSessionEndedEvent():
        clear();
      case DmReconnectedEvent():
        unawaited(reloadAll());
    }
  }

  void _onMessage(DmMessageEvent e) {
    final m = e.message;
    final mine = m.senderId != null && m.senderId == _myId();
    final open = OpenRoomTracker.current == e.roomId;
    for (final list in all) {
      final i = list.items.indexWhere((x) => x.roomId == e.roomId);
      if (i < 0) continue;
      final r = list.items[i];
      final preview = r.isTrip ? _tripPreview(m) : m.text;
      final next = r.copyWith(
        status: e.roomStatus,
        lastSeq: m.seq > r.lastSeq ? m.seq : r.lastSeq,
        lastMessageAt: m.createdAt ?? DateTime.now().toUtc(),
        preview: preview,
        unread: mine || open ? r.unread : r.unread + 1,
      );
      list.items
        ..removeAt(i)
        ..insert(0, next);
      return;
    }
    unawaited(load(e.kind == RoomKind.trip ? RoomBucket.trips : (e.roomStatus == RoomStatus.request && !mine ? RoomBucket.requests : RoomBucket.people)));
  }

  static String _tripPreview(ChatMessageModel m) => m.isSystem || m.senderName == null ? m.text : '${m.senderName}: ${m.text}';

  void _onRoomChanged(String roomId, String status, String lock) {
    var moved = false;
    for (final list in all) {
      final i = list.items.indexWhere((x) => x.roomId == roomId);
      if (i < 0) continue;
      final r = list.items[i];
      if (list == requests && status == RoomStatus.active) {
        list.items.removeAt(i);
        moved = true;
      } else {
        list.items[i] = r.copyWith(status: status, lock: lock, canSend: lock == RoomLock.none);
      }
    }
    if (moved) unawaited(load(RoomBucket.people));
  }

  void clear() {
    for (final list in all) {
      list.gen++;
      list.items.clear();
      list.nextCursor = null;
      list.state.value = RoomsLoad.idle;
      list.loadingMore.value = false;
    }
    unread.value = ChatUnread.zero;
  }
}
