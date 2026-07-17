import 'package:flutter/material.dart';

/// A single wallet ledger row (GET /wallet/transactions). [amount] is signed
/// — positive for a credit, negative for a debit — matching the backend
/// contract directly rather than splitting into separate credit/debit fields.
class CoinTransactionModel {
  final String id;
  final int amount;
  final String reason;
  final String? referenceId;
  final int balanceAfter;
  final String? note;
  final DateTime createdAt;

  CoinTransactionModel({
    required this.id,
    required this.amount,
    required this.reason,
    this.referenceId,
    required this.balanceAfter,
    this.note,
    required this.createdAt,
  });

  factory CoinTransactionModel.fromJson(Map<String, dynamic> json) => CoinTransactionModel(
        id: json['id'] as String,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ?? '',
        referenceId: json['referenceId'] as String?,
        balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  bool get isCredit => amount > 0;

  /// Human-friendly label per backend reason constant, so the raw enum-ish
  /// string never leaks into the wallet ledger UI. Unknown/future reasons
  /// fall back to the raw string rather than crashing.
  static String label(String reason) => switch (reason) {
        'RECHARGE' => 'Coin Recharge',
        'COUPON_REDEEM' => 'Code Redeemed',
        'WELCOME_BONUS' => 'Welcome Bonus',
        'ROOM_GOLIVE' => 'Room Go Live',
        'PLOT_GOLIVE' => 'Plot Go Live',
        'ADMIN_CREDIT' => 'Admin Credit',
        'ADMIN_DEBIT' => 'Admin Adjustment',
        _ => reason,
      };

  static IconData icon(String reason) => switch (reason) {
        'RECHARGE' => Icons.add_circle_rounded,
        'COUPON_REDEEM' => Icons.redeem_rounded,
        'WELCOME_BONUS' => Icons.card_giftcard_rounded,
        'ROOM_GOLIVE' => Icons.bed_rounded,
        'PLOT_GOLIVE' => Icons.terrain_rounded,
        'ADMIN_CREDIT' => Icons.add_moderator_rounded,
        'ADMIN_DEBIT' => Icons.remove_moderator_rounded,
        _ => Icons.swap_horiz_rounded,
      };
}
