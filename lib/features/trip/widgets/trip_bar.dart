import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../controllers/my_trips_controller.dart';
import '../trip_navigation.dart';
import '../trip_strings_bar.dart';
import '../utils/trip_bar_rules.dart';
import 'trip_bar_hide_sheet.dart';
import 'trip_card.dart';

class TripBar extends StatefulWidget {
  const TripBar({super.key});

  @override
  State<TripBar> createState() => _TripBarState();
}

class _TripBarState extends State<TripBar> {
  final _trips = MyTripsController.to;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _trips.ensureLoaded();
    });
  }

  void _continue(TripBarPick pick) {
    Get.toNamed(AppRoutes.tripPlan, arguments: TripBarRules.continueArgs(pick.trip))?.then((_) => _trips.load());
  }

  Future<void> _hide(TripBarPick pick) async {
    if (await TripBarHideSheet.show(context)) _trips.hideBar(pick.trip);
  }

  static String _line(TripBarPick pick) {
    switch (pick.line) {
      case TripBarLine.today:
        return TripStringsBar.todayLine;
      case TripBarLine.tomorrow:
        return TripStringsBar.tomorrowLine;
      case TripBarLine.next:
        final next = TripBarRules.nextTitle(pick.trip);
        return next == null ? TripStringsBar.readyLine : TripStringsBar.next(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pick = _trips.barPick;
      return AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.fastOutSlowIn,
        alignment: Alignment.bottomCenter,
        child: pick == null ? const SizedBox(width: double.infinity) : _BarEntrance(key: ValueKey(pick.trip.id), child: _bar(pick)),
      );
    });
  }

  static const _titleStyle =
      TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w800, color: FitnessAppTheme.white);
  static final _lineStyle = TextStyle(
      fontFamily: FitnessAppTheme.fontName,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: FitnessAppTheme.white.withValues(alpha: Alpha.high));
  static const _moreStyle =
      TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, fontWeight: FontWeight.w700, color: FitnessAppTheme.white);
  static const _continueStyle =
      TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, fontWeight: FontWeight.w800, color: FitnessAppTheme.nearlyDarkBlue);

  static double _textWidth(TextScaler scaler, String text, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)
      ..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  Widget _bar(TripBarPick pick) {
    final t = pick.trip;
    final title = t.title.trim().isEmpty ? t.routeLine : t.title.trim();
    final line = _line(pick);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: LayoutBuilder(builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        final more = pick.more > 0 ? TripStringsBar.more(pick.more) : null;
        final actionsWidth = (more == null ? 0 : 6 + 16 + _textWidth(scaler, more, _moreStyle)) +
            6 +
            26 +
            _textWidth(scaler, TripStringsBar.continueAction, _continueStyle);
        final textRoom = box.maxWidth - 10 - 40 - 6 - 26 - 6 - actionsWidth - 40;
        final textNeed = [
          _textWidth(scaler, title, _titleStyle),
          _textWidth(scaler, line, _lineStyle),
          scaler.scale(120),
        ].reduce((a, b) => a < b ? a : b);
        final stacked = textRoom < textNeed;
        final actions = <Widget>[
          if (more != null) ...[
            if (!stacked) const SizedBox(width: 6),
            GestureDetector(
              onTap: TripNavigation.openMyTrips,
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints(minHeight: 32),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: FitnessAppTheme.white.withValues(alpha: Alpha.soft),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(more, maxLines: 1, softWrap: false, style: _moreStyle),
              ),
            ),
          ],
          if (more != null || !stacked) const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minHeight: 32),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(color: FitnessAppTheme.white, borderRadius: BorderRadius.circular(8)),
            child: const Text(TripStringsBar.continueAction, maxLines: 1, softWrap: false, style: _continueStyle),
          ),
        ];
        final close = IconButton(
          tooltip: TripStringsBar.hideTooltip,
          onPressed: () => _hide(pick),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          icon: const Icon(Icons.close_rounded, size: 18, color: FitnessAppTheme.white),
        );
        final top = Row(
          children: [
            TripProgressRing(
              percent: t.progress.percent,
              size: 40,
              stroke: 4.5,
              fill: FitnessAppTheme.white,
              color: TripBarRules.isReady(t) ? FitnessAppTheme.nearlyBlue : FitnessAppTheme.nearlyDarkBlue,
              textColor: FitnessAppTheme.darkerText,
            ),
            const SizedBox(width: 6),
            TripKit.travelBadge('assets/images/design/travel3d/luggage.png', size: 26, image: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle),
                  Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: _lineStyle),
                ],
              ),
            ),
            if (!stacked) ...actions,
            close,
          ],
        );
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _continue(pick),
            splashColor: FitnessAppTheme.white.withValues(alpha: Alpha.soft),
            highlightColor: Colors.transparent,
            borderRadius: TripKit.cardRadiusSmall,
            child: Ink(
              padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
              decoration: TripKit.cardBox(gradient: TripKit.sky, radius: TripKit.cardRadiusSmall),
              child: stacked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        top,
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 6),
                          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
                        ),
                      ],
                    )
                  : top,
            ),
          ),
        );
      }),
    );
  }
}

class _BarEntrance extends StatefulWidget {
  final Widget child;

  const _BarEntrance({super.key, required this.child});

  @override
  State<_BarEntrance> createState() => _BarEntranceState();
}

class _BarEntranceState extends State<_BarEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TemplateEntrance(animation: templateInterval(_c, 0, 1), animationController: _c, child: widget.child);
}
