import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';

/// Single source of truth for the Inquiry pipeline's 5 confirmed states
/// (Submitted|Contacted|Confirmed|Cancelled|Rejected, admin-controlled only)
/// — status pill color/icon on My Inquiries rows, and the vertical stepper
/// on Inquiry Detail. Mirrors CoinTransactionModel.label()/icon()'s
/// switch-on-raw-backend-string convention rather than a separate enum, so
/// an unrecognized/future status degrades to a neutral pill instead of
/// crashing.
abstract final class InquiryStatus {
  static const submitted = 'Submitted';
  static const contacted = 'Contacted';
  static const confirmed = 'Confirmed';
  static const cancelled = 'Cancelled';
  static const rejected = 'Rejected';

  /// The 3-step happy path the vertical stepper walks through in order.
  /// Cancelled/Rejected are terminal branches off this path, not steps on it.
  static const List<String> steps = [submitted, contacted, confirmed];

  static bool isTerminalNegative(String status) => status == cancelled || status == rejected;

  static Color color(String status) => switch (status) {
        submitted => AppColors.primaryLight,
        contacted => AppColors.warning,
        confirmed => AppColors.success,
        cancelled => AppColors.error,
        rejected => AppColors.error,
        _ => AppColors.textLight,
      };

  static IconData icon(String status) => switch (status) {
        submitted => Iconsax.send_2,
        contacted => Iconsax.call_calling,
        confirmed => Iconsax.tick_circle,
        cancelled => Iconsax.close_circle,
        rejected => Iconsax.close_circle,
        _ => Iconsax.info_circle,
      };
}
