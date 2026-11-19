import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../features/stay/guest/stay_guest_controller.dart';
import '../features/taxi/guest/taxi_browse_repository.dart';
import '../utils/app_toast.dart';
import '../utils/contact_launcher.dart';
import '../utils/contact_message.dart';
import '../utils/dio_error_mapper.dart';

enum ListingKind { stay, taxi }

enum ContactOutcome { dialed, openedDetail, ignored, failed, whatsAppOpened }

class ListingContact {
  const ListingContact({required this.ownerId, this.phone, this.whatsApp, this.title});
  final String ownerId;
  final String? phone;
  final String? whatsApp;
  final String? title;
}

ContactCustomer? _noCustomer() => null;

class ListingContactDeps {
  const ListingContactDeps({
    required this.fetchContact,
    required this.currentUserId,
    required this.dial,
    required this.openRoute,
    required this.info,
    this.openWhatsApp = ContactLauncher.whatsApp,
    this.customer = _noCustomer,
  });

  final Future<ListingContact?> Function(ListingKind kind, String id) fetchContact;
  final String? Function() currentUserId;
  final Future<void> Function(String phone) dial;
  final void Function(String route, Object? arguments) openRoute;
  final void Function(String message) info;
  final Future<void> Function(String phone, {String? message}) openWhatsApp;
  final ContactCustomer? Function() customer;
}

class ListingContactActions {
  static const String phoneHiddenMessage = 'Phone not shared. See the details.';

  @visibleForTesting
  static ListingContactDeps? debugDeps;

  static final RxSet<String> busy = <String>{}.obs;

  static String keyOf(ListingKind kind, String id) => '${kind.name}:$id';

  static const String actionCall = 'call';
  static const String actionWhatsApp = 'whatsapp';

  static bool isBusy(ListingKind kind, String id, {String? action}) =>
      busy.contains(action == null ? keyOf(kind, id) : '${keyOf(kind, id)}|$action');

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
        await deps.openWhatsApp(phone, message: messageFor(kind, contact.title, deps.customer()));
        return ContactOutcome.whatsAppOpened;
      });

  static ContactCustomer? customer() {
    final u = Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value : null;
    return u == null ? null : (name: u.name, phone: u.phoneNumber);
  }

  static String messageFor(ListingKind kind, String? title, ContactCustomer? c) =>
      kind == ListingKind.stay ? ContactMessage.stay(stayName: title, customer: c) : ContactMessage.taxi(vehicle: title, customer: c);

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
    openRoute: (route, args) => Get.toNamed(route, arguments: args),
    info: AppToast.info,
    customer: customer,
  );

  static Future<ListingContact?> _fetchContact(ListingKind kind, String id) async {
    if (kind == ListingKind.stay) {
      final s = await StayGuestController.to.getById(id);
      return s == null ? null : ListingContact(ownerId: s.userId, phone: s.ownerPhone, title: s.name);
    }
    try {
      final t = await const TaxiBrowseRepository().getById(id);
      return ListingContact(
        ownerId: t.userId,
        phone: t.hasContact ? t.contactPhone : null,
        whatsApp: t.hasContact ? (t.whatsAppNumber ?? t.contactPhone) : null,
        title: t.vehicleTypeName,
      );
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      if (status != 401 && status != 404) AppToast.error(DioErrorMapper.toMessage(e, 'Could not load the taxi.'));
      return null;
    }
  }
}
