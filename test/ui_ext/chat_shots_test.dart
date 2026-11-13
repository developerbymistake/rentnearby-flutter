import 'dart:async';
import 'dart:convert';

import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/models/conversation_model.dart';
import 'package:bakhli/models/message_model.dart';
import 'package:bakhli/models/question_template_model.dart';
import 'package:bakhli/screens/chat_conversation_screen.dart';
import 'package:bakhli/screens/chats_list_screen.dart';
import 'package:bakhli/services/chat_hub_service.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

const _dir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\chat';

DateTime _at(int day, int hour) => DateTime(2026, 11, day, hour);

MessageModel _m(String id, String type, bool mine, Map<String, dynamic> payload, {String? respondsTo, bool read = true, int order = 0}) => MessageModel(
      id: id,
      conversationId: 'c1',
      senderId: mine ? 'me' : 'other',
      isMine: mine,
      type: type,
      payloadJson: jsonEncode(payload),
      respondsToMessageId: respondsTo,
      readAt: mine && read ? DateTime(2026, 11, 12) : null,
      createdAt: DateTime(2026, 11, 12, 9, order),
    );

final _templates = [
  for (final q in [
    'Is it available this weekend?',
    'Is it free on my dates?',
    'Can one extra guest stay?',
    'What food is served?',
    'Is pickup from the bus stand available?',
    'Are outside visitors allowed?',
    'Any discount for a longer stay?',
    'Is early check-in possible?',
    'Is there a group or extra room rate?',
    'Can I pay on arrival?',
    'Is there a ground floor room or a lift?',
    'Is it women-only or safe for solo travellers?',
  ])
    QuestionTemplateModel(id: q, key: q, listingType: 'Stay', questionText: q, answerOptions: const [], sortOrder: 0, isActive: true),
];

class _Scene {
  _Scene({this.messages = const [], this.status = 'Active', this.hasMore = false, this.hang = false, this.enquiry, this.owner = false, this.name = 'Meera Joshi', this.blockedByMe = false, this.hangOlder = false, this.hangSend = false});
  final List<MessageModel> messages;
  final String status;
  final bool hasMore;
  final bool hang;
  final bool hangOlder;
  final bool hangSend;
  final TripEnquiryModel? enquiry;
  final bool owner;
  final String name;
  final bool blockedByMe;
}

_Scene _scene = _Scene();

class _Chat extends ChatController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> markRead(String conversationId) async {}
  @override
  Future<List<QuestionTemplateModel>> loadQuestionTemplates({bool forceRefresh = false}) async {
    questionTemplates.value = _templates;
    return questionTemplates;
  }

  @override
  Future<({List<MessageModel> items, String? status, bool hasMore})> getMessages(String conversationId, {DateTime? before, DateTime? after}) {
    if (_scene.hang || (before != null && _scene.hangOlder)) return Completer<({List<MessageModel> items, String? status, bool hasMore})>().future;
    if (before != null || after != null) return Future.value((items: <MessageModel>[], status: null, hasMore: false));
    return Future.value((items: _scene.messages.reversed.toList(), status: _scene.status, hasMore: _scene.hasMore));
  }

  @override
  Future<MessageModel?> sendMessage(String conversationId, String type, Map<String, dynamic> payload, {String? respondsToMessageId, String? clientMessageId}) =>
      _scene.hangSend ? Completer<MessageModel?>().future : Future.value(null);
}

class _Hub extends ChatHubService {
  @override
  Future<void> joinConversation(String conversationId) async {}
  @override
  Future<void> leaveConversation(String conversationId) async {}
}

class _Notif extends NotificationService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}
  @override
  void dismissChatNotification(String conversationId) {}
}

class _Enq extends TripEnquiryController {
  @override
  Future<TripEnquiryModel?> forConversation(String conversationId) async => _scene.enquiry;
  @override
  Future<TripEnquiryModel?> refreshOne(String enquiryId) async => _scene.enquiry;
}

TripEnquiryModel _enquiry() => TripEnquiryModel.fromJson({
      'id': 'e1',
      'tripId': 't1',
      'listingId': 'l1',
      'listingName': 'Deodar Cottage',
      'conversationId': 'c1',
      'status': 'Asked',
      'displayStatus': 'asked',
      'checkIn': '2026-11-14',
      'checkOut': '2026-11-15',
      'context': {'city': 'Kausani', 'adults': 2, 'rooms': 1},
      'traveller': {'name': 'Meera Joshi', 'phone': '9876543210'},
      'owner': {'name': 'Rahul Sharma', 'phone': '9876500000'},
    });

class _Launcher extends StatefulWidget {
  const _Launcher();
  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.to(
        () => const ChatConversationScreen(),
        transition: Transition.noTransition,
        arguments: {
          'conversationId': 'c1',
          'listingType': 'Stay',
          'listingId': 'l1',
          'otherPartyId': 'o1',
          'otherPartyName': _scene.owner ? 'Rahul Sharma' : _scene.name,
          'listingTitle': _scene.status == 'Active' ? 'Deodar Cottage' : 'Ridge Cottage',
          'area': _scene.status == 'Active' ? 'Kausani' : 'Almora',
          'isOwner': _scene.owner,
          'status': _scene.status,
          'isBlockedByMe': _scene.blockedByMe,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

void _register() {
  Get.reset();
  Get.put<ChatController>(_Chat());
  Get.put<ChatHubService>(_Hub());
  Get.put<NotificationService>(_Notif());
  Get.put<TripEnquiryController>(_Enq());
}

Future<void> _open(WidgetTester t, _Scene scene, {double w = 360, double s = 1.0}) async {
  _scene = scene;
  _register();
  debugDisableShadows = false;
  await pumpPhone(t, const _Launcher(), size: Size(w, 800), devicePixelRatio: 1.5, textScale: s);
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await settlePhone(t);
}

Future<void> _snap(WidgetTester t, String name) async {
  await settlePhone(t);
  await shot(t, name);
}

void _done(WidgetTester t) {
  final e = t.takeException();
  debugDisableShadows = true;
  expect(e, isNull);
}

String _tag(double w, double s) => '${w.toInt()}_${s == 1.0 ? '10' : '13'}';

final _sizes = <(double, double)>[(360, 1.0), (360, 1.3), (300, 1.0)];

List<MessageModel> _seekerThread() => [
      _m('q1', 'quick_reply', true, {'key': 'Is it free on my dates?', 'text': 'Is it free on my dates?'}, order: 1),
      _m('a1', 'quick_reply', false, {'key': 'yes', 'text': 'Yes, dates are free'}, respondsTo: 'q1', order: 2),
      _m('cr', 'contact_request', true, {}, order: 3),
      _m('cs', 'contact_response', false, {'approved': true, 'phone': '9876500000'}, respondsTo: 'cr', order: 4),
    ];

List<MessageModel> _ownerThread() => [
      _m('q1', 'quick_reply', false, {
        'key': 'extra',
        'text': 'Can one extra guest stay?',
        'answerOptions': [
          {'key': 'y1', 'text': 'Yes, no extra cost', 'sentiment': 'positive'},
          {'key': 'y2', 'text': 'Yes, extra charge applies', 'sentiment': 'neutral'},
          {'key': 'n', 'text': 'No, listed guests only', 'sentiment': 'negative'},
        ],
      }, order: 1),
      _m('cr', 'contact_request', false, {}, order: 2),
    ];

List<MessageModel> _ownerTripThread() => [
      _m('q1', 'quick_reply', false, {'key': 'f', 'text': 'Is it free on my dates?'}, order: 1),
      _m('a1', 'quick_reply', true, {'key': 'y', 'text': 'Yes, dates are free'}, respondsTo: 'q1', order: 2),
      _m('q2', 'quick_reply', false, {'key': 'g', 'text': 'Can one extra guest stay?'}, order: 3),
      _m('a2', 'quick_reply', true, {'key': 'y', 'text': 'Yes, no extra cost'}, respondsTo: 'q2', order: 4),
    ];

List<MessageModel> _visitReqThread() => [
      _m('q1', 'quick_reply', false, {'key': 'food', 'text': 'What food is served?'}, order: 1),
      _m('a1', 'quick_reply', true, {'key': 'v', 'text': 'Veg and non-veg'}, respondsTo: 'q1', order: 2),
      _m('sp', 'schedule_proposal', false, {
        'status': 'pending',
        'proposedAts': [_at(14, 11).toUtc().toIso8601String(), _at(14, 16).toUtc().toIso8601String()],
      }, order: 3),
    ];

List<MessageModel> _visitThread() => [
      _m('s0', 'schedule_proposal', true, {'status': 'superseded', 'proposedAts': [_at(13, 10).toUtc().toIso8601String()]}, order: 1),
      _m('s1', 'schedule_proposal', true, {
        'status': 'pending',
        'proposedAts': [_at(14, 11).toUtc().toIso8601String(), _at(14, 16).toUtc().toIso8601String()],
      }, order: 2),
      _m('s2', 'schedule_response', false, {'status': 'confirmed', 'confirmedAt': _at(14, 11).toUtc().toIso8601String()}, respondsTo: 's1', order: 3),
    ];

ConversationModel _row(String id, String name, String title, String area, int unread, String preview, {String status = 'Active', Duration ago = const Duration(minutes: 2)}) =>
    ConversationModel(
      id: id,
      listingType: 'Stay',
      listingId: 'l$id',
      listingTitle: title,
      area: area,
      otherPartyId: 'o$id',
      otherPartyName: name,
      isOwner: false,
      status: status,
      lastMessageAt: DateTime.now().toUtc().subtract(ago),
      lastMessagePreview: preview.isEmpty ? null : preview,
      unreadCount: unread,
    );

class _ListChat extends ChatController {
  _ListChat(this.rows, {this.loading = false, this.more = false});
  final List<ConversationModel> rows;
  final bool loading;
  final bool more;
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadConversations({bool forceRefresh = false}) async {
    conversationsLoading.value = loading;
    loadingMoreConversations.value = more;
    hasMoreConversations.value = false;
    conversations.value = rows;
  }

  @override
  Future<void> loadMoreConversations() async {}
}

final _mainRows = [
  _row('1', 'Meera Joshi', 'Deodar Cottage', 'Kausani', 2, 'Yes, dates are free'),
  _row('2', 'Kavita Rawat', 'Lakeside Rooms', 'Nainital', 140, 'Is an advance needed?', ago: const Duration(hours: 1)),
  _row('3', 'Anil Bisht', 'Pine Ridge', 'Mukteshwar', 0, 'Can I pay on arrival?', ago: const Duration(hours: 5)),
  _row('4', 'Deepak Negi', 'Himalayan View', 'Bhimtal', 0, '', ago: const Duration(days: 3)),
];

final _moreRows = [
  _row('5', 'Sunita Mehra', 'Ridge Cottage', 'Almora', 0, 'What food is served?', status: 'ListingInactive', ago: const Duration(days: 3)),
  _row('6', 'Pooja Rana', 'Maple Rooms', 'Mussoorie', 0, 'Are outside visitors allowed?', status: 'ListingRemoved', ago: const Duration(days: 11)),
  _row('7', 'Ravi Kumar', 'Oak Homestay', 'Ranikhet', 0, 'Is early check-in possible?', status: 'Blocked', ago: const Duration(days: 10)),
  _row('8', 'Mohan Lal', 'Snow Peak', 'Auli', 0, '', status: 'Closed', ago: const Duration(days: 15)),
];

Future<void> _openList(WidgetTester t, ChatController c, {double w = 360, double s = 1.0}) async {
  Get.reset();
  Get.put<ChatController>(c);
  debugDisableShadows = false;
  await pumpPhone(t, const ChatsListScreen(), size: Size(w, 800), devicePixelRatio: 1.5, textScale: s);
  await settlePhone(t);
}

void main() {
  setUp(() => shotsDir = _dir);

  group('chats list', () {
    for (final (w, s) in _sizes) {
      testWidgets('list_main ${_tag(w, s)}', (t) async {
        await _openList(t, _ListChat(_mainRows), w: w, s: s);
        await _snap(t, 'list_main_${_tag(w, s)}');
        expect(find.text('99+'), findsOneWidget);
        if (s == 1.0 && w == 360) expect(find.text('Say hi'), findsOneWidget);
        _done(t);
      });
    }
    testWidgets('list_more', (t) async {
      await _openList(t, _ListChat(_moreRows, more: true));
      final pos = t.state<ScrollableState>(find.byType(Scrollable).last).position;
      pos.jumpTo(pos.maxScrollExtent);
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'list_more_360_10');
      expect(find.text('Say hi'), findsOneWidget);
      expect(find.text('STAY · LISTING REMOVED'), findsOneWidget);
      expect(find.text('STAY · UNAVAILABLE'), findsOneWidget);
      _done(t);
    });
    testWidgets('list_search and list_nomatch', (t) async {
      await _openList(t, _ListChat(_mainRows));
      await t.tap(find.byTooltip('Search'));
      await t.pump(const Duration(milliseconds: 500));
      await t.enterText(find.byType(TextField), 'e');
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'list_search_360_10');
      await t.enterText(find.byType(TextField), 'xyz');
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'list_nomatch_360_10');
      expect(find.text('No matches for "xyz"'), findsOneWidget);
      await t.tap(find.byTooltip('Close search'));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Meera Joshi'), findsOneWidget);
      _done(t);
    });
    testWidgets('list_empty', (t) async {
      await _openList(t, _ListChat(const []));
      await _snap(t, 'list_empty_360_10');
      expect(find.text('Start a chat from any stay.'), findsOneWidget);
      _done(t);
    });
    testWidgets('list_loading', (t) async {
      await _openList(t, _ListChat(const [], loading: true));
      await _snap(t, 'list_loading_360_10');
      _done(t);
    });
  });

  group('conversation', () {
    for (final (w, s) in _sizes) {
      testWidgets('c_seeker ${_tag(w, s)}', (t) async {
        await _open(t, _Scene(messages: _seekerThread(), enquiry: _enquiry()), w: w, s: s);
        await _snap(t, 'c_seeker_${_tag(w, s)}');
        expect(find.text('Contact number requested'), findsOneWidget);
        expect(find.text('Call'), findsOneWidget);
        expect(find.text('Ask something'), findsOneWidget);
        _done(t);
      });
      testWidgets('c_visitreq ${_tag(w, s)}', (t) async {
        await _open(t, _Scene(messages: _visitReqThread(), owner: true), w: w, s: s);
        await _snap(t, 'c_visitreq_${_tag(w, s)}');
        _done(t);
      });
    }
    testWidgets('c_owner', (t) async {
      await _open(t, _Scene(messages: _ownerThread(), owner: true));
      await _snap(t, 'c_owner_360_10');
      expect(find.text('No, listed guests only'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      _done(t);
    });
    testWidgets('c_owner_trip', (t) async {
      await _open(t, _Scene(messages: _ownerTripThread(), owner: true, enquiry: _enquiry()));
      await _snap(t, 'c_owner_trip_360_10');
      expect(find.byKey(const ValueKey('trip-owner-bar')), findsOneWidget);
      _done(t);
    });
    testWidgets('c_visit and c_visitno', (t) async {
      await _open(t, _Scene(messages: _visitThread()));
      await _snap(t, 'c_visit_360_10');
      _done(t);
    });
    testWidgets('c_visitno', (t) async {
      await _open(t, _Scene(messages: [
        _m('sp', 'schedule_proposal', true, {'status': 'pending', 'proposedAts': [_at(14, 11).toUtc().toIso8601String()]}, order: 1),
        _m('sr', 'schedule_response', false, {'status': 'declined'}, respondsTo: 'sp', order: 2),
        _m('cr', 'contact_request', true, {}, order: 3),
        _m('cs', 'contact_response', false, {'approved': false}, respondsTo: 'cr', order: 4),
      ]));
      await _snap(t, 'c_visitno_360_10');
      expect(find.text('Visit request declined'), findsOneWidget);
      expect(find.text('Contact request declined'), findsOneWidget);
      _done(t);
    });
    testWidgets('c_new, c_loading', (t) async {
      await _open(t, _Scene());
      await _snap(t, 'c_new_360_10');
      expect(find.text('Ask something'), findsOneWidget);
      _done(t);
    });
    testWidgets('c_loading', (t) async {
      await _open(t, _Scene(hang: true, enquiry: _enquiry()));
      await _snap(t, 'c_loading_360_10');
      _done(t);
    });
    testWidgets('c_older', (t) async {
      final many = [
        for (var i = 0; i < 16; i++) _m('m$i', 'quick_reply', i.isOdd, {'key': 'k$i', 'text': i.isOdd ? 'Is it free on my dates?' : 'Yes, dates are free'}, order: i),
      ];
      await _open(t, _Scene(messages: many, hasMore: true, hangOlder: true));
      final list = find.byType(Scrollable).last;
      t.state<ScrollableState>(list).position.jumpTo(0);
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      await _snap(t, 'c_older_360_10');
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      _done(t);
    });
    testWidgets('c_sending with toast slot', (t) async {
      await _open(t, _Scene(messages: _seekerThread().take(2).toList(), hangSend: true));
      await t.tap(find.text('Ask something'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.text('Is pickup from the bus stand available?'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(ToastLane.showInHost(ToastKind.error, 'Could not send that. Please try again.'), isTrue);
      await t.pump(const Duration(milliseconds: 400));
      await _snap(t, 'c_sending_360_10');
      await t.pump(const Duration(seconds: 5));
      _done(t);
    });
    testWidgets('c_menu, c_block', (t) async {
      await _open(t, _Scene(messages: _seekerThread(), enquiry: _enquiry()));
      await t.tap(find.byTooltip('More').first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'c_menu_360_10');
      expect(find.text('Report'), findsOneWidget);
      await t.tap(find.text('Block this user'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await _snap(t, 'c_block_360_10');
      expect(find.text('Block this user?'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pump(const Duration(milliseconds: 400));
      _done(t);
    });
    for (final (w, s) in _sizes.skip(1)) {
      testWidgets('c_block ${_tag(w, s)}', (t) async {
        await _open(t, _Scene(messages: _seekerThread(), enquiry: _enquiry()), w: w, s: s);
        await t.tap(find.byTooltip('More').first);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.text('Block this user'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        await _snap(t, 'c_block_${_tag(w, s)}');
        _done(t);
      });
    }
    testWidgets('c_blocked, c_menu_ub, c_unblock', (t) async {
      await _open(t, _Scene(messages: _seekerThread().take(3).toList(), enquiry: _enquiry(), status: 'Blocked', blockedByMe: true));
      await _snap(t, 'c_blocked_360_10');
      expect(find.text('Unblock'), findsOneWidget);
      await t.tap(find.byTooltip('More').first);
      await t.pump(const Duration(milliseconds: 300));
      await _snap(t, 'c_menu_ub_360_10');
      await t.tap(find.text('Unblock the user'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await _snap(t, 'c_unblock_360_10');
      expect(find.text('Unblock this user?'), findsOneWidget);
      _done(t);
    });
    for (final (key, status, text) in [
      ('c_removed', 'ListingRemoved', 'This listing has been removed — you can no longer send messages here.'),
      ('c_inactive', 'ListingInactive', 'This listing is currently inactive — you can no longer send messages here.'),
      ('c_blockedby', 'Blocked', 'You can no longer message in this conversation.'),
      ('c_ended', 'Closed', 'This conversation is no longer active.'),
    ]) {
      testWidgets(key, (t) async {
        await _open(t, _Scene(messages: key == 'c_removed' ? const [] : _seekerThread().take(2).toList(), status: status, name: 'Sunita Mehra'));
        await _snap(t, '${key}_360_10');
        expect(find.text(text), findsOneWidget);
        expect(find.text('Ask something'), findsNothing);
        _done(t);
      });
    }
  });

  group('sheets', () {
    for (final (w, s) in _sizes) {
      testWidgets('s_plus ${_tag(w, s)}', (t) async {
        await _open(t, _Scene(messages: _seekerThread().take(2).toList(), enquiry: _enquiry()), w: w, s: s);
        await t.tap(find.text('Ask something'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        await _snap(t, 's_plus_${_tag(w, s)}');
        if (w == 360 && s == 1.0) {
          await t.drag(find.text('Is it free on my dates?').last, const Offset(0, -800));
          await t.pump(const Duration(milliseconds: 400));
          await _snap(t, 's_plus_end_360_10');
          expect(find.text('Request contact number'), findsOneWidget);
        }
        _done(t);
      });
      testWidgets('s_visit ${_tag(w, s)}', (t) async {
        await _open(t, _Scene(messages: _seekerThread().take(2).toList(), enquiry: _enquiry()), w: w, s: s);
        await t.tap(find.text('Ask something'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        await t.scrollUntilVisible(find.text('Schedule a visit'), 200, scrollable: find.byType(Scrollable).last);
        await t.tap(find.text('Schedule a visit'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 800));
        expect(find.text('When would you like to visit?'), findsOneWidget);
        final tomorrow = DateTime.now().add(const Duration(days: 2));
        await t.tap(find.text('${tomorrow.day}').last);
        await t.pump(const Duration(milliseconds: 200));
        await t.tap(find.text('11:00 AM'));
        await t.tap(find.text('4:00 PM'));
        await t.pump(const Duration(milliseconds: 300));
        await _snap(t, 's_visit_${_tag(w, s)}');
        expect(find.text('Send these times →'), findsOneWidget);
        _done(t);
      });
    }
    testWidgets('s_plus_host', (t) async {
      await _open(t, _Scene(messages: _visitReqThread().take(2).toList(), owner: true));
      await t.tap(find.text('Ask something'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await _snap(t, 's_plus_host_360_10');
      expect(find.text('About this listing'.toUpperCase()), findsNothing);
      _done(t);
    });
    testWidgets('s_counter', (t) async {
      await _open(t, _Scene(messages: _visitReqThread(), owner: true));
      await t.tap(find.text('Propose different time'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      await _snap(t, 's_counter_360_10');
      expect(find.text('Propose a different time'), findsWidgets);
      expect(find.text('Send this time →'), findsOneWidget);
      _done(t);
    });
    testWidgets('s_counter_err', (t) async {
      await _open(t, _Scene(messages: _visitReqThread(), owner: true));
      await t.tap(find.text('Propose different time'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      if (find.text('7:00 PM').evaluate().isNotEmpty) await t.tap(find.text('7:00 PM'), warnIfMissed: false);
      AppToast.error('Those times have passed — please pick a new time');
      // toastification inserts the item in a post-frame callback; its slide-in starts on the next frame.
      for (var i = 0; i < 3; i++) {
        await t.pump(const Duration(milliseconds: 600));
      }
      expect(find.text('Those times have passed — please pick a new time'), findsOneWidget);
      await _snap(t, 's_counter_err_360_10');
      await t.pump(const Duration(seconds: 6));
      _done(t);
    });
  });
}
