import 'package:flutter/material.dart';
import 'design_colors.dart';

abstract final class HeaderGradients {
  static const Alignment _begin = Alignment.topLeft;
  static const Alignment _end = Alignment.bottomRight;

  static const LinearGradient home = LinearGradient(
      colors: [DesignColors.primary, DesignColors.primaryLight], begin: _begin, end: _end);
  static const LinearGradient stays = LinearGradient(
      colors: [DesignColors.hotelEnd, DesignColors.primaryLight], begin: _begin, end: _end);
  static const LinearGradient taxi = LinearGradient(
      colors: [DesignColors.sunriseDeep, DesignColors.sunriseDeepEnd], begin: _begin, end: _end);
  static const LinearGradient trips = LinearGradient(
      colors: [DesignColors.duskDeepStart, DesignColors.dinnerEnd], begin: _begin, end: _end);
  static const LinearGradient jobs = LinearGradient(
      colors: [DesignColors.warnDeep, DesignColors.amber], begin: _begin, end: _end);
  static const LinearGradient profile = LinearGradient(
      colors: [DesignColors.primary, DesignColors.statusOwn], begin: _begin, end: _end);
}
