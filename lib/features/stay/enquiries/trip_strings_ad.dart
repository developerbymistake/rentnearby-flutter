import '../../../models/browse_item.dart';

class TripStringsAD {
  static String perRoomPerNight(int price) => '${BrowseItem.inr(price)} per room per night';

  static String roomsNightsTotal(int rooms, int nights, int total) =>
      '$rooms room${rooms == 1 ? '' : 's'} x $nights night${nights == 1 ? '' : 's'} · Total ${BrowseItem.inr(total)}';

  static String listedPerNight(int price) => 'Listed ${BrowseItem.inr(price)}';

  static String priceTooHigh(int max) => 'Price must be at most ${BrowseItem.inr(max)} per night';

  static String totalTooHigh(int max) => 'Total must be at most ${BrowseItem.inr(max)}';
}
