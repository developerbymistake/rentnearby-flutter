import '../../../utils/money_format.dart';
import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class StaySpecialPriceStrings {
  static const title = 'Special prices';
  static String sub(String name) => name.isEmpty ? 'All rooms' : '$name · all rooms';
  static String meterLabel(bool plus, int limit) => plus ? 'Special prices on Plus' : (limit == 1 ? 'Special price on Free' : 'Special prices on Free');
  static const meterLabelOff = 'Special prices';
  static String meterCount(int used, int limit) => '$used of $limit';
  static String basePrices(List<int> prices) => prices.map(Money.exact).join(' / ');
  static String basePricesLabel(List<String> names) => '${names.join(' / ')} per night';
  static const higher = 'Higher';
  static const lower = 'Lower';
  static String percentHigher(int p) => '$p% higher';
  static String percentLower(int p) => '$p% lower';
  static String ruleLine(String dates, int percent, bool lower) => '$dates · ${lower ? percentLower(percent) : percentHigher(percent)}';
  static String priceStep(String room, int from, int to) => '$room ${Money.exact(from)} → ${Money.exact(to)}';
  static const live = 'Live';
  static const paused = 'Paused';
  static const pausedOnFree = 'Paused on Free';
  static const edit = 'Edit';
  static const delete = 'Delete';
  static const yourDates = 'Your dates';
  static const addSpecialPrice = 'Add special price';
  static const plusKeeps5 = 'Plus keeps 5 at a time';
  static const shieldNote = 'Travellers see the price for their dates. It is information only: they still ask, you send the offer.';
  static const addButton = '+ Add special price';
  static const deleteTitle = 'Delete this special price?';
  static const cancel = 'Cancel';

  static const sheetTitle = 'Special price';
  static String sheetSub(String name) => name.isEmpty ? 'All rooms' : 'All rooms · $name';
  static const dates = 'Dates';
  static String festivalChip(String name, String range) => '$name, $range';
  static const pickDates = 'Pick dates';
  static const from = 'From';
  static const to = 'To';
  static const change = 'Change';
  static const lowerPrice = 'Lower price';
  static const higherPrice = 'Higher price';
  static const percentChips = [10, 15, 20, 25];
  static String percent(int p) => '$p%';
  static const minus = '−';
  static const plusSign = '+';
  static String nights(int n) => n == 1 ? '1 night' : '$n nights';
  static String previewHigher(String range, int nights) => '$range · ${StaySpecialPriceStrings.nights(nights)} · travellers see only the new price';
  static String previewLower(String range, int nights, int percent) =>
      '$range · ${StaySpecialPriceStrings.nights(nights)} · travellers see the price with “$percent% off”';
  static const appliesNote = 'Applies to all your rooms. Bookings and offers already sent do not change.';
  static const save = 'Save';
  static const decrease = 'Lower the percent';
  static const increase = 'Raise the percent';

  static const overlap = 'These dates already have a special price.';
  static String overlapLine(String label, String range) => '$label ($range) covers part of these dates. Change the dates, or edit that price.';
  static String editRule(String label) => 'Edit $label';
  static const savesLimit = 'You can change special prices 3 times a day. Try again tomorrow.';
  static const tooManyNights = 'A special price can cover up to 60 nights.';
  static const startTooFar = 'Start date must be within 180 days.';
  static const percentLowerRange = 'Pick a percent between 5 and 50.';
  static const percentHigherRange = 'Pick a percent between 5 and 100.';

  static String a11ySwitch(String name, bool on) => '$name, ${on ? 'live' : 'paused'}';
  static String a11yEdit(String name) => 'Edit $name';
  static String a11yDelete(String name) => 'Delete $name';

  static String rangeTo(DateTime from, DateTime to) {
    if (from.year == to.year && from.month == to.month) {
      return from.day == to.day ? OwnerSharedStrings.dayMonth(from) : '${from.day} to ${OwnerSharedStrings.dayMonth(to)}';
    }
    return '${OwnerSharedStrings.dayMonth(from)} to ${OwnerSharedStrings.dayMonth(to)}';
  }

  static String longDate(DateTime d) => '${d.day} ${OwnerSharedStrings.monthsShort[d.month - 1]} ${d.year}';
}

abstract final class StayPlanVisibleStrings {
  static const title = 'Choose what stays';
  static String sub(int photos, int rooms) => 'Free shows ${photos == 1 ? '1 photo' : '$photos photos'} and ${rooms == 1 ? '1 room type' : '$rooms room types'}';
  static const photos = 'Photos';
  static const roomTypes = 'Room types';
  static String chosen(int n, int of) => '$n of $of chosen';
  static const cover = 'Cover';
  static String perNight(int price) => '${Money.exact(price)} / night';
  static const keptNote = 'Hidden photos and rooms are kept. Travellers do not see them. They come back on Plus.';
  static const threeADay = 'You can change this 3 times a day.';
  static const save = 'Save';
  static const seePlus = OwnerSharedStrings.seePlus;
  static const invalid = 'Pick exactly what your plan allows.';
  static const notNeeded = 'Nothing is hidden.';
  static String photoA11y(int i, bool on) => 'Photo ${i + 1}, ${on ? 'shown' : 'hidden'}';
}
