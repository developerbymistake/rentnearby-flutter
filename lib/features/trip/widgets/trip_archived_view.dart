import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../../config/app_insets.dart';
import '../../buddy/buddy_navigation.dart';
import '../../buddy/shared/widgets/note_banner.dart';
import '../models/trip_archive_model.dart';
import '../models/trip_model.dart';
import '../trip_strings_archived.dart';
import '../trip_strings_summary.dart';
import '../utils/trip_format.dart';
import '../utils/trip_parts.dart';
import 'trip_overview_progress.dart';
import 'trip_page_header.dart';

// Read-only page of an archived trip: the plan is gone, only the kept summary is shown.
class TripArchivedView extends StatelessWidget {
  const TripArchivedView({super.key, required this.trip, this.onBack});

  final TripModel trip;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final summary = trip.archiveOrFallback;
    return Scaffold(
      key: const ValueKey('trip_archived_view'),
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: TripPageHeader(
              title: TripStringsArchived.title,
              subtitle: TripArchiveSections.titleOf(summary, trip.title),
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(16), DS.s(18), AppInsets.bottomViewPadding(context) + DS.gv(24)),
              children: [
                NoteBanner(key: const ValueKey('trip_archived_note'), text: TripStringsArchived.note, margin: EdgeInsets.zero),
                Gap.v(12),
                TripArchiveSections(
                  summary: summary,
                  fallbackTitle: trip.title,
                  onTravellers: () => BuddyNavigation.openTravellers(trip.id),
                  onExpenses: () => BuddyNavigation.openMoneySummary(trip.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TripArchiveSections extends StatelessWidget {
  const TripArchiveSections({
    super.key,
    required this.summary,
    this.fallbackTitle = '',
    this.onTravellers,
    this.onExpenses,
    this.showPeopleAndMoney = true,
  });

  final TripArchiveSummary summary;
  final String fallbackTitle;
  final VoidCallback? onTravellers;
  final VoidCallback? onExpenses;
  final bool showPeopleAndMoney;

  static String titleOf(TripArchiveSummary s, String fallback) {
    final t = s.title ?? fallback.trim();
    if (t.isNotEmpty) return t;
    final names = s.cities.map((c) => c.name).toList();
    if (names.isEmpty) return TripStringsArchived.title;
    if (names.length == 1) return names.first;
    return TripStringsArchived.citiesTitle(names.first, names.last, names.length);
  }

  static String? datesOf(TripArchiveSummary s) {
    final a = s.startDate;
    final b = s.endDate ?? a;
    if (a == null || b == null) return null;
    return '${TripFormat.dayMonthRange(a, b)} ${b.year}';
  }

  static String lineOf(TripArchiveSummary s, {bool withTravellers = true}) {
    final members = s.memberCount ?? 0;
    return [
      ?datesOf(s),
      if (TripStringsArchived.daysPlaces(s.dayCount ?? 0, s.spotCount ?? 0) case final dp when dp.isNotEmpty) dp,
      if (withTravellers && members > 0) TripStringsSummary.travellers(members),
    ].join(' · ');
  }

  static TextStyle get _heading => Ink3D.text(16, FontWeight.w700, Ink3D.title, height: 1.5, letterSpacing: 0);
  static TextStyle get _strong => Ink3D.text(13, FontWeight.w600, Ink3D.title, height: 1.45, letterSpacing: 0);
  static TextStyle get _small => Ink3D.text(12, FontWeight.w400, Ink3D.grey, height: 1.5, letterSpacing: 0);

  static BoxDecoration get _box =>
      BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: DS.shadows(Ink3D.softShadow));

  Widget _city(int i, TripArchiveCity c) {
    final more = c.moreSpots;
    final spots = c.spots.isEmpty ? null : [c.spots.join(', '), if (more > 0) TripStringsArchived.moreSpots(more)].join(' ');
    return Padding(
      key: ValueKey('trip_archived_city_$i'),
      padding: EdgeInsets.only(top: DS.gv(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(TripStringsArchived.cityLine(c.name, c.nights), maxLines: 1, overflow: TextOverflow.ellipsis, style: _strong),
          if (spots != null) Text(spots, maxLines: 3, overflow: TextOverflow.ellipsis, style: _small),
          if (c.stays.isNotEmpty)
            Text(TripStringsArchived.stays(c.stays), key: ValueKey('trip_archived_stay_$i'), maxLines: 2, overflow: TextOverflow.ellipsis, style: _small),
        ],
      ),
    );
  }

  Widget _row(String key, String asset, String text, VoidCallback? onTap) {
    final row = Padding(
      padding: DS.insets(l: 16, t: 14, r: 12, b: 14),
      child: Row(
        children: [
          ExcludeSemantics(child: TravelIcon(asset, size: 22)),
          Gap.h(12),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _strong)),
          if (onTap != null) Icon(Icons.chevron_right_rounded, size: DS.s(20), color: Ink3D.grey),
        ],
      ),
    );
    return Padding(
      key: ValueKey(key),
      padding: EdgeInsets.only(top: DS.gv(12)),
      child: Container(
        decoration: _box,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: DS.br(CardRadius.card),
            onTap: onTap,
            child: Semantics(button: onTap != null, child: row),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final members = s.memberCount ?? 0;
    final spent = s.expensesTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TripOverviewProgress(
          key: const ValueKey('trip_archived_card'),
          parts: TripParts.none,
          title: titleOf(s, fallbackTitle),
          line: lineOf(s, withTravellers: showPeopleAndMoney),
          showProgress: false,
        ),
        if (s.cities.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: DS.gv(12)),
            child: Container(
              key: const ValueKey('trip_archived_route'),
              padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
              decoration: _box,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(TripStringsArchived.routeTitle, style: _heading),
                  for (var i = 0; i < s.cities.length; i++) _city(i, s.cities[i]),
                ],
              ),
            ),
          ),
        if (s.taxiBooked) _row('trip_archived_taxi', TravelIcon.taxi, TripStringsArchived.taxiBooked, null),
        if (showPeopleAndMoney && members > 1)
          _row('trip_archived_travellers', TravelIcon.luggage, TripStringsSummary.travellers(members), onTravellers),
        if (showPeopleAndMoney && spent != null && spent > 0)
          _row('trip_archived_expenses', TravelIcon.money, TripStringsArchived.spent(spent), onExpenses),
      ],
    );
  }
}
