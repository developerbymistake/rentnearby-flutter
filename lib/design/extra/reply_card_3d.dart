import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';
import 'status_pill.dart';

const BorderRadius _kCardRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

class ReplyRow {
  const ReplyRow(this.label, this.value, {this.done, this.step});

  final String label;
  final String value;
  final bool? done;
  final int? step;
}

class ReplyAction {
  const ReplyAction({required this.label, this.onTap, this.busy = false, this.itemKey});

  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final Key? itemKey;
}

class ReplyCard3D extends StatelessWidget {
  const ReplyCard3D({
    super.key,
    required this.status,
    required this.art,
    required this.pill,
    required this.title,
    this.urgent = false,
    this.statusLine,
    this.cap,
    this.number,
    this.unit,
    this.onMenu,
    this.menuKey,
    this.rows = const [],
    this.tag,
    this.note,
    this.noteArt,
    this.noteAction,
    this.onNoteAction,
    this.primary,
    this.secondary = const [null, null],
    this.onTap,
    this.tone,
    this.semanticsLabel,
    this.emptyNote = 'No update yet',
    this.emptyPrimary = 'Not available',
    this.emptyCell = 'Not now',
  });

  final StatusTone3D status;
  final String art;
  final String pill;
  final String title;
  final bool urgent;
  final String? statusLine;
  final String? cap;
  final String? number;
  final String? unit;
  final VoidCallback? onMenu;
  final Key? menuKey;
  final List<ReplyRow> rows;
  final String? tag;
  final String? note;
  final String? noteArt;
  final String? noteAction;
  final VoidCallback? onNoteAction;
  final ReplyAction? primary;
  final List<ReplyAction?> secondary;
  final VoidCallback? onTap;
  final ListingTone? tone;
  final String? semanticsLabel;
  final String emptyNote;
  final String emptyPrimary;
  final String emptyCell;

  static const double topRoom = 58;
  static const int rowSlots = 3;

  Widget _row(ReplyRow? r, Color ink) {
    if (r == null) return const SizedBox(height: 22);
    final step = r.step;
    final wide = r.value.isEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 22),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: wide ? 2 : 0),
        child: Row(
          children: [
            if (step != null) ...[
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: Text('$step', textScaler: TextScaler.noScaling, style: Ink3D.text(11, FontWeight.w700, ink, height: 1, letterSpacing: 0)),
              ),
              const SizedBox(width: 8),
            ] else if (r.done != null) ...[
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: r.done! ? Colors.white.withValues(alpha: 0.35) : Colors.white),
                child: r.done! ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: ink)),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(r.label, maxLines: wide ? 3 : 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white, height: wide ? 1.3 : null))),
            if (!wide) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(r.value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: Ink3D.text(12.5, FontWeight.w700, Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _primary(Color ink) {
    final p = primary;
    final live = p != null && p.onTap != null && !p.busy;
    final box = Container(
      height: 44,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: p == null ? Colors.white.withValues(alpha: 0.1) : (live || p.busy ? Colors.white : Colors.white.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: live || (p?.busy ?? false) ? const [BoxShadow(color: Color(0x33000000), offset: Offset(3, 6), blurRadius: 10)] : null,
      ),
      child: p == null
          ? FittedBox(fit: BoxFit.scaleDown, child: Text(emptyPrimary, maxLines: 1, softWrap: false, style: Ink3D.text(14.5, FontWeight.w700, Colors.white.withValues(alpha: 0.55))))
          : p.busy
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.6, color: ink))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(p.label, maxLines: 1, softWrap: false, style: Ink3D.text(14.5, FontWeight.w700, live ? ink : Colors.white)),
            ),
    );
    if (p == null) return ExcludeSemantics(child: box);
    return Tap3D(onTap: live ? p.onTap : null, tapKey: p.itemKey, child: Opacity(opacity: live || p.busy ? 1 : 0.85, child: box));
  }

  Widget _cell(ReplyAction? a) {
    final live = a != null && a.onTap != null && !a.busy;
    final box = Container(
      height: 38,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: live || (a?.busy ?? false) ? 0.26 : 0.1), borderRadius: BorderRadius.circular(19)),
      child: a == null
          ? FittedBox(fit: BoxFit.scaleDown, child: Text(emptyCell, maxLines: 1, softWrap: false, style: Ink3D.text(13, FontWeight.w700, Colors.white.withValues(alpha: 0.45))))
          : a.busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(a.label, maxLines: 1, softWrap: false, style: Ink3D.text(13, FontWeight.w700, Colors.white.withValues(alpha: live ? 1 : 0.55))),
            ),
    );
    if (a == null) return ExcludeSemantics(child: box);
    return Tap3D(onTap: live ? a.onTap : null, tapKey: a.itemKey, child: box);
  }

  @override
  Widget build(BuildContext context) {
    final t = tone ?? status.tone;
    final ink = tone?.button ?? status.pillText;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final roomy = narrow || scale > 1.15;
    final artSize = narrow ? 112.0 : 144.0;
    final left = narrow ? 124.0 : 160.0;
    final cells = [secondary.isNotEmpty ? secondary[0] : null, secondary.length > 1 ? secondary[1] : null];

    final head = Padding(
      padding: EdgeInsets.fromLTRB(left, 12, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24 * scale.clamp(1.0, 1.3),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusPill3D(label: pill, color: ink),
                  if (urgent) ...[const SizedBox(width: 6), const UrgentPill3D()],
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 42 * scale,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Colors.white, height: 21 / 17)),
            ),
          ),
          SizedBox(
            height: (roomy ? 52 : 35) * scale,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(statusLine ?? '', maxLines: roomy ? 3 : 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white.withValues(alpha: 0.96), height: 17 / 12.5)),
            ),
          ),
        ],
      ),
    );

    final price = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cap != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 5),
                        child: Text(cap!.toUpperCase(), textScaler: TextScaler.noScaling, style: Ink3D.text(11, FontWeight.w700, Colors.white.withValues(alpha: 0.9), letterSpacing: 0.5, height: 1)),
                      ),
                    Text(number ?? '', textScaler: TextScaler.noScaling, style: Ink3D.text(26, FontWeight.w500, Colors.white, height: 1.1, letterSpacing: 0)),
                    if (unit != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 5, bottom: 4),
                        child: Text(unit!, textScaler: TextScaler.noScaling, style: Ink3D.text(12, FontWeight.w500, Colors.white, height: 1)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (onMenu == null)
            const SizedBox(width: 38, height: 38)
          else
            Tooltip(
              message: 'More',
              child: Tap3D(
                onTap: onMenu,
                tapKey: menuKey,
                label: 'More',
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(color: Color(0xFFFAFAFA), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x66213333), offset: Offset(6, 6), blurRadius: 8)]),
                  child: Icon(Icons.more_vert_rounded, size: 22, color: ink),
                ),
              ),
            ),
        ],
      ),
    );

    final box = Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < rowSlots; i++) _row(i < rows.length ? rows[i] : null, ink)],
        ),
      ),
    );

    final noteStrip = Container(
      margin: const EdgeInsets.only(top: 10),
      constraints: BoxConstraints(minHeight: 46 * scale.clamp(1.0, 1.3)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: const Color(0x1C000000),
      child: Row(
        children: [
          if (noteArt != null && note != null) ...[Image.asset(noteArt!, width: 20, height: 20, fit: BoxFit.contain), const SizedBox(width: 8)],
          Expanded(
            child: Text(note ?? emptyNote, maxLines: 5, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, note == null ? Colors.white.withValues(alpha: 0.55) : Colors.white, height: 1.35)),
          ),
          if (noteAction != null) ...[
            const SizedBox(width: 8),
            Tap3D(
              onTap: onNoteAction,
              child: Container(
                constraints: const BoxConstraints(minHeight: 28),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Text(noteAction!, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, ink)),
              ),
            ),
          ],
        ],
      ),
    );

    final actions = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _primary(ink),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: _cell(cells[0])), const SizedBox(width: 8), Expanded(child: _cell(cells[1]))]),
        ],
      ),
    );

    Widget card = Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: t.gradient, borderRadius: _kCardRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          price,
          box,
          if (tag != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(tag!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w700, Colors.white.withValues(alpha: 0.95))),
            ),
          noteStrip,
          actions,
        ],
      ),
    );
    card = DecoratedBox(
      decoration: BoxDecoration(borderRadius: _kCardRadius, boxShadow: t.glow()),
      child: card,
    );
    if (onTap != null) card = Tap3D(onTap: onTap, child: card);
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(14, topRoom, 14, 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            left: 6,
            top: narrow ? -40 : -52,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: const Color(0x3DFAFAFA), haloDy: 4, shadowAlpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
    if (semanticsLabel == null) return body;
    return Semantics(container: true, label: semanticsLabel, child: body);
  }
}

class ReplyCardSkeleton extends StatelessWidget {
  const ReplyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final left = narrow ? 124.0 : 160.0;
    Widget bar(double factor, {double h = 14}) => FractionallySizedBox(
      widthFactor: factor,
      alignment: Alignment.centerLeft,
      child: Container(height: h, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(7))),
    );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, ReplyCard3D.topRoom, 14, 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: _kCardRadius,
                gradient: LinearGradient(colors: [Color(0xFFE3E6EE), Color(0xFFEEF0F5), Color(0xFFE3E6EE)], stops: [0.3, 0.5, 0.7]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(left, 8, 18, 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(0.6), bar(0.9, h: 18), bar(0.8), bar(0.5)]),
                  ),
                  Container(height: 76, margin: const EdgeInsets.fromLTRB(20, 56, 20, 0), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14))),
                  Container(height: 40, margin: const EdgeInsets.fromLTRB(20, 12, 20, 0), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14))),
                  Container(height: 44, margin: const EdgeInsets.fromLTRB(20, 14, 20, 0), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(22))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                    child: Row(
                      children: [
                        Expanded(child: Container(height: 38, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(19)))),
                        const SizedBox(width: 8),
                        Expanded(child: Container(height: 38, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(19)))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(left: 4, top: -46, child: Container(width: narrow ? 116 : 148, height: narrow ? 116 : 148, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE3E6EE)))),
          ],
        ),
      ),
    );
  }
}
