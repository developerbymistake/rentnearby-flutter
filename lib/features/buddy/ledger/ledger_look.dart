import 'package:flutter/material.dart';
import 'package:bakhli/design/tokens/design_colors.dart';

import '../expenses/models/expense_models.dart';
import '../shared/buddy_look.dart';

abstract final class LedgerLook {
  static const Color getsBack = Color(0xFF17501B);
  static const Color owes = Color(0xFFB85A12);
  static const Color square = Color(0xFF767676);
  static const Color line = Color(0xFFEEF0F4);
  static const Color barTrack = Color(0xFFECEDF2);
  static const Color expenseTint = Color(0xFFFFF0F5);
  static const Color heroSub = Color(0xFF6B6B6B);

  static const List<Color> barOrange = [Color(0xFFFFC371), Color(0xFFFF8A3D)];
  static const List<Color> barGreen = [Color(0xFF66BB6A), Color(0xFF2E7D32)];
  static const List<Color> barRose = [Color(0xFFFE95B6), Color(0xFFFF5287)];
  static const List<Color> barTeal = [Color(0xFF54D3C2), Color(0xFF1FA396)];
  static const List<Color> barIndigo = [DesignColors.brandNavy, DesignColors.brandRoyal];
  static const List<Color> barAmber = [Color(0xFFFFD27A), Color(0xFFE0A030)];

  static List<Color> barOf(String category) => switch (category) {
        ExpenseCategory.taxi => barOrange,
        ExpenseCategory.stay => barGreen,
        ExpenseCategory.food => barRose,
        ExpenseCategory.tickets => barIndigo,
        ExpenseCategory.fuel => barAmber,
        _ => barTeal,
      };

  static const String alarm = BuddyArt.alarm;
  static const String warning = BuddyArt.warning;
  static const String moneyBag = BuddyArt.moneyBag;
  static const String locked = BuddyArt.locked;
  static const String luggage = BuddyArt.luggage;
  static const String flag = '${BuddyArt.dir}chequered_flag.png';
  static const String star = '${BuddyArt.dir}star.png';
}
