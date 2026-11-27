import 'package:flutter/material.dart';
import 'package:bakhli/design/tokens/design_colors.dart';

import '../shared/buddy_look.dart';
import 'models/expense_models.dart';

abstract final class ExpenseLook {
  static const Color roseTint = Color(0xFFFFF0F5);
  static const Color roseBorder = Color(0xFFFFD0DE);
  static const Color roseDash = Color(0xFFF5B8CB);
  static const Color roseFill = Color(0xFFFFF7FA);
  static const Color roseDot = Color(0xFFFF5287);
  static const Color fieldBorder = Color(0xFFE3E5EC);
  static const Color fieldOn = DesignColors.brandRoyal;
  static const Color fieldBad = Color(0xFFE5484D);
  static const Color okBorder = Color(0xFF66BB6A);
  static const Color okText = Color(0xFF17501B);
  static const Color leftText = Color(0xFFB85A12);
  static const Color offFill = Color(0xFFECEDF2);
  static const Color offEdge = Color(0xFFE3E5EC);
  static const Color greyDot = Color(0xFFC9CDD6);
  static const Color padBg = Color(0xFFD9DCE3);
  static const Color padKeyDark = Color(0xFFC3C7D0);
  static const Color placeholder = Color(0xFF9FA3AB);
  static const Color copy = Color(0xFF6B6B6B);
  static const Color label = Color(0xFF253840);
  static const Color thumbTop = Color(0xFFF4F5FF);
  static const Color thumbBottom = Color(0xFFE6E9FF);
  static const Color thumbEdge = DesignColors.brandLine;
  static const Color pillDisabled = Color(0xFFC9CDD6);
  static const Color amberBg = Color(0xFFFFF4E0);
  static const Color amberText = BuddyLook.amberText;
  static const Color dangerBg = Color(0xFFFDECEE);
  static const Color reasonBg = BuddyLook.reasonBg;

  static const String dir = BuddyArt.dir;
  static const String hotel = '${dir}hotel.png';
  static const String taxi = '${dir}taxi.png';
  static const String food = '${dir}pot_of_food.png';
  static const String fuel = '${dir}automobile.png';
  static const String tickets = '${dir}camera.png';
  static const String other = '${dir}backpack.png';
  static const String moneyBag = BuddyArt.moneyBag;
  static const String dividers = '${dir}card_index_dividers.png';
  static const String panda = BuddyArt.panda;
  static const String memo = BuddyArt.memo;
  static const String warning = BuddyArt.warning;

  static String categoryArt(String category) => switch (category) {
        ExpenseCategory.stay => hotel,
        ExpenseCategory.taxi => taxi,
        ExpenseCategory.food => food,
        ExpenseCategory.fuel => fuel,
        ExpenseCategory.tickets => tickets,
        _ => other,
      };

  static String linkArt(String kind) => kind == ExpenseLinkKind.taxi ? taxi : hotel;
}
