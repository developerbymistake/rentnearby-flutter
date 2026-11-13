import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'dialog_3d.dart';
import 'page_header_3d.dart';
import 'pill_buttons_3d.dart';
import 'reply_card_3d.dart';
import 'status_pill.dart';

const BorderRadius _kStripRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

abstract final class RepliesLook {
  static const Color stayPage = Color(0xFFD8EEDA);
  static const Color taxiPage = Color(0xFFFFE3DA);
  static const Color plainPage = Color(0xFFF2F3F8);
  static const Color field = Color(0xFFF2F3F8);
  static const Color ok = Color(0xFF2E7D32);
  static const Color bad = Color(0xFFE0406F);
  static const Color badInk = Color(0xFFB8264F);
  static const Color badSurface = Color(0xFFFFE1EA);
  static const Color warnSurface = Color(0xFFFFF1DE);
  static const Color warnInk = Color(0xFF6A4A1A);
  static const Color muted = Color(0xFF8A8F99);
  static const Color rule = Color(0xFFEEF0F4);

  static Color pageOf(ListingTone tone) {
    if (identical(tone, ListingTone.forest)) return stayPage;
    if (identical(tone, ListingTone.coral)) return taxiPage;
    return plainPage;
  }

  static TextStyle section = Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.6);
  static TextStyle foot = Ink3D.text(12, FontWeight.w400, muted, height: 1.45, letterSpacing: 0);
}

class RepliesScaffold extends StatelessWidget {
  const RepliesScaffold({super.key, required this.tone, required this.title, required this.art, required this.body, this.subtitle, this.leg, this.onBack, this.top});

  final ListingTone tone;
  final String title;
  final String? subtitle;
  final String art;
  final String? leg;
  final VoidCallback? onBack;
  final Widget? top;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final legText = leg;
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    return Scaffold(
      backgroundColor: RepliesLook.pageOf(tone),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader3D(
              tone: tone,
              title: title,
              subtitle: subtitle,
              art: art,
              artSize: narrow ? 104 : 116,
              inlineTitle: true,
              onBack: onBack,
              bottom: legText == null
                  ? null
                  : Padding(
                      padding: EdgeInsets.fromLTRB(18 + PageHeader3D.buttonSize + 12, 0, 18, 0),
                      child: Align(alignment: Alignment.centerLeft, child: RepliesLegPill(tone: tone, text: legText)),
                    ),
            ),
            ?top,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class RepliesLegPill extends StatelessWidget {
  const RepliesLegPill({super.key, required this.tone, required this.text});

  final ListingTone tone;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
    decoration: BoxDecoration(gradient: tone.gradient, borderRadius: BorderRadius.circular(12), boxShadow: tone.glow(blur: 6, dy: 3)),
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w700, Colors.white, letterSpacing: 0)),
  );
}

class ReplySummaryStrip extends StatelessWidget {
  const ReplySummaryStrip({super.key, required this.tone, required this.title, this.value = '', this.subtitle, this.trailing, this.margin = const EdgeInsets.only(top: 14)});

  final ListingTone tone;
  final String title;
  final String? subtitle;
  final String value;
  final Widget? trailing;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: _kStripRadius, boxShadow: tone.glow(dy: 4)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, Colors.white, height: 1.3, letterSpacing: 0)),
                if (sub != null && sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white, height: 1.3, letterSpacing: 0)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing ??
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(value, maxLines: 1, style: Ink3D.text(22, FontWeight.w700, Colors.white, letterSpacing: 0))),
              ),
        ],
      ),
    );
  }
}

class ArtPillButton extends StatelessWidget {
  const ArtPillButton({super.key, required this.tone, required this.art, required this.label, required this.onTap, this.margin = const EdgeInsets.fromLTRB(18, 30, 18, 0), this.tapKey});

  final ListingTone tone;
  final String art;
  final String label;
  final VoidCallback? onTap;
  final EdgeInsets margin;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final live = onTap != null;
    return Padding(
      padding: margin,
      child: Tap3D(
        onTap: onTap,
        label: label,
        tapKey: tapKey,
        exclude: true,
        child: Opacity(
          opacity: live ? 1 : 0.5,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 54),
                padding: const EdgeInsets.fromLTRB(80, 12, 24, 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: tone.gradient, borderRadius: BorderRadius.circular(27), boxShadow: live ? Form3D.glow(tone) : null),
                child: Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, Colors.white, letterSpacing: 0)),
              ),
              Positioned(left: 14, top: -14, child: Art3D(asset: art, size: 60, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
            ],
          ),
        ),
      ),
    );
  }
}

class RepliesEmpty extends StatelessWidget {
  const RepliesEmpty({super.key, required this.tone, required this.art, required this.title, this.message, this.actionLabel, this.onAction, this.actionArt = ListingArt.compass, this.topPad = 40});

  final ListingTone tone;
  final String art;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String actionArt;
  final double topPad;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final size = narrow ? 160.0 : 200.0;
    final msg = message;
    final label = actionLabel;
    return Padding(
      padding: EdgeInsets.fromLTRB(26, topPad, 26, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Art3D(asset: art, size: size, halo: size - 12, haloColor: tone.halo, shadowBlur: 10, shadowOffset: const Offset(8, 12))),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: Ink3D.text(24, FontWeight.w700, Ink3D.title, height: 1.25, letterSpacing: 0)),
          if (msg != null && msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(msg, textAlign: TextAlign.center, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.copy, height: 1.45, letterSpacing: 0)),
            ),
          if (label != null) ArtPillButton(tone: tone, art: actionArt, label: label, onTap: onAction, margin: const EdgeInsets.fromLTRB(4, 28, 4, 0)),
        ],
      ),
    );
  }
}

class RepliesBanner extends StatelessWidget {
  const RepliesBanner({super.key, required this.art, required this.text, this.actionLabel, this.onAction, this.bad = false, this.margin = const EdgeInsets.fromLTRB(18, 14, 18, 0)});

  final String art;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool bad;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final ink = bad ? RepliesLook.badInk : RepliesLook.warnInk;
    final label = actionLabel;
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(color: bad ? RepliesLook.badSurface : RepliesLook.warnSurface, borderRadius: _kStripRadius, boxShadow: Form3D.cardShadow),
      child: Row(
        children: [
          Image.asset(art, width: 34, height: 34, fit: BoxFit.contain),
          const SizedBox(width: 10),
          Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w500, ink, height: 1.35, letterSpacing: 0))),
          if (label != null)
            Tap3D(
              onTap: onAction,
              label: label,
              exclude: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(widthFactor: 1, child: Text(label, maxLines: 1, style: Ink3D.text(14, FontWeight.w700, ink, letterSpacing: 0))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ResultRow3D extends StatelessWidget {
  const ResultRow3D({super.key, required this.art, required this.title, required this.label, this.subtitle, this.ok = true, this.divider = true});

  final String art;
  final String title;
  final String? subtitle;
  final String label;
  final bool ok;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: BoxDecoration(border: divider ? const Border(bottom: BorderSide(color: RepliesLook.rule)) : null),
      child: Row(
        children: [
          Image.asset(art, width: 30, height: 30, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                if (sub != null && sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, RepliesLook.muted, letterSpacing: 0)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(label, maxLines: 2, textAlign: TextAlign.right, style: Ink3D.text(12.5, FontWeight.w700, ok ? RepliesLook.ok : Ink3D.grey, letterSpacing: 0)),
          ),
        ],
      ),
    );
  }
}

class NameChips3D extends StatelessWidget {
  const NameChips3D({super.key, required this.items, this.tone});

  final List<(String, String)> items;
  final ListingTone? tone;

  @override
  Widget build(BuildContext context) {
    final t = tone;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (art, name) in items)
          Container(
            padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
            decoration: BoxDecoration(color: t?.tint ?? RepliesLook.field, borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(art, width: 22, height: 22, fit: BoxFit.contain),
                const SizedBox(width: 6),
                Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w700, t?.text ?? Ink3D.body, letterSpacing: 0))),
              ],
            ),
          ),
      ],
    );
  }
}

class GreyPillBox extends StatelessWidget {
  const GreyPillBox({super.key, required this.child, this.margin = const EdgeInsets.only(top: 12), this.padding = const EdgeInsets.fromLTRB(18, 10, 12, 10), this.radius = 30});

  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    constraints: const BoxConstraints(minHeight: 54),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(color: RepliesLook.field, borderRadius: BorderRadius.circular(radius)),
    child: child,
  );
}

Future<void> showReplyMenu(GlobalKey anchorKey, List<MenuItem3D> items) async {
  final ctx = anchorKey.currentContext;
  final box = ctx?.findRenderObject();
  if (ctx == null || box is! RenderBox || !box.attached || items.isEmpty) return;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  await showMenu3D(ctx, anchor: rect, items: items);
}

class ProblemOption3D extends StatelessWidget {
  const ProblemOption3D({super.key, required this.tone, required this.art, required this.label, required this.onTap, this.selected = false, this.busy = false});

  final ListingTone tone;
  final String art;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool busy;

  static const BorderRadius _radius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final size = narrow ? 70.0 : 88.0;
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Tap3D(
        onTap: onTap,
        label: label,
        selected: selected,
        exclude: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: BoxConstraints(minHeight: narrow ? 70 : 80),
              padding: EdgeInsets.fromLTRB(size + 28, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: tone.gradient,
                borderRadius: _radius,
                border: selected ? Border.all(color: Colors.white, width: 3) : null,
                boxShadow: tone.glow(blur: selected ? 14 : 8),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, Colors.white, height: 1.3, letterSpacing: 0))),
                  const SizedBox(width: 8),
                  if (busy)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  else
                    Icon(selected ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: 26, color: Colors.white),
                ],
              ),
            ),
            Positioned(
              left: 10,
              top: narrow ? -20 : -28,
              child: IgnorePointer(child: Art3D(asset: art, size: size, halo: size + 6, haloColor: const Color(0x38FFFFFF), shadowBlur: 5, shadowOffset: const Offset(4, 6))),
            ),
          ],
        ),
      ),
    );
  }
}

class CandidateRow3D extends StatelessWidget {
  const CandidateRow3D({super.key, required this.title, required this.onTap, this.subtitle, this.warn});

  final String title;
  final String? subtitle;
  final String? warn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    final w = warn;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Tap3D(
        onTap: onTap,
        label: title,
        exclude: true,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: Form3D.cardShadow),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
              if (sub != null && sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, RepliesLook.muted, letterSpacing: 0)),
              if (w != null) Text(w, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w500, Form3D.amber, height: 1.35, letterSpacing: 0)),
            ],
          ),
        ),
      ),
    );
  }
}

const BorderRadius _kChatCardRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

class ChatTripCard3D extends StatelessWidget {
  const ChatTripCard3D({
    super.key,
    required this.status,
    required this.art,
    required this.pill,
    required this.title,
    this.line,
    this.rows = const [],
    this.extra = const [],
    this.note,
    this.noteArt,
    this.noteAction,
    this.onNoteAction,
    this.primary,
    this.secondary,
    this.showActions = true,
    this.mine = false,
    this.read = false,
    this.dimmed = false,
  });

  final StatusTone3D status;
  final String art;
  final String pill;
  final String title;
  final String? line;
  final List<ReplyRow> rows;
  final List<String> extra;
  final String? note;
  final String? noteArt;
  final String? noteAction;
  final VoidCallback? onNoteAction;
  final ReplyAction? primary;
  final ReplyAction? secondary;
  final bool showActions;
  final bool mine;
  final bool read;
  final bool dimmed;

  static const double topRoom = 58;

  Widget _row(ReplyRow? r, Color ink) {
    if (r == null) return const SizedBox(height: 22);
    final done = r.done;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 22),
      child: Row(
        children: [
          if (done != null) ...[
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: done ? Colors.white.withValues(alpha: 0.35) : Colors.white),
              child: done ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: ink)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white, height: 1.3))),
          if (r.value.isNotEmpty) ...[
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(r.value, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: Ink3D.text(12.5, FontWeight.w700, Colors.white, height: 1.3)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _button(ReplyAction? a, {required bool primary, required Color ink}) {
    final live = a != null && a.onTap != null && !a.busy;
    final busy = a?.busy ?? false;
    final Color fill = primary ? (live || busy ? Colors.white : Colors.white.withValues(alpha: 0.28)) : Colors.white.withValues(alpha: live || busy ? 0.26 : 0.1);
    final Color text = primary && live ? ink : Colors.white.withValues(alpha: live ? 1 : 0.55);
    final box = Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(24),
        boxShadow: primary && live ? const [BoxShadow(color: Color(0x33000000), offset: Offset(3, 6), blurRadius: 10)] : null,
      ),
      child: a == null
          ? const SizedBox.shrink()
          : busy
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: primary ? ink : Colors.white))
          : Text(a.label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, text, height: 1.15, letterSpacing: 0)),
    );
    if (a == null) return ExcludeSemantics(child: box);
    return Tap3D(onTap: live ? a.onTap : null, tapKey: a.itemKey, label: a.label, exclude: true, child: box);
  }

  @override
  Widget build(BuildContext context) {
    final t = dimmed ? StatusTone3D.closed.tone : status.tone;
    final ink = t.button;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final roomy = narrow || scale > 1.15;
    final artSize = narrow ? 112.0 : 144.0;
    final left = narrow ? 124.0 : 160.0;
    final noteText = note;
    final action = noteAction;

    final head = Padding(
      padding: EdgeInsets.fromLTRB(left, 14, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24 * scale.clamp(1.0, 1.3),
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: StatusPill3D(label: pill, color: ink)),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: (roomy ? 66 : 44) * scale,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(title, maxLines: roomy ? 3 : 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Colors.white, height: 22 / 17, letterSpacing: 0)),
            ),
          ),
          SizedBox(
            height: (roomy ? 54 : 36) * scale,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(line ?? '', maxLines: roomy ? 3 : 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white.withValues(alpha: 0.96), height: 18 / 12.5, letterSpacing: 0)),
            ),
          ),
        ],
      ),
    );

    final slots = rows.length < 3 ? 3 : rows.length;
    final box = Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < slots; i++) _row(i < rows.length ? rows[i] : null, ink)],
      ),
    );

    final noteStrip = Container(
      margin: const EdgeInsets.only(top: 10),
      constraints: BoxConstraints(minHeight: 46 * scale.clamp(1.0, 1.3)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: const Color(0x1C000000),
      child: Row(
        children: [
          if (noteText != null) ...[Image.asset(noteArt ?? ListingArt.clipboard, width: 20, height: 20, fit: BoxFit.contain), const SizedBox(width: 8)],
          Expanded(
            child: Text(noteText ?? '', maxLines: 5, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white, height: 1.35, letterSpacing: 0)),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            Tap3D(
              onTap: onNoteAction,
              label: action,
              exclude: true,
              child: Container(
                constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: onNoteAction == null ? 0.4 : 1), borderRadius: BorderRadius.circular(16)),
                child: Text(action, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, ink, letterSpacing: 0)),
              ),
            ),
          ],
        ],
      ),
    );

    final card = DecoratedBox(
      decoration: BoxDecoration(borderRadius: _kChatCardRadius, boxShadow: dimmed ? null : t.glow()),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(gradient: t.gradient, borderRadius: _kChatCardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            head,
            box,
            for (final x in extra)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(x, maxLines: 4, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, Colors.white, height: 1.35, letterSpacing: 0)),
              ),
            noteStrip,
            if (showActions)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_button(primary, primary: true, ink: ink), const SizedBox(height: 10), _button(secondary, primary: false, ink: ink)],
                      )
                    : IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _button(primary, primary: true, ink: ink)),
                            const SizedBox(width: 10),
                            Expanded(child: _button(secondary, primary: false, ink: ink)),
                          ],
                        ),
                      ),
              ),
            if (mine)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 18, 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(read ? Icons.done_all_rounded : Icons.done_rounded, size: 15, color: Colors.white.withValues(alpha: read ? 1 : 0.8)),
                ),
              )
            else
              const SizedBox(height: 18),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, topRoom, 0, 6),
      child: Opacity(
        opacity: dimmed ? 0.8 : 1,
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
      ),
    );
  }
}

class BucketChip3D extends StatelessWidget {
  const BucketChip3D({super.key, required this.tone, required this.art, required this.label, this.off = false, this.onTap});

  final ListingTone tone;
  final String art;
  final String label;
  final bool off;
  final VoidCallback? onTap;

  static const BorderRadius _radius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final artSize = narrow ? 44.0 : 58.0;
    return Tap3D(
      onTap: onTap,
      label: label,
      selected: !off,
      exclude: true,
      child: Opacity(
        opacity: off ? 0.62 : 1,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: _radius, gradient: tone.gradient, boxShadow: off ? const [] : tone.glow(blur: 8)),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(artSize + 4, 12, narrow ? 8 : 12, 12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(narrow ? 12.5 : 14, FontWeight.w700, Colors.white, letterSpacing: 0)),
                  ),
                ),
              ),
            ),
            Positioned(left: 4, top: narrow ? 6 : 0, child: IgnorePointer(child: Art3D(asset: art, size: artSize, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28))),
          ],
        ),
      ),
    );
  }
}
