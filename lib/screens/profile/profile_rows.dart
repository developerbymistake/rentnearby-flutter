import 'package:flutter/widgets.dart';

import '../../config/shell_kind.dart';
import 'profile_rows_seeker.dart';
import 'profile_rows_stay_owner.dart';
import 'profile_rows_taxi_driver.dart';

abstract final class ProfileRows {
  static Widget forShell(ShellKind kind) => switch (kind) {
        ShellKind.seeker => const SeekerProfileRows(),
        ShellKind.stayOwner => const StayOwnerProfileRows(),
        ShellKind.taxiDriver => const TaxiDriverProfileRows(),
      };

  static List<Widget> activityRows(ShellKind kind) => switch (kind) {
        ShellKind.stayOwner => StayOwnerProfileRows.activityRows(),
        _ => const [],
      };

  static bool showsJobsFeed(ShellKind kind) => kind == ShellKind.seeker;
}
