import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/browse_item.dart';
import '../../widgets/role_option_card.dart';
import 'models/taxi_owner_model.dart';

class TaxiColors {
  static const Color accent = Color(0xFF0D9488);
  static const Color accentDark = Color(0xFF0F766E);
  static const Color surface = Color(0xFFF0FDFA);
  static const LinearGradient gradient = RoleVisuals.taxiGradient;
}

class TaxiStatus {
  static const String draft = 'Draft';
  static const String pendingReview = 'PendingReview';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';
}

class TaxiOption {
  final String value;
  final String label;
  const TaxiOption(this.value, this.label);
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

// Values mirror RentNearBy.Core/Models/TaxiOptions.cs.
class TaxiOptionSets {
  static const seats = [4, 6, 7, 12];
  static const tripTypes = [TaxiOption('OneWay', 'One way'), TaxiOption('RoundTrip', 'Round trip')];
  static const categories = [
    TaxiOption('Hatchback', 'Hatchback'),
    TaxiOption('Sedan', 'Sedan'),
    TaxiOption('MUV', 'MUV'),
    TaxiOption('SUV', 'SUV'),
    TaxiOption('TempoTraveller', 'Tempo Traveller'),
    TaxiOption('Bus', 'Bus'),
  ];
  static const int maxRoutes = 10;
  static const int minFare = 100;
  static const int maxFare = 9900000;
  static const int phoneLength = 10;
  static const double minEndpointDistanceMeters = 500;

  static const safetyLine = 'Bakhli takes no booking or payment. Confirm the fare and the vehicle before you travel.';
  static const plateCheckedLabel = 'Plate photo checked';
  static const plateHelp = 'Enter a valid number plate, e.g. UK 07 TA 1234';

  static final List<TextInputFormatter> plateInputFormatters = [
    const _UpperCaseFormatter(),
    FilteringTextInputFormatter.allow(RegExp('[A-Z0-9 ]')),
    LengthLimitingTextInputFormatter(16),
  ];

  static final List<TextInputFormatter> phoneInputFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(phoneLength),
  ];

  static final _plateStandard = RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{4}$');
  static final _plateBh = RegExp(r'^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$');
  static final _mobile = RegExp(r'^[6-9]\d{9}$');

  static String normalizePlate(String raw) => raw.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  static bool isValidPlate(String normalised) =>
      normalised.length <= 12 && (_plateStandard.hasMatch(normalised) || _plateBh.hasMatch(normalised));

  static bool isValidMobile(String digits) => _mobile.hasMatch(digits);

  static String tenDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length > phoneLength ? digits.substring(digits.length - phoneLength) : digits;
  }

  static String seatsLabel(int n) => n >= 12 ? '12+' : '$n';

  static String labelOf(List<TaxiOption> set, String? value) {
    for (final o in set) {
      if (o.value == value) return o.label;
    }
    return value ?? '';
  }

  static String categoryLabel(String? value) => labelOf(categories, value);

  static String tripLabel(String? value) => labelOf(tripTypes, value);

  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  static String vehicleLabel(TaxiOwnerModel t) {
    final c = t.vehicleCategory;
    if (c != null && c.isNotEmpty) return categoryLabel(c);
    return t.vehicleTypeName ?? 'Vehicle';
  }

  static String vehicleSummary(TaxiOwnerModel t) => [
        vehicleLabel(t),
        if (t.seats != null) '${seatsLabel(t.seats!)} seats',
      ].join(' · ');

  static String step1Summary(TaxiOwnerModel t) => [
        vehicleSummary(t),
        if (t.plateDisplay != null && t.plateDisplay!.isNotEmpty) t.plateDisplay!,
      ].join(' · ');

  static String routesSummary(TaxiOwnerModel t) {
    final n = t.routes.length;
    final min = t.minFare;
    final from = min != null ? ' · from ${BrowseItem.inr(min)}' : '';
    return '$n route${n == 1 ? '' : 's'}$from';
  }
}
