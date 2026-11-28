import 'package:flutter/material.dart';

import '../../../../widgets/location_switch_sheet.dart';
import '../social_strings_a.dart';
import 'place_picker_sheet.dart';

abstract final class HomeCitySheet {
  static Future<PickedHome?> pick(BuildContext context) async {
    final p = await LocationSwitchSheet.pick(context, title: SocialStringsA.pickHomeTitle);
    if (p == null) return null;
    return PickedHome(city: p.name, state: p.stateName ?? '');
  }
}
