import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _removed = <String, List<String>>{
  'TripStrings': ['seeAllTaxis', 'taxiEnquiry', 'driverSeesPhone', 'taxiReplies', 'repliedFare', 'listedRate', 'driversFare', 'noteFromDriver', 'driverReplied', 'noTaxiReplies', 'driversReply', 'driverAlsoGot', 'askAnother', 'findAnotherTaxi', 'bothFare', 'addYourDates', 'editBooking', 'viewLead', 'sendEnquiry', 'from', 'to', 'itineraryFromPlan'],
  'TripStringsV2Find': ['taxiTitle', 'taxiSubtitle', 'taxiDays', 'taxiDayNote', 'noTaxiTitle', 'noTaxiBody', 'taxisFailed', 'taxisPaused', 'perDayShort', 'forDays', 'pickDay', 'veryShortNoticeDriver', 'cancelFirstTaxi'],
  'TripStringsV2Easy': ['taxiHint', 'askMoreDrivers', 'driverNotify', 'sentToDrivers'],
  'TripStringsA3': ['seats4', 'seats6', 'suv', 'noMatchTitle', 'noMatchBody', 'clearFilters', 'pastTripTitle', 'readOnlyBody', 'viewStatus', 'more', 'iBookedThis', 'viewDetails', 'contactFailed', 'rateOnRequest', 'errPriceRange'],
  'TripStringsGuide': ['noTaxiNote', 'findATaxi', 'nameTaxi', 'taxiTitle', 'taxiBody', 'carReviewBody', 'chooseAndSend'],
  'TripStringsMcbK1': ['localTaxiLeadKept', 'localTaxiDayRemoved'],
  'TripStringsShortlist': ['sending'],
};

const _baselineBeforeTaxiRequest = <String, int>{
  'lib/design/extra/buttons_kit.dart': 1,
  'lib/design/extra/card_kit.dart': 12,
  'lib/design/extra/chat_kit.dart': 1,
  'lib/design/extra/dialog_3d.dart': 4,
  'lib/design/extra/ext_chat.dart': 1,
  'lib/design/extra/ext_details.dart': 7,
  'lib/design/extra/ext_jobs.dart': 2,
  'lib/design/extra/ext_journeys.dart': 6,
  'lib/design/extra/ext_plans.dart': 1,
  'lib/design/extra/ext_stay_owner.dart': 2,
  'lib/design/extra/ext_trip_replies.dart': 1,
  'lib/design/extra/gate_kit.dart': 7,
  'lib/design/extra/guide_kit_3d.dart': 1,
  'lib/design/extra/listing_chrome.dart': 4,
  'lib/design/extra/meals_card_v.dart': 2,
  'lib/design/extra/option_tile.dart': 3,
  'lib/design/extra/replies_kit.dart': 2,
  'lib/design/extra/state_card.dart': 2,
  'lib/design/extra/state_card_3d.dart': 1,
  'lib/design/extra/stay_grid_card.dart': 2,
  'lib/design/extra/template_ports.dart': 1,
  'lib/design/extra/trip_pick_kit.dart': 1,
  'lib/design/extra/trip_plan_look.dart': 1,
  'lib/design/extra/wide_card.dart': 11,
  'lib/design/extra/workout_card.dart': 2,
  'lib/features/jobs/screens/jobs_landing_screen.dart': 1,
  'lib/features/jobs/screens/my_jobs_screen.dart': 1,
  'lib/features/jobs/widgets/jobs_ui.dart': 1,
  'lib/features/stay/enquiries/stay_enquiry_button.dart': 3,
  'lib/features/stay/guest/stay_bottom_sheet.dart': 3,
  'lib/features/stay/guest/stay_map_screen.dart': 1,
  'lib/features/taxi/journeys/saved_journey_screen.dart': 1,
  'lib/features/taxi/journeys/widgets/journey_rail_row.dart': 1,
  'lib/features/taxi/journeys/widgets/journey_status_banner.dart': 1,
  'lib/features/taxi/leads/trip_leads_screen.dart': 1,
  'lib/features/taxi/ways/journey_road_screen.dart': 1,
  'lib/features/taxi/ways/taxi_ways_feed_screen.dart': 4,
  'lib/features/taxi/ways/widgets/best_way_mark.dart': 1,
  'lib/features/taxi/ways/widgets/journey_total_bar.dart': 1,
  'lib/features/taxi/ways/widgets/travel_confirm_sheet.dart': 2,
  'lib/features/taxi/ways/widgets/ways_arrange_bar.dart': 2,
  'lib/features/trip/screens/trip_stay_screen.dart': 1,
  'lib/features/trip/screens/trip_taxi_screen.dart': 4,
  'lib/features/trip/widgets/hub/hub_card_bars.dart': 1,
  'lib/features/trip/widgets/trip_city_sheet.dart': 3,
  'lib/features/trip/widgets/trip_day_chips.dart': 1,
  'lib/features/trip/widgets/trip_filter_chips.dart': 1,
  'lib/features/trip/widgets/trip_journey_compact.dart': 2,
  'lib/features/trip/widgets/trip_journey_strip.dart': 1,
  'lib/features/trip/widgets/trip_map_day_card.dart': 1,
  'lib/features/trip/widgets/trip_map_travel_block.dart': 3,
  'lib/features/trip/widgets/trip_problem_sheet.dart': 1,
  'lib/features/trip/widgets/trip_route_strip.dart': 1,
  'lib/features/trip/widgets/trip_spots_extras.dart': 1,
  'lib/features/trip/widgets/trip_today_card.dart': 2,
  'lib/features/trip/widgets/trip_ui.dart': 6,
  'lib/screens/home_screen.dart': 5,
  'lib/screens/notifications_screen.dart': 1,
  'lib/screens/plan_history_screen.dart': 1,
  'lib/widgets/chat_message_bubble.dart': 1,
  'lib/widgets/chat_schedule_picker_sheet.dart': 1,
  'lib/widgets/detail_header.dart': 3,
  'lib/widgets/home_card_surface.dart': 1,
  'lib/widgets/listing_grid_card.dart': 2,
  'lib/widgets/listing_share_card.dart': 29,
  'lib/widgets/location_pill.dart': 1,
  'lib/widgets/tour_info_dialog.dart': 1,
  'lib/widgets/tour_overlay.dart': 1,
};

void main() {
  test('no_removed_string_is_referenced', () {
    final files = [
      ...Directory('lib').listSync(recursive: true),
      ...Directory('test').listSync(recursive: true),
    ].whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.endsWith('unused_taxi_strings_test.dart'));
    final text = {for (final f in files) f.path: f.readAsStringSync()};
    final hits = <String>[];
    _removed.forEach((cls, names) {
      for (final n in names) {
        final re = RegExp('\\b$cls\\.$n\\b');
        for (final e in text.entries) {
          if (re.hasMatch(e.value)) hits.add('${e.key}: $cls.$n');
        }
      }
    });
    expect(hits, isEmpty);
  });

  test('removed_strings_are_gone_from_the_string_files', () {
    final src = Directory('lib/features/trip').listSync().whereType<File>().where((f) => f.path.contains('trip_strings')).map((f) => f.readAsStringSync()).join('\n');
    final left = <String>[];
    _removed.forEach((cls, names) {
      final body = RegExp('class $cls \\{([\\s\\S]*?)\\n\\}').firstMatch(src)?.group(1) ?? '';
      for (final n in names) {
        if (RegExp('static[^;=(]*\\b$n\\b\\s*(=|\\(|=>)').hasMatch(body)) left.add('$cls.$n');
      }
    });
    expect(left, isEmpty);
  });

  test('layout_baseline_lists_only_files_that_exist', () {
    final base = jsonDecode(File('test/lint/raw_layout_baseline.json').readAsStringSync()) as Map<String, dynamic>;
    expect([for (final k in base.keys) if (!File(k).existsSync()) k], isEmpty);
  });

  test('layout_baseline_has_no_new_or_larger_entry', () {
    final base = jsonDecode(File('test/lint/raw_layout_baseline.json').readAsStringSync()) as Map<String, dynamic>;
    final grown = <String>[
      for (final e in base.entries)
        if ((e.value as int) > (_baselineBeforeTaxiRequest[e.key] ?? 0)) '${e.key}: ${_baselineBeforeTaxiRequest[e.key] ?? 'new'} -> ${e.value}',
    ];
    expect(grown, isEmpty);
  });
}
