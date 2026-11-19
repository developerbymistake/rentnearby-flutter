import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
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

  void _continue(TripBarPick pick) => TripNavigation.continueTrip(pick.trip.id);

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

  static TextStyle get _titleStyle =>
      TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(12.5), fontWeight: FontWeight.w800, color: FitnessAppTheme.white);
  static TextStyle get _lineStyle => TextStyle(
      fontFamily: FitnessAppTheme.fontName,
      fontSize: DS.f(11),
      fontWeight: FontWeight.w600,
      color: FitnessAppTheme.white.withValues(alpha: Alpha.high));
  static TextStyle get _moreStyle =>
      TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(11), fontWeight: FontWeight.w700, color: FitnessAppTheme.white);
  static TextStyle get _continueStyle =>
      TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(11.5), fontWeight: FontWeight.w800, color: FitnessAppTheme.nearlyDarkBlue);

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
      padding: DS.insets(l: 10, r: 10, b: 8),
      child: LayoutBuilder(builder: (context, box) {
        final scaler = MediaQuery.textScalerOf(context);
        final more = pick.more > 0 ? TripStringsBar.more(pick.more) : null;
        final actionsWidth = (more == null ? 0 : DS.gh(6) + DS.s(16) + _textWidth(scaler, more, _moreStyle)) +
            DS.gh(6) +
            DS.s(26) +
            _textWidth(scaler, TripStringsBar.continueAction, _continueStyle);
        final textRoom = box.maxWidth - DS.s(10) - DS.s(40) - DS.gh(6) - DS.s(26) - DS.gh(6) - actionsWidth - DS.s(40);
        final textNeed = [
          _textWidth(scaler, title, _titleStyle),
          _textWidth(scaler, line, _lineStyle),
          scaler.scale(DS.s(120)),
        ].reduce((a, b) => a < b ? a : b);
        final stacked = textRoom < textNeed;
        final actions = <Widget>[
          if (more != null) ...[
            if (!stacked) Gap.h(6),
            GestureDetector(
              onTap: TripNavigation.openMyTrips,
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: BoxConstraints(minHeight: DS.s(32)),
                alignment: Alignment.center,
                padding: DS.sym(h: 8),
                decoration: BoxDecoration(
                  color: FitnessAppTheme.white.withValues(alpha: Alpha.soft),
                  borderRadius: DS.circular(8),
                ),
                child: Text(more, maxLines: 1, softWrap: false, style: _moreStyle),
              ),
            ),
          ],
          if (more != null || !stacked) Gap.h(6),
          Container(
            constraints: BoxConstraints(minHeight: DS.s(32)),
            alignment: Alignment.center,
            padding: DS.sym(h: 13),
            decoration: BoxDecoration(color: FitnessAppTheme.white, borderRadius: DS.circular(8)),
            child: Text(TripStringsBar.continueAction, maxLines: 1, softWrap: false, style: _continueStyle),
          ),
        ];
        final close = IconButton(
          tooltip: TripStringsBar.hideTooltip,
          onPressed: () => _hide(pick),
          visualDensity: VisualDensity.compact,
          constraints: BoxConstraints(minWidth: DS.s(40), minHeight: DS.s(40)),
          icon: Icon(Icons.close_rounded, size: DS.s(18), color: FitnessAppTheme.white),
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
            Gap.h(6),
            TripKit.travelBadge('assets/images/design/travel3d/luggage.png', size: 26, image: 18),
            Gap.h(6),
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
            borderRadius: DS.br(TripKit.cardRadiusSmall),
            child: Ink(
              padding: DS.insets(l: 8, t: 8, r: 2, b: 8),
              decoration: TripKit.cardBox(gradient: TripKit.sky, radius: TripKit.cardRadiusSmall),
              child: stacked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        top,
                        Padding(
                          padding: EdgeInsets.only(top: DS.gv(6), right: DS.s(6)),
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
