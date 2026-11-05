import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi/taxi_option_sets.dart';
import '../models/trip_journey_model.dart';
import '../trip_colors.dart';
import '../trip_strings_steps_a2.dart';

class TripJourneyCompact extends StatelessWidget {
  final TripJourney journey;
  final bool showContacts;
  final bool dense;
  final Color? tone;

  const TripJourneyCompact({super.key, required this.journey, this.showContacts = true, this.dense = false, this.tone});

  static const List<Color> _legColors = [TripColors.accentDark, TaxiColors.accentDark];

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
            builder: (context, box) => legs.length <= 2 && box.maxWidth >= 260 ? _railRow() : _railColumn(),
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
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        if (fares.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            fares,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
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
                Icon(Iconsax.car, size: 14, color: l.driverAvailable ? legColor(i) : TripStatusColors.waiting),
                const SizedBox(height: 3),
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: l.driverAvailable ? legColor(i) : TripStatusColors.waiting,
                    borderRadius: BorderRadius.circular(3),
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
                          fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.warningText),
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
            color: change ? Colors.white : TaxiColors.accentDark,
            border: change ? Border.all(color: TripStatusColors.waiting, width: 3) : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        if (change)
          const Text(
            TripStringsStepsA2.changeCar,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.warningText),
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
                  color: change ? Colors.white : TaxiColors.accentDark,
                  border: change ? Border.all(color: TripStatusColors.waiting, width: 3) : null,
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
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: change ? AppColors.warningText : AppColors.textDark,
              ),
            ),
          ),
        ],
      ));
      if (i < legs.length) {
        final l = legs[i];
        final color = l.driverAvailable ? legColor(i) : TripStatusColors.waiting;
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 20,
                child: Center(
                  child: Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
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
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
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
        ? Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            decoration: BoxDecoration(
              color: paused ? AppColors.warningSurface : (tone ?? TaxiColors.accentDark).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: paused ? TripStatusColors.waiting : (tone ?? TaxiColors.accentDark), width: 5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                Text(
                  TripStringsStepsA2.vehicleLine(l.fromName, l.toName, l.vehicleTypeName),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
                ),
              ],
            ),
          )
        : Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '${TripStringsStepsA2.carDriver(i + 1)} ',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              TextSpan(text: name),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
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
            child: Icon(Iconsax.warning_2, size: 14, color: AppColors.warningText),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              TripStringsStepsA2.driverPaused(name, backup),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.warningText),
            ),
          ),
        ],
      );

  Widget _contacts(TripJourneyLeg l) {
    final call = phoneOf(l.phone, l.whatsApp);
    final chat = phoneOf(l.whatsApp, l.phone);
    if (call == null && chat == null) return const SizedBox.shrink();
    final callBtn = _contactButton(TripStringsStepsA2.call, Iconsax.call, TaxiColors.accentDark,
        call == null ? null : () => ContactLauncher.call(call));
    final chatBtn = _contactButton(TripStringsStepsA2.whatsApp, Iconsax.message, AppColors.successDark,
        chat == null ? null : () => ContactLauncher.whatsApp(chat));
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 220) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [callBtn, const SizedBox(height: 8), chatBtn],
        );
      }
      return Row(children: [Expanded(child: callBtn), const SizedBox(width: 8), Expanded(child: chatBtn)]);
    });
  }

  static Widget _contactButton(String label, IconData icon, Color color, VoidCallback? onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: onTap == null ? AppColors.textHint : color),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: onTap == null ? AppColors.textHint : color,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          side: const BorderSide(color: AppColors.divider, width: 1.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
      );
}
