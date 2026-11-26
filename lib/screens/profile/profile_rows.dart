import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../features/dev/map_lab/map_lab_entry.dart';
import '../../config/shell_kind.dart';
import 'profile_rows_seeker.dart';
import 'profile_rows_stay_owner.dart';
import 'profile_rows_taxi_driver.dart';

abstract final class ProfileRows {
  static Widget forShell(ShellKind kind) {
    final rows = switch (kind) {
      ShellKind.seeker => const SeekerProfileRows(),
      ShellKind.stayOwner => const StayOwnerProfileRows(),
      ShellKind.taxiDriver => const TaxiDriverProfileRows(),
    };
    if (!kDebugMode) return rows;
    return Column(children: [rows, if (kDebugMode) MapLabEntry.row()]);
  }

  static bool showsJobsFeed(ShellKind kind) => kind == ShellKind.seeker;
}
