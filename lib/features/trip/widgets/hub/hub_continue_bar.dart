import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../trip_navigation.dart';
import '../../trip_strings_hub.dart';
import '../../utils/trip_bar_rules.dart';
import '../trip_card.dart';
import 'hub_dots.dart';
import 'hub_ring.dart';
import 'hub_tokens.dart';
import 'hub_trip_body.dart';

class HubContinueBar extends StatefulWidget {
  const HubContinueBar({super.key, required this.trips, required this.onContinue});

  final List<TripSummaryModel> trips;
  final ValueChanged<TripSummaryModel> onContinue;

  @override
  State<HubContinueBar> createState() => _HubContinueBarState();
}

class _HubContinueBarState extends State<HubContinueBar> {
  bool _open = false;
  int _index = 0;

  int get _safeIndex => _index.clamp(0, widget.trips.length - 1);

  void _toggle() => setState(() => _open = !_open);

  void _swipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final n = widget.trips.length;
    if (n < 2 || v.abs() < 200) return;
    setState(() => _index = v < 0 ? (_safeIndex + 1) % n : (_safeIndex - 1 + n) % n);
  }

  static String _name(TripSummaryModel t) => t.title.trim().isEmpty ? TripCard.routeTitle(t) : t.title.trim();

  @override
  Widget build(BuildContext context) {
    final trips = widget.trips;
    if (trips.isEmpty) return const SizedBox.shrink();
    final t = trips[_safeIndex];
    final reduce = KitMotion.reduce(context);
    final next = TripBarRules.nextTitle(t);
    final name = _name(t);
    final sub = next == null ? name : '$name · ${TripStringsHub.nextPrefix}: $next';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onHorizontalDragEnd: _swipe,
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: HubTokens.cardRadius(44),
              boxShadow: HubTokens.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: HubTokens.cardRadius(44),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(t, sub),
                  AnimatedSize(
                    duration: reduce ? Duration.zero : const Duration(milliseconds: 380),
                    curve: Curves.ease,
                    alignment: Alignment.topCenter,
                    child: _open ? _body(t) : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (trips.length > 1) ...[
          const SizedBox(height: 13),
          HubDots(count: trips.length, index: _safeIndex),
        ],
      ],
    );
  }

  Widget _header(TripSummaryModel t, String sub) {
    return Semantics(
      button: true,
      expanded: _open,
      label: _open ? TripStringsHub.closeBar : TripStringsHub.openBar,
      child: InkWell(
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              HubRing(
                percent: t.progress.percent,
                center: Text('${t.progress.percent}%', style: Ink3D.text(12, FontWeight.w700, HubTokens.ink, letterSpacing: 0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      TripStringsHub.continueTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(15, FontWeight.w700, HubTokens.ink, letterSpacing: 0),
                    ),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(12, FontWeight.w400, HubTokens.sub, letterSpacing: 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 22),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: HubTokens.chipBg),
                child: AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Center(child: CustomPaint(size: Size(9, 5), painter: _CaretPainter())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(TripSummaryModel t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: TripNavigation.openMyTrips,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Align(
                  widthFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(TripStringsHub.viewAll, style: Ink3D.text(14, FontWeight.w700, HubTokens.blue, letterSpacing: 0)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: HubTokens.blue),
                    ],
                  ),
                ),
              ),
            ),
          ),
          HubTripBody(key: ValueKey('hub-body-${t.id}'), trip: t, onNext: () => widget.onContinue(t)),
        ],
      ),
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = HubTokens.accent);
  }

  @override
  bool shouldRepaint(_CaretPainter old) => false;
}
