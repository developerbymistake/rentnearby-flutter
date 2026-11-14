import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../trip_strings_hub_trips.dart';
import '../../utils/trip_card_bars.dart';
import 'hub_tokens.dart';

class HubCardBars extends StatelessWidget {
  final TripCardBars bars;
  const HubCardBars({super.key, required this.bars});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: HubTokens.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Bar(
              label: TripStringsHubTrips.stay,
              bar: bars.stay,
              from: const Color(0xFF66BB6A),
              to: const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Bar(
              label: TripStringsHubTrips.taxi,
              bar: bars.taxi,
              from: const Color(0xFFFA7D82),
              to: const Color(0xFFE0525C),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Bar(
              label: TripStringsHubTrips.travel,
              bar: bars.travel,
              from: HubTokens.accentLight,
              to: HubTokens.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final TripCardBar bar;
  final Color from;
  final Color to;
  const _Bar({required this.label, required this.bar, required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Ink3D.text(11.5, FontWeight.w600, HubTokens.sub, height: 1.5, letterSpacing: 0)),
        Container(
          width: double.infinity,
          height: 6,
          margin: const EdgeInsets.fromLTRB(0, 5, 0, 4),
          decoration: BoxDecoration(color: HubTokens.trackBar, borderRadius: BorderRadius.circular(4)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: bar.fraction.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(colors: [from, to]),
              ),
            ),
          ),
        ),
        Text(
          bar.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Ink3D.text(11, FontWeight.w400, HubTokens.grey, height: 22 / 11, letterSpacing: 0),
        ),
      ],
    );
  }
}
