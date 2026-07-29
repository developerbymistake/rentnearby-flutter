import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';

/// Single source of truth for the Enquiry pipeline's 3 states
/// (Submitted|Contacted|Closed) — status pill color/icon on My Enquiries
/// rows, and the vertical stepper on Enquiry Detail. Mirrors
/// CreditTransactionModel.label()/icon()'s switch-on-raw-backend-string
/// convention rather than a separate enum, so an unrecognized/future status
/// degrades to a neutral pill instead of crashing.
abstract final class EnquiryStatus {
  static const submitted = 'Submitted';
  static const contacted = 'Contacted';
  static const closed = 'Closed';

  /// The happy path the vertical stepper walks through in order. Closed is
  /// the terminal step on this path (reachable only from Contacted).
  static const List<String> steps = [submitted, contacted, closed];

  static Color color(String status) => switch (status) {
        submitted => AppColors.primaryLight,
        contacted => AppColors.warning,
        closed => AppColors.success,
        _ => AppColors.textLight,
      };

  static IconData icon(String status) => switch (status) {
        submitted => Iconsax.send_2,
        contacted => Iconsax.call_calling,
        closed => Iconsax.tick_circle,
        _ => Iconsax.info_circle,
      };
}
