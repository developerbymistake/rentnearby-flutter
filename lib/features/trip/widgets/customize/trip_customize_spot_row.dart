import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/trip_plan_model.dart';
import '../../trip_strings_customize.dart';
import '../../utils/trip_format.dart';

class TripPlaceDrag {
  final String spotId;
  final int day;

  const TripPlaceDrag(this.spotId, this.day);
}

class TripCustomizeSpotRow extends StatelessWidget {
  static const double _removeFont = 12.5;
  static const double _removeWidth = 128;
  static const double _minNameRoom = 90;
  static const double liftedHeight = 68;

  final TripSpotRef spot;
  final int day;
  final int index;
  final Color color;
  final String time;
  final int? driveMinutes;
  final bool frozen;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onDragStarted;
  final DragUpdateCallback? onDragUpdate;
  final VoidCallback? onDragEnd;
  final ValueListenable<bool>? liftHidden;
  final bool preview;

  const TripCustomizeSpotRow({
    super.key,
    required this.spot,
    required this.day,
    required this.index,
    required this.color,
    required this.time,
    required this.driveMinutes,
    this.frozen = false,
    this.selected = false,
    this.onTap,
    this.onRemove,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDragEnd,
    this.liftHidden,
    this.preview = false,
  });

  static double timeWidth(BuildContext context) => MediaQuery.textScalerOf(context).scale(DS.s(66));

  @override
  Widget build(BuildContext context) {
    final timeW = timeWidth(context);
    if (preview) return _Lifted(child: _body(context, timeW, handle: true, lifted: true));
    final drive = (driveMinutes ?? 0) > 0 ? driveMinutes : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        frozen ? _body(context, timeW, handle: false) : _draggable(context, timeW),
        if (drive != null)
          Padding(
            padding: EdgeInsets.only(left: DS.s(20) + timeW),
            child: Container(
              padding: EdgeInsets.only(left: DS.s(18), top: DS.s(3), bottom: DS.s(3)),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: DesignColors.driveLine, width: DS.s(2))),
              ),
              child: Row(
                children: [
                  const Art3D(asset: ListingArt.taxi, size: 16, shadowBlur: 0, shadowOffset: Offset.zero, shadowAlpha: 0),
                  Gap.h(8),
                  Flexible(
                    child: Text(TripFormat.duration(drive), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _draggable(BuildContext context, double timeW) {
    return LayoutBuilder(
      builder: (context, box) => LongPressDraggable<TripPlaceDrag>(
        key: ValueKey('customize-drag-${spot.id}'),
        data: TripPlaceDrag(spot.id, day),
        hapticFeedbackOnStart: true,
        onDragStarted: onDragStarted,
        onDragUpdate: onDragUpdate,
        onDragEnd: (_) => onDragEnd?.call(),
        feedback: _HideWhen(
          hidden: liftHidden,
          child: _Lifted(width: box.maxWidth, scale: 1.03, child: _body(context, timeW, handle: true, lifted: true)),
        ),
        childWhenDragging: _MovedAway(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: _body(context, timeW, handle: true),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, double timeW, {required bool handle, bool lifted = false}) {
    return ConstrainedBox(
      key: lifted ? null : ValueKey('customize-row-${spot.id}'),
      constraints: BoxConstraints(minHeight: DS.s(60)),
      child: Padding(
        padding: DS.insets(l: 12, t: lifted ? 12 : 8, r: 8, b: lifted ? 12 : 8),
        child: LayoutBuilder(
          builder: (context, box) => _line(timeW, box.maxWidth, handle: handle, lifted: lifted),
        ),
      ),
    );
  }

  Widget _line(double timeW, double width, {required bool handle, required bool lifted}) {
    final removing = selected && !lifted;
    final nameRoom = width - timeW - DS.s(26 + 12 + 40 + 12 + _removeWidth);
    final showArt = !removing || nameRoom >= DS.s(_minNameRoom);
    return Row(
      children: [
        SizedBox(
          width: timeW,
          child: Text(time, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w600, Ink3D.sub)),
        ),
        Container(
          width: DS.s(26),
          height: DS.s(26),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text('${index + 1}', style: Ink3D.text(12.5, FontWeight.w700, DesignColors.surface)),
        ),
        Gap.h(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(spot.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title)),
              Text(
                TripStringsCustomize.spotLine(spot.category, spot.visitMinutes),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText),
              ),
            ],
          ),
        ),
        if (showArt)
          Padding(
            padding: EdgeInsets.only(left: DS.s(10)),
            child: Art3D(asset: TripSpotLook.assetOf(spot.category), size: 30, shadowBlur: 2, shadowOffset: const Offset(1, 3)),
          ),
        if (removing)
          Padding(
            padding: DS.insets(l: 8, t: 4, r: 4, b: 4),
            child: SizedBox(
              width: DS.s(_removeWidth),
              child: GradientPillButton(
                key: ValueKey('customize-remove-${spot.id}'),
                tone: ListingTone.coral,
                label: TripStringsCustomize.removeFromTrip,
                height: 44,
                fontSize: _removeFont,
                shadows: TripCustomizeLook.removeShadow,
                onTap: onRemove,
              ),
            ),
          )
        else ...[
          if (handle)
            Semantics(
              label: TripStringsCustomize.holdToMove,
              child: SizedBox.square(dimension: DS.s(TripGripDots.box), child: const Center(child: TripGripDots())),
            )
          else
            Gap.h(8),
        ],
      ],
    );
  }
}

class TripGripDots extends StatelessWidget {
  static const double box = 40;

  const TripGripDots({super.key});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: DS.s(5),
      height: DS.s(5),
      decoration: const BoxDecoration(color: DesignColors.gripDot, shape: BoxShape.circle),
    );
    Widget pair() => Row(mainAxisSize: MainAxisSize.min, children: [dot, Gap.h(4), dot]);
    return Column(mainAxisSize: MainAxisSize.min, children: [pair(), Gap.v(4), pair(), Gap.v(4), pair()]);
  }
}

class _HideWhen extends StatelessWidget {
  final ValueListenable<bool>? hidden;
  final Widget child;

  const _HideWhen({required this.hidden, required this.child});

  @override
  Widget build(BuildContext context) {
    final h = hidden;
    if (h == null) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: h,
      builder: (context, off, child) => Visibility(visible: !off, maintainSize: true, maintainAnimation: true, maintainState: true, child: child!),
      child: child,
    );
  }
}

class _Lifted extends StatelessWidget {
  final double? width;
  final double scale;
  final Widget child;

  const _Lifted({this.width, this.scale = 1, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: DS.circular(12),
            border: Border.all(color: ListingPalette.indigo.line, width: DS.s(1.5)),
            boxShadow: DS.shadows(TripCustomizeLook.liftShadow),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MovedAway extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: DS.sym(h: 14, v: 10),
      child: CustomPaint(
        painter: TripDashBox(TripLook.disabledFill, DS.s(1), fill: DesignColors.surface),
        child: Padding(
          padding: DS.all(14),
          child: Text(
            TripStringsCustomize.placeMovedAway,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText),
          ),
        ),
      ),
    );
  }
}

class TripCustomizeDashedNote extends StatelessWidget {
  final String text;

  const TripCustomizeDashedNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TripDashBox(TripLook.disabledFill, DS.s(1), fill: DesignColors.scaffold),
      child: Padding(
        padding: DS.sym(h: 12, v: 14),
        child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText)),
      ),
    );
  }
}

class TripDashBox extends CustomPainter {
  final Color line;
  final double unit;
  final Color? fill;
  final BorderRadius? radius;
  final double stroke;

  const TripDashBox(this.line, this.unit, {this.fill, this.radius, this.stroke = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke * unit / 2);
    final box = (radius ?? BorderRadius.all(Radius.circular(12 * unit))).toRRect(rect);
    final f = fill;
    if (f != null) canvas.drawRRect(box, Paint()..color = f);
    final pen = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * unit;
    final path = Path()..addRRect(box);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6 * unit), pen);
        d += 11 * unit;
      }
    }
  }

  @override
  bool shouldRepaint(TripDashBox old) =>
      old.line != line || old.unit != unit || old.fill != fill || old.radius != radius || old.stroke != stroke;
}
