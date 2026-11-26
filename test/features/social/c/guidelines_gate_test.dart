import 'dart:async';

import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:bakhli/features/social/c/chat/open_room_tracker.dart';
import 'package:bakhli/features/social/c/chat/room_controller.dart';
import 'package:bakhli/features/social/shared/data/social_me_api.dart';
import 'package:bakhli/features/social/shared/social_error_types.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'chat_fakes.dart';
import 'plus_fakes.dart';

class GateMe extends FakeSocialMeController {
  GateMe({bool? accepted}) : super(freeLimits()) {
    me.value = SocialMe(limits: freeLimits(), guidelinesAccepted: accepted);
  }

  int accepts = 0;
  String? acceptError;

  @override
  Future<String?> acceptGuidelines() async {
    accepts++;
    if (acceptError != null) return acceptError;
    applyGuidelinesAccepted(true);
    return null;
  }
}

class TripQueueApi extends FakeChatApi {
  final List<BuddyResult<ChatRoomModel>> tripQueue = [];
  int tripCalls = 0;

  @override
  Future<BuddyResult<ChatRoomModel>> tripRoom(String tripId) async {
    tripCalls++;
    return tripQueue.removeAt(0);
  }
}

class StartQueueApi extends FakeChatApi {
  final List<BuddyResult<StartedChat>> startQueue = [];
  final List<String> startIds = [];

  @override
  Future<BuddyResult<StartedChat>> start({required String toUserId, required String clientMessageId, required String text}) async {
    startIds.add(clientMessageId);
    return startQueue.removeAt(0);
  }
}

class SlowMeApi extends SocialMeApi {
  SlowMeApi();

  final List<Completer<BuddyResult<SocialMe>>> pending = [];

  @override
  Future<BuddyResult<SocialMe>> me() {
    final c = Completer<BuddyResult<SocialMe>>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<BuddyResult<void>> acceptGuidelines() async => const BuddyOk(null);
}

const _refusal = BuddyRefused<Object?>(type: SocialErrorTypes.guidelinesNotAccepted, statusCode: 403, message: 'Accept the guidelines first.');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeChatApi api;
  late FakeTransport hub;
  late GateMe me;
  var ids = 0;
  var prompts = 0;
  var groupFlags = <bool>[];

  setUp(() {
    api = FakeChatApi();
    hub = FakeTransport();
    ids = 0;
    prompts = 0;
    groupFlags = [];
  });
  tearDown(() {
    OpenRoomTracker.clear();
    Get.reset();
  });

  Future<RoomController> open({String? roomId = 'r1', String? userId, String? tripId, bool? accepted, FakeChatApi? useApi, Future<bool> Function(bool group)? prompt}) async {
    me = GateMe(accepted: accepted);
    Get.put<SocialMeController>(me);
    final c = Get.put(RoomController(
        roomId: roomId, userId: userId, tripId: tripId, api: useApi ?? api, transport: hub, myId: () => myId, newId: () => 'cid${ids++}', foreground: () => true));
    c.guidelinesPrompt = prompt ??
        (group) async {
          prompts++;
          groupFlags.add(group);
          return (await me.acceptGuidelines()) == null;
        };
    await settle();
    return c;
  }

  test('first send while not accepted shows the guidelines once, then sends the same text', () async {
    final c = await open(accepted: false);
    hub.hubReplies
      ..add({'ok': true, 'message': messageJson(1, sender: myId, text: 'Hello', cid: 'cid0')})
      ..add({'ok': true, 'message': messageJson(2, sender: myId, text: 'Again', cid: 'cid1')});
    expect(await c.send('Hello'), isTrue);
    expect(prompts, 1);
    expect(me.accepts, 1);
    expect(groupFlags, [false]);
    expect(c.messages.single.text, 'Hello');
    expect(me.me.value!.guidelinesAccepted, isTrue);
    expect(await c.send('Again'), isTrue);
    expect(prompts, 1);
    expect(c.messages.map((m) => m.text), ['Hello', 'Again']);
  });

  test('closing the sheet sends nothing and loses nothing: send returns false, no bubble, no call', () async {
    final c = await open(accepted: false, prompt: (_) async {
      prompts++;
      return false;
    });
    expect(await c.send('Keep me'), isFalse);
    expect(prompts, 1);
    expect(c.messages, isEmpty);
    expect(hub.hubIds, isEmpty);
    expect(api.sentIds, isEmpty);
    expect(me.me.value!.guidelinesAccepted, isFalse);
  });

  test('accepted or unknown: no sheet is shown', () async {
    final c = await open(accepted: true);
    hub.hubReplies.add({'ok': true, 'message': messageJson(1, sender: myId, text: 'Hi', cid: 'cid0')});
    await c.send('Hi');
    expect(prompts, 0);
    Get.reset();
    final c2 = await open(accepted: null);
    hub.hubReplies.add({'ok': true, 'message': messageJson(1, sender: myId, text: 'Hi', cid: 'cid1')});
    await c2.send('Hi');
    expect(prompts, 0);
  });

  test('GuidelinesNotAccepted from the hub: sheet, accept, the same text is sent again once with the same id', () async {
    final c = await open(accepted: null);
    hub.hubReplies
      ..add({'ok': false, 'type': SocialErrorTypes.guidelinesNotAccepted, 'message': 'Accept the guidelines first.'})
      ..add({'ok': true, 'message': messageJson(1, sender: myId, text: 'Hello', cid: 'cid0')});
    await c.send('Hello');
    expect(prompts, 1);
    expect(hub.hubIds, ['cid0', 'cid0']);
    expect(c.messages.single.seq, 1);
    expect(c.messages.single.text, 'Hello');
    expect(c.bounced.value, isNull);
  });

  test('GuidelinesNotAccepted over HTTP: accept then retry; a second refusal bounces the text back, no loop', () async {
    final c = await open(accepted: null);
    api.sendResults
      ..add(_refusal.cast<ChatMessageModel>())
      ..add(_refusal.cast<ChatMessageModel>());
    await c.send('Hello');
    expect(prompts, 1);
    expect(api.sentIds, ['cid0', 'cid0']);
    expect(c.messages, isEmpty);
    expect(c.bounced.value, 'Hello');
    expect(c.refusal.value?.type, SocialErrorTypes.guidelinesNotAccepted);
  });

  test('GuidelinesNotAccepted and the sheet is closed: the text bounces back to the composer', () async {
    final c = await open(accepted: null, prompt: (_) async {
      prompts++;
      return false;
    });
    hub.hubReplies.add({'ok': false, 'type': SocialErrorTypes.guidelinesNotAccepted, 'message': 'x'});
    await c.send('Keep me');
    expect(prompts, 1);
    expect(c.messages, isEmpty);
    expect(c.bounced.value, 'Keep me');
    expect(hub.hubIds, ['cid0']);
  });

  test('first message of a new chat: refused, accepted, started again once with the same id', () async {
    final start = StartQueueApi()
      ..preflightResult = BuddyOk(ChatPreflight.fromJson({'room': null, 'peer': personJson(peerId, 'Kavya'), 'canMessage': true, 'lock': 'none', 'newChats': {'limit': 3, 'used': 0}}))
      ..startQueue.addAll([_refusal.cast<StartedChat>(), BuddyOk(StartedChat(room: roomOf(), message: msgOf(1, sender: myId, text: 'Hi Kavya', cid: 'cid0')))]);
    final c = await open(roomId: null, userId: peerId, accepted: null, useApi: start);
    await c.send('Hi Kavya');
    expect(prompts, 1);
    expect(start.startIds, ['cid0', 'cid0']);
    expect(c.room.value?.roomId, 'r1');
    expect(c.messages.single.seq, 1);
  });

  test('group entry refused: the sheet says group, accept, the trip room is fetched again', () async {
    final trip = roomOf(kind: 'T', trip: {'tripId': 't1', 'title': 'Manali', 'memberCount': 3, 'photoUrls': []});
    final tripApi = TripQueueApi()
      ..tripQueue.addAll([_refusal.cast<ChatRoomModel>(), BuddyOk(trip)])
      ..messagesResult = const BuddyOk(MessagesPage(items: []));
    final c = await open(roomId: null, tripId: 't1', accepted: false, useApi: tripApi);
    expect(prompts, 1);
    expect(groupFlags, [true]);
    expect(tripApi.tripCalls, 2);
    expect(c.view.value, RoomView.ready);
    expect(c.room.value?.isTrip, isTrue);
  });

  test('group entry refused and the sheet is closed: the entry fails with a retry, no crash', () async {
    final tripApi = TripQueueApi()..tripQueue.add(_refusal.cast<ChatRoomModel>());
    final c = await open(roomId: null, tripId: 't1', accepted: false, useApi: tripApi, prompt: (_) async {
      prompts++;
      return false;
    });
    expect(prompts, 1);
    expect(c.view.value, RoomView.failed);
  });

  test('entry on a trip chat asks once when the server did not refuse; the accepted state is kept', () async {
    final trip = roomOf(kind: 'T', trip: {'tripId': 't1', 'title': 'Manali', 'memberCount': 3, 'photoUrls': []});
    final tripApi = TripQueueApi()..tripQueue.add(BuddyOk(trip));
    final c = await open(roomId: null, tripId: 't1', accepted: false, useApi: tripApi);
    expect(prompts, 0);
    await c.ensureGuidelinesOnEntry();
    await c.ensureGuidelinesOnEntry();
    expect(prompts, 1);
    expect(groupFlags, [true]);
    expect(c.needsGuidelines, isFalse);
  });

  test('two asks at the same moment show one sheet', () async {
    final gate = Completer<bool>();
    final c = await open(accepted: false, prompt: (_) {
      prompts++;
      return gate.future;
    });
    final a = c.askGuidelines();
    final b = c.askGuidelines();
    expect(prompts, 1);
    gate.complete(true);
    expect(await a, isTrue);
    expect(await b, isTrue);
  });

  test('CannotMessage on an open room turns the composer off (the cannot-message state); a reload clears it', () async {
    final c = await open(accepted: true);
    expect(c.canSend, isTrue);
    hub.hubReplies.add({'ok': false, 'type': SocialErrorTypes.cannotMessage, 'message': 'You cannot message this person.'});
    await c.send('Hello');
    expect(c.cannotMessageNow.value, isTrue);
    expect(c.canSend, isFalse);
    expect(c.bounced.value, 'Hello');
    await c.open();
    await settle();
    expect(c.cannotMessageNow.value, isFalse);
  });

  test('SocialMeController keeps the flag false until the server saves it', () async {
    await open(accepted: false);
    me.acceptError = 'Offline';
    expect(await me.acceptGuidelines(), 'Offline');
    expect(me.guidelinesMissing, isTrue);
    me.acceptError = null;
    expect(await me.acceptGuidelines(), isNull);
    expect(me.guidelinesMissing, isFalse);
  });
  test('a refresh that started before the acceptance never turns the flag back to false', () async {
    final slow = SlowMeApi();
    final c = SocialMeController(api: slow);
    c.me.value = SocialMe(limits: freeLimits(), guidelinesAccepted: false);
    final stale = c.refreshQuiet();
    expect(await c.acceptGuidelines(), isNull);
    expect(c.guidelinesMissing, isFalse);
    slow.pending.single.complete(BuddyOk(SocialMe(limits: freeLimits(), guidelinesAccepted: false)));
    await stale;
    expect(c.guidelinesMissing, isFalse);
  });

  test('the room is reopened while the sheet is up: no retry, the typed text still comes back to the composer', () async {
    late RoomController c;
    c = await open(accepted: null, prompt: (_) async {
      prompts++;
      unawaited(c.open());
      return (await me.acceptGuidelines()) == null;
    });
    api.sendResults.add(_refusal.cast<ChatMessageModel>());
    await c.send('Do not lose me');
    await settle();
    expect(prompts, 1);
    expect(api.sentIds, ['cid0']);
    expect(c.messages.where((m) => m.isLocal), isEmpty);
    expect(c.bounced.value, 'Do not lose me');
  });
}
