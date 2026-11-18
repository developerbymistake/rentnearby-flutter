import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../models/taxi_request_models.dart';
import '../../trip_strings_taxi_status.dart';
import 'taxi_driver_card.dart';

class TaxiStatusHero extends StatelessWidget {
  const TaxiStatusHero({super.key, required this.art, required this.title, this.line, this.titleSize = 24});

  final String art;
  final String title;
  final String? line;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final sub = line;
    return Column(
      children: [
        Art3D(asset: art, size: 84, shadowBlur: 6, shadowOffset: const Offset(3, 5)),
        Gap.v(10),
        Text(title, textAlign: TextAlign.center, style: Ink3D.text(titleSize, FontWeight.w700, Ink3D.title)),
        if (sub != null && sub.isNotEmpty) ...[
          Gap.v(4),
          Text(sub, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, Ink3D.copy)),
        ],
      ],
    );
  }
}

class TaxiStatusCard extends StatelessWidget {
  const TaxiStatusCard({super.key, this.cardKey, required this.children});

  final Key? cardKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      padding: DS.insets(l: 16, t: 16, r: 16, b: 16),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.hero), boxShadow: DS.shadows(Ink3D.softShadow)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class TaxiDangerOutline extends StatelessWidget {
  const TaxiDangerOutline({super.key, required this.label, required this.onTap, this.buttonKey});

  final String label;
  final VoidCallback? onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final height = DS.s(48);
    final body = Container(
      height: height,
      alignment: Alignment.center,
      padding: DS.sym(h: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: DesignColors.statusAttention, width: DS.s(1.5)),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: Ink3D.text(14, FontWeight.w700, Form3D.errorText))),
    );
    return Tap3D(tapKey: buttonKey, onTap: onTap, child: onTap == null ? Opacity(opacity: 0.45, child: body) : body);
  }
}

const double _buttonFont = 14;

class TaxiBookedCard extends StatelessWidget {
  const TaxiBookedCard({
    super.key,
    required this.request,
    required this.driver,
    required this.enabled,
    required this.onCall,
    required this.onCancel,
    required this.onEnd,
  });

  final TaxiRequest request;
  final TaxiDriverCard? driver;
  final bool enabled;
  final VoidCallback? onCall;
  final VoidCallback onCancel;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final b = request.booking;
    final progress = request.view == RequestView.inProgress;
    final day = b?.dayNumber;
    final total = request.dayCount;
    final canAct = progress ? (b?.canEnd ?? false) : (b?.canCancel ?? request.canCancel);
    final call = onCall == null
        ? null
        : WhitePillButton(key: const ValueKey('booked_call'), tone: ListingTone.indigo, label: TripStringsTaxiStatus.call, onTap: enabled ? onCall : null, height: 48, fontSize: _buttonFont);
    final act = canAct
        ? TaxiDangerOutline(
            buttonKey: ValueKey(progress ? 'end_trip' : 'cancel_booking'),
            label: progress ? TripStringsTaxiStatus.endTrip : TripStringsTaxiStatus.cancelBooking,
            onTap: enabled ? (progress ? onEnd : onCancel) : null,
          )
        : null;
    return TaxiStatusCard(
      cardKey: ValueKey(progress ? 'taxi_in_progress_card' : 'taxi_booked_card'),
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: DS.gh(12),
          runSpacing: DS.gv(6),
          children: [
            TaxiStateChip(label: progress ? TripStringsTaxiStatus.inProgress : TripStringsTaxiStatus.booked, positive: true),
            Text(
              progress && day != null ? TripStringsTaxiStatus.dayOf(day, total) : TripStringsTaxiStatus.dates(b?.from ?? request.from, b?.to ?? request.to),
              style: Ink3D.text(16, FontWeight.w700, Ink3D.title),
            ),
          ],
        ),
        if (progress && day != null && total > 0) ...[
          Gap.v(12),
          ClipRRect(
            borderRadius: DS.circular(4),
            child: LinearProgressIndicator(
              value: (day / total).clamp(0.0, 1.0),
              minHeight: DS.s(8),
              backgroundColor: DesignColors.progressTrack,
              valueColor: const AlwaysStoppedAnimation(DesignColors.statusOffer),
            ),
          ),
        ],
        if (driver != null) ...[
          Gap.v(14),
          TaxiDriverIdentity(driver: driver!, showRating: !progress),
        ],
        if (act != null || call != null) ...[
          Gap.v(14),
          Row(
            children: [
              if (act != null) Expanded(child: act),
              if (act != null && call != null) Gap.h(12),
              if (call != null) Expanded(child: call),
            ],
          ),
        ],
      ],
    );
  }
}

class TaxiBottomBar extends StatelessWidget {
  const TaxiBottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(16))),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(14), DS.s(18), DS.s(20) + MediaQuery.paddingOf(context).bottom),
        child: children.length == 1
            ? children.first
            : PillButtonRow(children: children),
      ),
    );
  }
}
