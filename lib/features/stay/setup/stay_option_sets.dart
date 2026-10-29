import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../widgets/role_option_card.dart';
import '../models/stay_owner_model.dart';

class StayColors {
  static const Color accent = AppColors.warning;
  static const Color accentDark = Color(0xFFD97706);
  static const Color surface = Color(0xFFFFFBEB);
  static const LinearGradient gradient = RoleVisuals.stayGradient;
}

class StayOption {
  final String value;
  final String label;
  const StayOption(this.value, this.label);
}

// Values mirror RentNearBy.Core/Models/StayOptions.cs.
class StayOptionSets {
  static const vehicleAccess = [
    StayOption('CarToGate', 'Car to gate'),
    StayOption('ShortWalk', 'Short walk'),
    StayOption('LongWalk', 'Long walk'),
  ];

  static const facilities = [
    StayOption('HotWater', 'Hot water'),
    StayOption('Heater', 'Heater'),
    StayOption('WiFi', 'Wi-Fi'),
    StayOption('Parking', 'Parking'),
    StayOption('HomeFood', 'Home food'),
    StayOption('MountainView', 'Mountain view'),
  ];

  static const roomNames = [
    StayOption('Standard', 'Standard'),
    StayOption('Deluxe', 'Deluxe'),
    StayOption('Premium', 'Premium'),
    StayOption('Suite', 'Suite'),
    StayOption('Family Room', 'Family Room'),
    StayOption('Executive', 'Executive'),
    StayOption('Dormitory', 'Dormitory'),
  ];

  static const meals = [
    StayOption('RoomOnly', 'Room only'),
    StayOption('Breakfast', 'Breakfast'),
    StayOption('AllMeals', 'All meals'),
  ];

  static const cancellation = [
    StayOption('Flexible', 'Flexible'),
    StayOption('Moderate', 'Moderate'),
    StayOption('Strict', 'Strict'),
  ];

  static const maxGuests = [1, 2, 3, 4];
  static const int maxRooms = 2;
  static const int minPrice = 100;
  static const int maxPrice = 9900000;

  static String labelOf(List<StayOption> set, String? value) {
    for (final o in set) {
      if (o.value == value) return o.label;
    }
    return value ?? '';
  }

  static String guestsLabel(int n) => n >= 4 ? '4+' : '$n';

  static String time12(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m ${h < 12 ? 'AM' : 'PM'}';
  }

  static String basicSummary(StayOwnerModel s) => [
        s.name ?? 'Stay',
        '${s.photos.length} photo${s.photos.length == 1 ? '' : 's'}',
      ].join(' · ');

  static String roomsSummary(StayOwnerModel s) {
    final n = s.rooms.length;
    final min = s.minPricePerNight;
    final from = min != null ? ' · from ${BrowseItem.inr(min)} / night' : '';
    return '$n room${n == 1 ? '' : 's'}$from';
  }

  static String rulesSummary(StayOwnerModel s) {
    final r = s.rules;
    if (r == null) return '';
    return '${time12(r.checkInTime)} in · ${time12(r.checkOutTime)} out · '
        '${labelOf(cancellation, r.cancellationPolicy)}';
  }
}
