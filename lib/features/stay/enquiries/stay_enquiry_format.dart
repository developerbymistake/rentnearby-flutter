import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/contact_launcher.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_constants.dart';
import '../../trip/trip_strings.dart';
import '../stay_strings_fin_c1.dart';
import 'stay_enquiry_strings.dart';

class StayEnquiryFormat {
  static final RegExp phonePattern = RegExp(r'^[6-9]\d{9}$');

  static final List<TextInputFormatter> upiFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9.@_-]')),
    LengthLimitingTextInputFormatter(TripConstants.upiMax),
  ];

  static final List<TextInputFormatter> phoneFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  static String accountPhone() =>
      Get.isRegistered<AuthController>() ? ContactLauncher.tenDigits(Get.find<AuthController>().user.value?.phoneNumber ?? '') : '';

  static String? upiError(String value) =>
      value.isEmpty || TripConstants.upiPattern.hasMatch(value) ? null : TripStrings.upiInvalid;

  static String? phoneError(String value) =>
      value.isEmpty || phonePattern.hasMatch(value) ? null : StayEnquiryStrings.phoneInvalid;

  static String guest(TripEnquiryModel e) {
    final n = e.traveller.name;
    return n == null || n.trim().isEmpty ? StayEnquiryStrings.guestFallback : n.trim();
  }

  static int? tripInDays(TripEnquiryModel e) {
    final start = e.context.days.isNotEmpty ? e.context.days.first.date : null;
    final from = start ?? e.checkIn;
    if (from == null) return null;
    final now = DateTime.now();
    final d = DateTime(from.year, from.month, from.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    return d < 0 ? 0 : d;
  }

  static String tripInLabel(int days) => days == 0 ? TripStrings.tonight : TripStrings.tripIn(days);

  static String summary(TripEnquiryModel e) {
    final c = e.context;
    final inDays = tripInDays(e);
    return [
      if (c.city.isNotEmpty) StayFinStrings.cityTrip(c.city),
      if (e.datesLabel.isNotEmpty) e.datesLabel,
      c.peopleLabel,
      c.roomsLabel,
      if (inDays != null) tripInLabel(inDays),
    ].whereType<String>().join(' · ');
  }

  static List<String> chips(TripEnquiryModel e) => [
        ...e.context.needs.map(TripNeeds.label),
        ...e.context.days.expand((d) => d.spots),
      ];

  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
