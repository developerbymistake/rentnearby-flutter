import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../features/stay/guest/stay_guest_controller.dart';
import '../features/taxi/guest/taxi_browse_repository.dart';
import '../models/conversation_model.dart';
import '../utils/app_toast.dart';
import '../utils/contact_launcher.dart';
import '../utils/dio_error_mapper.dart';

enum ListingKind { stay, taxi }

enum ContactOutcome { dialed, chatOpened, openedDetail, ignored, failed, whatsAppOpened }

class ListingContact {
  const ListingContact({required this.ownerId, this.phone, this.whatsApp});
  final String ownerId;
  final String? phone;
  final String? whatsApp;
}

class ListingContactDeps {
  const ListingContactDeps({
    required this.fetchContact,
    required this.currentUserId,
    required this.dial,
    required this.createConversation,
    required this.openRoute,
    required this.info,
    this.openWhatsApp = ContactLauncher.whatsApp,
  });

  final Future<ListingContact?> Function(ListingKind kind, String id) fetchContact;
  final String? Function() currentUserId;
  final Future<void> Function(String phone) dial;
  final Future<ConversationModel?> Function(String listingType, String id) createConversation;
  final void Function(String route, Object? arguments) openRoute;
  final void Function(String message) info;
  final Future<void> Function(String phone) openWhatsApp;
}

class ListingContactActions {
  static const String phoneHiddenMessage = 'Phone not shared. See the details.';

  @visibleForTesting
  static ListingContactDeps? debugDeps;

  static final RxSet<String> busy = <String>{}.obs;

  static String keyOf(ListingKind kind, String id) => '${kind.name}:$id';

  static const String actionCall = 'call';
  static const String actionWhatsApp = 'whatsapp';
  static const String actionChat = 'chat';

  static bool isBusy(ListingKind kind, String id, {String? action}) =>
      busy.contains(action == null ? keyOf(kind, id) : '${keyOf(kind, id)}|$action');

  static bool supportsChat(ListingKind kind) => kind == ListingKind.stay;

  static String listingType(ListingKind kind) => kind == ListingKind.stay ? 'Stay' : 'Taxi';

  static String detailRoute(ListingKind kind) => kind == ListingKind.stay ? AppRoutes.stayDetail : AppRoutes.taxiDetail;

  static ListingContactDeps get _deps => debugDeps ?? _defaultDeps;

  static Future<ContactOutcome> call(
    BuildContext context, {
    required ListingKind kind,
    required String id,
    Map<String, dynamic>? detailArguments,
  }) =>
      _guard(kind, id, actionCall, () async {
        final deps = _deps;
        final contact = await deps.fetchContact(kind, id);
        if (!context.mounted) return ContactOutcome.ignored;
        if (contact == null) {
          _openDetail(deps, kind, id, detailArguments);
          return ContactOutcome.failed;
        }
        final me = deps.currentUserId();
        final isOwner = me != null && me == contact.ownerId;
        final raw = contact.phone;
        final phone = isOwner || raw == null || ContactLauncher.tenDigits(raw).isEmpty ? null : raw;
        if (phone == null) {
          if (!isOwner) deps.info(phoneHiddenMessage);
          _openDetail(deps, kind, id, detailArguments);
          return ContactOutcome.openedDetail;
        }
        await deps.dial(phone);
        return ContactOutcome.dialed;
      });

  static Future<ContactOutcome> whatsApp(
    BuildContext context, {
    required ListingKind kind,
    required String id,
    Map<String, dynamic>? detailArguments,
  }) =>
      _guard(kind, id, actionWhatsApp, () async {
        final deps = _deps;
        final contact = await deps.fetchContact(kind, id);
        if (!context.mounted) return ContactOutcome.ignored;
        if (contact == null) {
          _openDetail(deps, kind, id, detailArguments);
          return ContactOutcome.failed;
        }
        final me = deps.currentUserId();
        final isOwner = me != null && me == contact.ownerId;
        final raw = contact.whatsApp ?? contact.phone;
        final phone = isOwner || raw == null || ContactLauncher.tenDigits(raw).isEmpty ? null : raw;
        if (phone == null) {
          if (!isOwner) deps.info(phoneHiddenMessage);
          _openDetail(deps, kind, id, detailArguments);
          return ContactOutcome.openedDetail;
        }
        await deps.openWhatsApp(phone);
        return ContactOutcome.whatsAppOpened;
      });

  static Future<ContactOutcome> chat(
    BuildContext context, {
    required ListingKind kind,
    required String id,
    Map<String, dynamic>? detailArguments,
  }) =>
      _guard(kind, id, actionChat, () async {
        final deps = _deps;
        if (!supportsChat(kind)) {
          _openDetail(deps, kind, id, detailArguments);
          return ContactOutcome.openedDetail;
        }
        final conv = await deps.createConversation(listingType(kind), id);
        if (!context.mounted) return ContactOutcome.ignored;
        if (conv == null) return ContactOutcome.failed;
        deps.openRoute(AppRoutes.chatConversation, chatArguments(conv));
        return ContactOutcome.chatOpened;
      });

  static Map<String, dynamic> chatArguments(ConversationModel conv) => {
        'conversationId': conv.id,
        'listingType': conv.listingType,
        'listingId': conv.listingId,
        'stayTypeId': conv.stayTypeId,
        'otherPartyId': conv.otherPartyId,
        'otherPartyName': conv.otherPartyName,
        'listingTitle': conv.listingTitle,
        'isOwner': conv.isOwner,
        'status': conv.status,
        'isBlockedByMe': conv.isBlockedByMe,
      };

  static Future<ContactOutcome> _guard(ListingKind kind, String id, String action, Future<ContactOutcome> Function() run) async {
    final key = keyOf(kind, id);
    final actionKey = '$key|$action';
    if (busy.contains(key)) return ContactOutcome.ignored;
    busy.addAll([key, actionKey]);
    try {
      return await run();
    } finally {
      busy.removeAll([key, actionKey]);
    }
  }

  static void _openDetail(ListingContactDeps deps, ListingKind kind, String id, Map<String, dynamic>? args) =>
      deps.openRoute(detailRoute(kind), {...?args, 'id': id});

  static final ListingContactDeps _defaultDeps = ListingContactDeps(
    fetchContact: _fetchContact,
    currentUserId: () => Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null,
    dial: ContactLauncher.call,
    createConversation: (type, id) async =>
        Get.isRegistered<ChatController>() ? Get.find<ChatController>().createOrGetConversation(type, id) : null,
    openRoute: (route, args) => Get.toNamed(route, arguments: args),
    info: AppToast.info,
  );

  static Future<ListingContact?> _fetchContact(ListingKind kind, String id) async {
    if (kind == ListingKind.stay) {
      final s = await StayGuestController.to.getById(id);
      return s == null ? null : ListingContact(ownerId: s.userId, phone: s.ownerPhone);
    }
    try {
      final t = await const TaxiBrowseRepository().getById(id);
      return ListingContact(
        ownerId: t.userId,
        phone: t.hasContact ? t.contactPhone : null,
        whatsApp: t.hasContact ? (t.whatsAppNumber ?? t.contactPhone) : null,
      );
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      if (status != 401 && status != 404) AppToast.error(DioErrorMapper.toMessage(e, 'Could not load the taxi.'));
      return null;
    }
  }
}
