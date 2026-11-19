import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
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
  static const double _removeFont = 12;

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
  });

  static double timeWidth(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(DS.s(MediaQuery.sizeOf(context).width < Form3D.narrow ? 52 : 60));

  @override
  Widget build(BuildContext context) {
    final timeW = timeWidth(context);
    final drive = (driveMinutes ?? 0) > 0 ? driveMinutes : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        frozen ? _body(context, timeW, handle: false) : _draggable(context, timeW),
        if (drive != null)
          Padding(
            padding: EdgeInsets.only(left: timeW + DS.s(12)),
            child: Container(
              padding: EdgeInsets.only(left: DS.s(19), top: DS.s(2), bottom: DS.s(2)),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: color.withValues(alpha: Alpha.scrim), width: DS.s(2))),
              ),
              child: Row(
                children: [
                  const Art3D(asset: ListingArt.taxi, size: 16, shadowBlur: 0),
                  Gap.h(6),
                  Flexible(
                    child: Text(TripFormat.duration(drive), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey)),
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
        feedback: _Lifted(width: box.maxWidth, child: _body(context, timeW, handle: true, lifted: true)),
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
      constraints: BoxConstraints(minHeight: DS.s(52)),
      child: Padding(
        padding: DS.sym(v: 4, h: lifted ? 10 : 0),
        child: Row(
          children: [
            SizedBox(
              width: timeW,
              child: Text(time, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w600, Ink3D.sub)),
            ),
            Container(
              width: DS.s(26),
              height: DS.s(26),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text('${index + 1}', style: Ink3D.text(11.5, FontWeight.w700, DesignColors.surface)),
            ),
            Gap.h(10),
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
                    style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey),
                  ),
                ],
              ),
            ),
            if (selected && !lifted)
              Flexible(
                child: GradientPillButton(
                  key: ValueKey('customize-remove-${spot.id}'),
                  tone: ListingTone.indigo,
                  label: TripStringsCustomize.removeFromTrip,
                  danger: true,
                  expand: false,
                  height: 38,
                  fontSize: _removeFont,
                  onTap: onRemove,
                ),
              )
            else ...[
              Padding(
                padding: EdgeInsets.only(left: DS.s(6)),
                child: Art3D(asset: TripSpotLook.assetOf(spot.category), size: 34, shadowBlur: 2, shadowOffset: const Offset(1, 3)),
              ),
              if (handle)
                Semantics(
                  label: TripStringsCustomize.holdToMove,
                  child: Padding(
                    padding: EdgeInsets.only(left: DS.s(6)),
                    child: Icon(Icons.drag_indicator_rounded, size: DS.s(24), color: TripLook.textHint),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Lifted extends StatelessWidget {
  final double width;
  final Widget child;

  const _Lifted({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Transform.scale(
        scale: 1.03,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: DS.circular(14),
            boxShadow: DS.shadows(Form3D.onCard),
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
      padding: DS.sym(v: 4),
      child: CustomPaint(
        painter: _DashBox(Form3D.outline, DS.s(1)),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(48)),
          child: Center(
            child: Padding(
              padding: DS.sym(h: 12, v: 8),
              child: Text(
                TripStringsCustomize.placeMovedAway,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(12.5, FontWeight.w500, Ink3D.grey),
              ),
            ),
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
      painter: _DashBox(Form3D.outline, DS.s(1), fill: Form3D.limit),
      child: Padding(
        padding: DS.sym(h: 12, v: 14),
        child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.sub)),
      ),
    );
  }
}

class _DashBox extends CustomPainter {
  final Color line;
  final double unit;
  final Color? fill;

  const _DashBox(this.line, this.unit, {this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius((Offset.zero & size).deflate(unit), Radius.circular(12 * unit));
    final f = fill;
    if (f != null) canvas.drawRRect(box, Paint()..color = f);
    final pen = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * unit;
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
  bool shouldRepaint(_DashBox old) => old.line != line || old.unit != unit || old.fill != fill;
}
