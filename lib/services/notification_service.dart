import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../config/app_colors.dart';
import '../config/app_constants.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../models/conversation_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

const String _chatChannelId = 'chat_messages';
const String _chatChannelName = 'Chat messages';
const int _maxStackedLines = 8;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final conversationId = message.data['conversation_id'] as String?;
  if (conversationId == null) return; // not a chat push — report/membership/broadcast unaffected

  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await _showChatNotification(
    conversationId,
    message.data['title'] as String? ?? 'New message',
    message.data['body'] as String? ?? '',
  );
}

// Android's action-button-tap callback — this design has no action buttons, so a plain tap
// shouldn't route here in practice (it should hit onDidReceiveNotificationResponse, or the
// cold-start getNotificationAppLaunchDetails() check, instead). Kept as a documented no-op
// for forward-compatibility; verify on-device which callback actually fires for a plain tap
// in each app state.
@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {}

// Draws a circular initial-letter avatar matching chats_list_screen.dart's existing
// per-conversation avatar exactly (solid navy AppColors.primary, white bold initial) — there
// are no real profile photos in this app and no per-user color palette, so this is always
// the same fixed navy circle, never derived from userId/name.
Future<Uint8List> _buildInitialAvatarBytes(String senderName) async {
  const size = 128.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

  canvas.drawCircle(
    const Offset(size / 2, size / 2),
    size / 2,
    Paint()..color = AppColors.primary,
  );

  final initial = senderName.trim().isNotEmpty ? senderName.trim()[0].toUpperCase() : '?';
  final textPainter = TextPainter(
    text: TextSpan(
      text: initial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: size * 0.45,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(
    canvas,
    Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
  );

  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

// Single source of truth for building/showing a chat notification — called from the killed-app
// background handler, the foreground listener, and nowhere else. Stacks consecutive messages
// from the same conversation into one notification (WhatsApp-like) via a small persisted
// per-conversation message cache, since flutter_local_notifications has no API to read back an
// already-shown notification's style contents.
//
// Uses MessagingStyleInformation (not InboxStyleInformation) specifically so Android renders
// the sender's avatar as the circular icon on the LEFT, matching WhatsApp exactly — InboxStyle
// has no concept of a per-message Person, so Android falls back to drawing the large icon on
// the right instead. MessagingStyle also lets the contact's name be the notification's own
// title (derived from the single Person below) instead of a separate bold name line repeated
// above the message body, which is the second WhatsApp-parity issue this fixes.
Future<void> _showChatNotification(String conversationId, String title, String body) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  ); // fresh instance — no singleton sharing across isolates (the background handler runs in a separate one)

  final avatarBytes = await _buildInitialAvatarBytes(title);
  final sender = Person(
    key: conversationId,
    name: title,
    icon: ByteArrayAndroidIcon(avatarBytes),
  );

  final stored = StorageService.getChatStackedLines(conversationId)
    ..add({'text': body, 'timestamp': DateTime.now().millisecondsSinceEpoch});
  final stacked = stored.length > _maxStackedLines
      ? stored.sublist(stored.length - _maxStackedLines)
      : stored;
  await StorageService.saveChatStackedLines(conversationId, stacked);

  final messages = stacked
      .map((m) => Message(
            m['text'] as String,
            DateTime.fromMillisecondsSinceEpoch(m['timestamp'] as int),
            sender,
          ))
      .toList();

  await plugin.show(
    id: conversationId.hashCode,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _chatChannelId,
        _chatChannelName,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: MessagingStyleInformation(
          const Person(name: 'You'),
          groupConversation: false,
          messages: messages,
        ),
        largeIcon: ByteArrayAndroidBitmap(avatarBytes),
        autoCancel: true,
      ),
    ),
    payload: conversationId,
  );
}

class NotificationService extends GetxService {
  static NotificationService get to => Get.find();

  StreamSubscription? _messageOpenedSub;
  StreamSubscription? _tokenRefreshSub;
  StreamSubscription? _foregroundMessageSub;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Explore and Chats are resident tabs (see AppTabs); My Rooms/My Plots are
  // pushed routes, handled separately below.

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initFirebase();
  }

  Future<void> _initFirebase() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Notification tap handlers — always active regardless of login state
    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);

    // Chat pushes are data-only (see ChatFcmService.cs), so FCM routes them to onMessage
    // while the app is foregrounded, never auto-displaying anything — build the same
    // stacked/avatar notification here too, unless the user is already looking at that
    // exact conversation.
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) async {
      final conversationId = message.data['conversation_id'] as String?;
      if (conversationId == null) return;
      if (Get.currentRoute == AppRoutes.chatConversation &&
          (Get.arguments as Map?)?['conversationId'] == conversationId) {
        return;
      }
      await _showChatNotification(
        conversationId,
        message.data['title'] as String? ?? 'New message',
        message.data['body'] as String? ?? '',
      );
    });

    await _initLocalNotifications();

    // Token refresh listener — only registers if logged in
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (StorageService.isLoggedIn) await _registerToken(token);
      // Defensive re-subscribe — cheap no-op if already subscribed, guards against
      // any FCM-side token/topic association edge cases after a token refresh.
      final topic = StorageService.getSubscribedDistrictTopic();
      if (topic != null) {
        try {
          await FirebaseMessaging.instance.subscribeToTopic(topic);
        } catch (_) {}
      }
    });

    // Returning user: permission already granted — silently register token
    // Permission is NOT requested here. It is requested only after login (registerTokenAfterLogin)
    // so the user has context before seeing the system dialog.
    if (StorageService.isLoggedIn) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await _registerToken(token);
      }
    }
  }

  Future<void> _initLocalNotifications() async {
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _chatChannelId,
          _chatChannelName,
          description: 'Notifications for new chat messages',
          importance: Importance.high,
        ));

    // Cold start: app was killed and launched by tapping our own local notification — a
    // DIFFERENT signal from FirebaseMessaging.getInitialMessage() above, which only detects
    // taps on Play-Services-auto-rendered notifications (chat is no longer auto-rendered
    // at all, since chat pushes are data-only).
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true && payload != null) {
      _navigateToChatConversation(payload);
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (!StorageService.isLoggedIn) return;
    final conversationId = response.payload;
    if (conversationId != null) _navigateToChatConversation(conversationId);
  }

  // Screens pushed ON TOP of main screen — main is underneath in the stack
  static const _routesOnTopOfMain = {
    AppRoutes.listingDetail,
    AppRoutes.plotDetail,
    AppRoutes.addListing,
    AppRoutes.addPlot,
    AppRoutes.coinPacks,
    AppRoutes.redeemCode,
    AppRoutes.walletLedger,
    AppRoutes.listingReports,
    AppRoutes.reportDetail,
    AppRoutes.myFiledReports,
  };

  void _handleNotificationTap(RemoteMessage message) {
    if (!StorageService.isLoggedIn) return;

    // Chat pushes are data-only now (see ChatFcmService.cs) and are never auto-rendered
    // by Play Services, so this branch is normally dead for real chat pushes — the plugin's
    // own onMessage/onBackgroundMessage + our local-notification tap handling own that path
    // instead. Kept (not deleted) because it's not fully unreachable: a manually-composed
    // Firebase Console test push always includes a Notification block, and a tester could
    // still add conversation_id as a custom data key for QA — that combined-payload message
    // WOULD flow through onMessageOpenedApp with data populated, hitting this exact branch.
    final isChatMessage = message.data['conversation_id'] != null;
    final notificationType = message.data['notification_type'];
    final reportListingId = message.data['listing_id'];
    final reportListingType = message.data['listing_type'];
    // Only report pushes carry listing_id — room/plot membership pushes never did,
    // so this can't collide with the notificationType 'room'/'plot' branch below.
    final isReportMessage = reportListingId != null;
    final currentRoute = Get.currentRoute;

    // Broadcast still lands on the resident Explore tab; Room/Plot membership
    // notifications now push the My Rooms/My Plots route (no longer tabs).
    void goToDestination() {
      if (isChatMessage) {
        _navigateToChatConversation(message.data['conversation_id'] as String);
      } else if (isReportMessage) {
        Get.toNamed(AppRoutes.listingReports, arguments: {
          'listingId': reportListingId,
          'listingType': reportListingType ?? 'Room',
          'title': message.data['listing_title'] ?? 'your listing',
        });
      } else if (notificationType == 'broadcast') {
        Get.find<AuthController>().tabIndex.value = AppTabs.rooms;
      } else {
        Get.toNamed(notificationType == 'plot' ? AppRoutes.myPlots : AppRoutes.myListings);
      }
    }

    if (currentRoute == AppRoutes.main) {
      // Already on main screen — no rebuild needed for the tab case; the
      // pushed-route case just navigates on top.
      goToDestination();
    } else if (_routesOnTopOfMain.contains(currentRoute)) {
      // Detail/add screens are on top of main — main screen is alive underneath
      // Pop back to main WITHOUT recreating it (IndexedStack state preserved)
      Get.until((route) => route.settings.name == AppRoutes.main);
      goToDestination();
    } else {
      // Main screen is NOT in stack: terminated app, login, splash, onboarding
      // Navigate fresh — double postFrameCallback waits for MainScreen.initState()
      Get.offAllNamed(AppRoutes.main);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.isRegistered<AuthController>()) {
            goToDestination();
          }
        });
      });
    }
  }

  // Shared route-state juggling for both trigger sources — FCM's own tap tracking
  // (_handleNotificationTap, for the narrow still-possible case documented above) and
  // flutter_local_notifications' own tap tracking (_onLocalNotificationTap / cold-start
  // getNotificationAppLaunchDetails), which is what actually fires for real chat pushes now.
  void _navigateToChatConversation(String conversationId) {
    final currentRoute = Get.currentRoute;
    if (currentRoute == AppRoutes.main) {
      _openChatConversation(conversationId);
    } else if (_routesOnTopOfMain.contains(currentRoute)) {
      Get.until((route) => route.settings.name == AppRoutes.main);
      _openChatConversation(conversationId);
    } else {
      Get.offAllNamed(AppRoutes.main);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.isRegistered<AuthController>()) _openChatConversation(conversationId);
        });
      });
    }
  }

  // Chat pushes only carry `conversation_id` — ChatConversationScreen needs more
  // (listingType, otherPartyId, title, isOwner, status) to render, which already lives
  // in ChatController.conversations (populated by loadConversations(), same fields
  // chats_list_screen.dart's _openConversation already maps into nav arguments). Land
  // on the Chats tab immediately as a safe fallback view, then open the specific
  // conversation once its data is available.
  Future<void> _openChatConversation(String conversationId) async {
    Get.find<AuthController>().tabIndex.value = AppTabs.chats;

    if (!Get.isRegistered<ChatController>()) return;
    final chatCtrl = Get.find<ChatController>();

    ConversationModel? find() =>
        chatCtrl.conversations.firstWhereOrNull((c) => c.id == conversationId);

    var conv = find();
    if (conv == null) {
      // MainScreen.initState() already kicks off its own loadConversations() before this
      // ever runs (and ChatsListScreen's own call no-ops against the same in-flight guard) —
      // calling loadConversations() again here would no-op instantly too. Wait out the
      // existing load instead of firing a redundant one.
      if (chatCtrl.conversationsLoading.value) {
        final done = Completer<void>();
        late final Worker worker;
        worker = ever<bool>(chatCtrl.conversationsLoading, (loading) {
          if (!loading && !done.isCompleted) done.complete();
        });
        await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
        worker.dispose();
      } else {
        await chatCtrl.loadConversations();
      }
      conv = find();
    }

    if (conv == null) return; // not on page 1 / not found — stays on Chats list, not a dead end

    // Stacked-notification cleanup lives in ChatConversationScreen.initState() instead of
    // here — that runs regardless of HOW the screen was reached (this notification-tap path,
    // or a plain manual tap from chats_list_screen.dart's own conversation list), so it's the
    // one place that reliably fires every time the conversation is actually opened.

    // Already looking at this exact conversation — nothing to do (mirrors the identical
    // check the foreground-message listener does above for the in-app notification banner).
    if (Get.currentRoute == AppRoutes.chatConversation &&
        (Get.arguments as Map?)?['conversationId'] == conv.id) {
      return;
    }
    // A DIFFERENT conversation screen is already open — GetX's default preventDuplicates
    // compares by route name only (every conversation uses the same route name), so pushing
    // on top of it would otherwise be silently dropped. Replace it instead of stacking an
    // unbounded number of chat screens from repeated notification taps.
    if (Get.currentRoute == AppRoutes.chatConversation) {
      Get.back();
    }

    Get.toNamed(AppRoutes.chatConversation, arguments: {
      'conversationId': conv.id,
      'listingType': conv.listingType,
      'listingId': conv.listingId,
      'roomTypeId': conv.roomTypeId,
      'plotTypeId': conv.plotTypeId,
      'otherPartyId': conv.otherPartyId,
      'otherPartyName': conv.otherPartyName,
      'listingTitle': conv.listingTitle,
      'area': conv.area,
      'isOwner': conv.isOwner,
      'status': conv.status,
    });
  }

  /// Clears a conversation's stacked-notification state (recent lines cache + the tray
  /// notification itself, if still showing). Call this whenever the conversation screen is
  /// actually opened — regardless of navigation source — so a message the user has already
  /// read in-app never resurfaces stacked under a future notification for the same thread.
  void dismissChatNotification(String conversationId) {
    StorageService.clearChatStackedLines(conversationId);
    unawaited(_localNotifications.cancel(id: conversationId.hashCode));
  }

  Future<void> _registerToken(String token) async {
    final stored = StorageService.getFcmToken();
    if (stored == token) return;

    try {
      await ApiService.post(AppConstants.registerTokenPath, {'token': token});
      await StorageService.saveFcmToken(token);
    } catch (e) {
      debugPrint('NotificationService: token registration failed: $e');
    }
  }

  Future<void> registerTokenAfterLogin() async {
    // Delay so location permission dialog (shown by LocationController on main screen open)
    // completes first — prevents two system dialogs overlapping on Android 13+.
    await Future.delayed(const Duration(seconds: 3));

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(token);
  }

  Future<void> clearToken() async {
    StorageService.clearFcmToken();
    try {
      await ApiService.delete(AppConstants.registerTokenPath);
    } catch (_) {}
  }

  /// Returns true if user should be prompted to re-enable notifications:
  /// - Previously had notifications (stored token exists)
  /// - Current permission is denied
  /// - Has not dismissed the prompt in the last 24 hours
  Future<bool> shouldShowPermissionPrompt() async {
    if (StorageService.getFcmToken() == null) return false;

    final lastDismissed = StorageService.getNotifPromptDismissedAt();
    if (lastDismissed != null) {
      final hoursSince = DateTime.now().difference(lastDismissed).inHours;
      if (hoursSince < 24) return false;
    }

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.denied;
  }

  void onPermissionPromptDismissed() =>
      StorageService.saveNotifPromptDismissedAt();

  /// Subscribes to the FCM topic for [districtId] (`district_<id>`), unsubscribing
  /// from the previously-subscribed district topic first if it changed.
  /// Pass null to unsubscribe without subscribing to a new one.
  Future<void> updateDistrictTopic(String? districtId) async {
    final previous = StorageService.getSubscribedDistrictTopic();
    final next = districtId == null
        ? null
        : '${AppConstants.districtTopicPrefix}$districtId';
    if (previous == next) return;

    if (previous != null) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(previous);
      } catch (e) {
        debugPrint('NotificationService: unsubscribe from $previous failed: $e');
      }
    }

    if (next != null) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(next);
        await StorageService.saveSubscribedDistrictTopic(next);
        return;
      } catch (e) {
        debugPrint('NotificationService: subscribe to $next failed: $e');
        return; // leave stored topic as-is — retried on next district-change event
      }
    }

    StorageService.clearSubscribedDistrictTopic();
  }

  /// Unsubscribes from the currently-subscribed district topic, if any. Call on logout.
  Future<void> clearDistrictTopic() async {
    final topic = StorageService.getSubscribedDistrictTopic();
    if (topic == null) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (_) {}
    StorageService.clearSubscribedDistrictTopic();
  }

  @override
  void onClose() {
    _messageOpenedSub?.cancel();
    _tokenRefreshSub?.cancel();
    _foregroundMessageSub?.cancel();
    super.onClose();
  }
}
