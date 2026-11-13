import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'trip_ui.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../models/trip_journey_model.dart';
import '../trip_strings_steps_a2.dart';

class TripJourneyCompact extends StatelessWidget {
  final TripJourney journey;
  final bool showContacts;
  final bool dense;
  final Color? tone;

  const TripJourneyCompact({super.key, required this.journey, this.showContacts = true, this.dense = false, this.tone});

  static const List<Color> _legColors = [TripUi.tripDark, TripUi.taxiDark];

  static Color legColor(int i) => _legColors[i % _legColors.length];

  static String driverOf(String? name) =>
      name == null || name.trim().isEmpty ? TripStringsStepsA2.driverFallback : name.trim();

  static String? phoneOf(String? a, String? b) {
    for (final p in [a, b]) {
      if (p != null && ContactLauncher.tenDigits(p).isNotEmpty) return p;
    }
    return null;
  }

  static String? fareOf(int? fare) => fare == null || fare <= 0 ? null : BrowseItem.inr(fare);

  List<String> get _nodes {
    final legs = journey.legs;
    final p = journey.places;
    if (p.length == legs.length + 1) return p;
    return [
      journey.fromName,
      for (var i = 1; i < legs.length; i++) legs[i].changePlace,
      journey.toName,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (dense) return _dense();
    final legs = journey.legs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (legs.length > 1) ...[
          LayoutBuilder(
            builder: (context, box) => legs.length <= 2 && box.maxWidth >= 260
                ? KitRouteReveal(child: _railRow())
                : KitRouteReveal(axis: Axis.vertical, child: _railColumn()),
          ),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < legs.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _legBlock(legs[i], i, single: legs.length == 1),
        ],
      ],
    );
  }

  Widget _dense() {
    final legs = journey.legs;
    final fares = [
      for (final l in legs) [driverOf(l.driverName), ?fareOf(l.listedFare)].join(' '),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _nodes.join(' → '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: FitnessAppTheme.darkerText),
        ),
        if (fares.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            fares,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.lightText),
          ),
        ],
        if (showContacts)
          for (var i = 0; i < legs.length; i++) ...[
            const SizedBox(height: 8),
            _contacts(legs[i]),
          ],
      ],
    );
  }

  Widget _railRow() {
    final nodes = _nodes;
    final legs = journey.legs;
    final children = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final change = i > 0 && i < nodes.length - 1;
      children.add(SizedBox(width: change ? 64 : 56, child: _node(nodes[i], change: change)));
      if (i < legs.length) {
        final l = legs[i];
        children.add(Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                TravelIcon(TravelIcon.taxi, size: 14),
                const SizedBox(height: 3),
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: l.driverAvailable ? legColor(i) : TripUi.warn,
                    borderRadius: CardRadius.pill,
                  ),
                ),
                const SizedBox(height: 3),
                if (fareOf(l.listedFare) != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      fareOf(l.listedFare)!,
                      maxLines: 1,
                      style: const TextStyle(
                          fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w800, color: TripUi.warn),
                    ),
                  ),
              ],
            ),
          ),
        ));
      }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _node(String name, {required bool change}) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: change ? FitnessAppTheme.white : TripUi.taxiDark,
            border: change ? Border.all(color: TripUi.warn, width: 3) : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w700, color: FitnessAppTheme.darkerText),
        ),
        if (change)
          const Text(
            TripStringsStepsA2.changeCar,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w700, color: TripUi.warn),
          ),
      ],
    );
  }

  Widget _railColumn() {
    final nodes = _nodes;
    final legs = journey.legs;
    final rows = <Widget>[];
    for (var i = 0; i < nodes.length; i++) {
      final change = i > 0 && i < nodes.length - 1;
      rows.add(Row(
        children: [
          SizedBox(
            width: 20,
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: change ? FitnessAppTheme.white : TripUi.taxiDark,
                  border: change ? Border.all(color: TripUi.warn, width: 3) : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              change ? '${nodes[i]} · ${TripStringsStepsA2.changeCar}' : nodes[i],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: FitnessAppTheme.fontName,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: change ? TripUi.warn : FitnessAppTheme.darkerText,
              ),
            ),
          ),
        ],
      ));
      if (i < legs.length) {
        final l = legs[i];
        final color = l.driverAvailable ? legColor(i) : TripUi.warn;
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 20,
                child: Center(
                  child: Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: CardRadius.pill)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    [TripStringsStepsA2.carDriver(i + 1), ?fareOf(l.listedFare)].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, color: FitnessAppTheme.lightText),
                  ),
                ),
              ),
            ],
          ),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  Widget _legBlock(TripJourneyLeg l, int i, {required bool single}) {
    final name = driverOf(l.driverName);
    final paused = !l.driverAvailable;
    final head = single
        ? ClipRRect(
            borderRadius: CardRadius.chip,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: paused ? TripUi.warnTint : DesignColors.tint(tone ?? TripUi.taxiDark, Alpha.hairline),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 5, color: paused ? TripUi.warn : (tone ?? TripUi.taxiDark)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.style(13, FontWeight.w700, color: DesignColors.textStrong),
                            ),
                            Text(
                              TripStringsStepsA2.vehicleLine(l.fromName, l.toName, l.vehicleTypeName),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.style(12, FontWeight.w400, color: TypeTokens.secondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '${TripStringsStepsA2.carDriver(i + 1)} ',
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontWeight: FontWeight.w700, color: FitnessAppTheme.darkerText),
              ),
              TextSpan(text: name),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.lightText),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        head,
        if (paused) ...[
          const SizedBox(height: 6),
          _pausedLine(name, l.backupName),
        ],
        if (showContacts) ...[
          const SizedBox(height: 8),
          _contacts(l),
        ],
      ],
    );
  }

  Widget _pausedLine(String name, String? backup) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: TravelIcon(TravelIcon.calendar, size: 16),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              TripStringsStepsA2.driverPaused(name, backup),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: TripUi.warn),
            ),
          ),
        ],
      );

  Widget _contacts(TripJourneyLeg l) {
    final call = phoneOf(l.phone, l.whatsApp);
    if (call == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: _contactButton(TripStringsStepsA2.call, const SizedBox.shrink(), TripUi.taxiDark, () => ContactLauncher.call(call)),
    );
  }

  static Widget _contactButton(String label, Widget icon, Color color, VoidCallback? onTap) => SecondaryButton(
        label: label,
        onPressed: onTap,
        tone: TripUi.toneOf(color),
        height: 44,
        icon: icon,
      );
}
