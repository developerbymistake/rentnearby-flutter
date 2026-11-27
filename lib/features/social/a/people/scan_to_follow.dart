import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../utils/app_toast.dart';
import '../../../buddy/buddies/data/buddies_api.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/buddy_navigation.dart';
import '../../../buddy/scan/scan_outcome.dart';
import '../../../buddy/scan/scan_rules.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../social_strings_a.dart';
import 'username_entry_sheet.dart';

enum ScanLookup { opened, own, notFound, tryLater, offline, failed }

class ScanToFollow {
  const ScanToFollow({
    this.api = const BuddiesApi(),
    this.scan = BuddyNavigation.openScan,
    this.typeUsername = UsernameEntrySheet.show,
    this.openTraveller = SocialNav.openTraveller,
  });

  final BuddiesApi api;
  final Future<ScanOutcome?> Function() scan;
  final Future<String?> Function(BuildContext context) typeUsername;
  final void Function(String userId) openTraveller;

  static AuthController? get _auth => Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;

  Future<void> start(BuildContext context) async {
    final outcome = await scan();
    final String? username;
    final String source;
    switch (outcome) {
      case null:
        return;
      case ScanFound(username: final u):
        username = u;
        source = BuddySource.qr;
      case ScanTypeInstead():
        if (!context.mounted) return;
        username = await typeUsername(context);
        source = BuddySource.search;
    }
    if (username == null) return;
    final result = await lookup(username, source: source);
    final line = messageOf(result);
    if (line == null) return;
    if (result == ScanLookup.notFound) {
      AppToast.info(line);
    } else {
      AppToast.warning(line);
    }
  }

  Future<ScanLookup> lookup(String raw, {required String source}) async {
    final username = ScanRules.normalize(raw);
    if (!ScanRules.isBakhliUsername(username)) return ScanLookup.notFound;
    final me = _auth?.user.value;
    if (me != null && username == me.username) return _own(me.id);
    final r = await api.find(username, source: source);
    switch (r) {
      case BuddyOk(:final value):
        final person = value.person;
        if (!value.found || person == null || person.userId.isEmpty) return ScanLookup.notFound;
        if (me != null && person.userId == me.id) return _own(me.id);
        openTraveller(person.userId);
        return ScanLookup.opened;
      case BuddyRefused(:final rateLimited) when rateLimited:
        return ScanLookup.tryLater;
      case BuddyRefused():
        return ScanLookup.failed;
      case BuddyOffline():
        return ScanLookup.offline;
      case BuddyFailed():
        return ScanLookup.failed;
    }
  }

  ScanLookup _own(String myId) {
    openTraveller(myId);
    return ScanLookup.own;
  }

  static String? messageOf(ScanLookup r) => switch (r) {
        ScanLookup.opened || ScanLookup.own => null,
        ScanLookup.notFound => SocialStringsA.noTravellerFound,
        ScanLookup.tryLater => SocialStringsA.scanTryLater,
        ScanLookup.offline => SocialStrings.offline,
        ScanLookup.failed => SocialStrings.failed,
      };
}
