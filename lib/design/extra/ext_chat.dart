import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'pill_buttons_3d.dart';

abstract final class ChatLook3D {
  static const Color bannerFill = Color(0xFFFFF1DE);
  static const Color bannerText = Color(0xFF6A4A1A);
  static const Color red = Color(0xFFE0525C);
  static const Color redBorder = Color(0x59E0525C);
  static const Color outline = Color(0xFFE6E8EE);
  static const Color divider = Color(0xFFEEF0F4);
  static const Color strip = Color(0x1F000000);
  static const Color avatarHalo = Color(0x3DFAFAFA);
  static const Color headerButton = Color(0x38FFFFFF);
  static const Color headerHalo = Color(0x2EFFFFFF);
  static const Color avatarFill = Color(0x40FFFFFF);
  static const Color avatarRing = Color(0xB3FFFFFF);
  static const Color skeleton = Color(0xFFE2E9E3);
  static const Color askedPill = Color(0xFF9A5B00);
  static const Color skeletonBone = Color(0xFFD3DCD5);
  static const Color skeletonRing = Color(0xFFEEF2EF);
  static const Color skeletonStrip = Color(0x0A000000);
  static const List<BoxShadow> grey = [BoxShadow(color: Color(0x599E9E9E), offset: Offset(3, 5), blurRadius: 10)];
  static const List<BoxShadow> card = [BoxShadow(color: Color(0x409E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)];
  static const List<BoxShadow> panel = [BoxShadow(color: Color(0x26000000), offset: Offset(0, -4), blurRadius: 20)];
  static const List<BoxShadow> badge = [BoxShadow(color: Color(0x38000000), offset: Offset(3, 5), blurRadius: 8)];
  static const List<BoxShadow> avatar = [BoxShadow(color: Color(0x4D000000), offset: Offset(4, 8), blurRadius: 12)];
  static const LinearGradient avatarGradient = LinearGradient(
    colors: [Color(0xFF81C784), Color(0xFF1B5E20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ListingTone toneFor(String listingType) => switch (listingType) {
    'Taxi' => ListingTone.coral,
    'Stay' => ListingTone.forest,
    _ => ListingTone.forest,
  };

  static String artFor(String listingType) => switch (listingType) {
    'Stay' => ListingArt.hotel,
    'Taxi' => ListingArt.taxi,
    _ => ListingArt.compass,
  };

  static String initialOf(String name) => name.isNotEmpty ? name[0].toUpperCase() : '?';

  static List<BoxShadow> glow(ListingTone tone, {double alpha = 0.5, double blur = 10, Offset offset = const Offset(1.1, 4)}) => [
    BoxShadow(
      color: tone.haloBase.withValues(alpha: alpha),
      offset: offset,
      blurRadius: blur,
    ),
  ];
}

const BorderRadius _kRow = BorderRadius.only(
  topLeft: Radius.circular(8),
  topRight: Radius.circular(54),
  bottomLeft: Radius.circular(8),
  bottomRight: Radius.circular(8),
);
const BorderRadius _kChip = BorderRadius.only(
  topLeft: Radius.circular(8),
  topRight: Radius.circular(24),
  bottomLeft: Radius.circular(8),
  bottomRight: Radius.circular(8),
);

double _scale(BuildContext context) => MediaQuery.textScalerOf(context).scale(1);

typedef ChatMenuTap = void Function(Rect anchor);

Rect chatRectOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}

class ChatRoundButton3D extends StatelessWidget {
  const ChatRoundButton3D({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.tone,
    this.gradient = false,
    this.glass = false,
    this.size = 44,
    this.tapKey,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final ListingTone? tone;
  final bool gradient;
  final bool glass;
  final double size;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.forest;
    final ink = gradient || glass ? Colors.white : t.text;
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Tap3D(
        onTap: onTap,
        label: tooltip,
        exclude: true,
        tapKey: tapKey,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: glass ? ChatLook3D.headerButton : (gradient ? null : Colors.white),
            gradient: gradient ? t.gradient : null,
            boxShadow: glass ? null : (gradient ? ChatLook3D.glow(t, offset: const Offset(3, 6)) : Ink3D.softShadow),
          ),
          child: Icon(icon, size: size * 0.55, color: ink),
        ),
      ),
    );
  }
}

class ChatThreadCard extends StatelessWidget {
  const ChatThreadCard({
    super.key,
    required this.tone,
    required this.initial,
    required this.sticker,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.preview,
    this.unread = '',
    this.dimmed = false,
    this.onTap,
  }) : skeleton = false;

  const ChatThreadCard.skeleton({super.key})
    : tone = null,
      initial = '',
      sticker = '',
      tag = '',
      title = '',
      subtitle = '',
      time = '',
      preview = '',
      unread = '',
      dimmed = false,
      onTap = null,
      skeleton = true;

  final ListingTone? tone;
  final String initial;
  final String sticker;
  final String tag;
  final String title;
  final String subtitle;
  final String time;
  final String preview;
  final String unread;
  final bool dimmed;
  final VoidCallback? onTap;
  final bool skeleton;

  static const double topRoom = 44;

  Widget _bone(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: ChatLook3D.skeletonBone, borderRadius: BorderRadius.circular(h / 2)),
  );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final av = narrow ? 72.0 : 88.0;
    final left = narrow ? 102.0 : 124.0;
    final right = narrow ? 70.0 : 72.0;
    final tagRight = narrow ? 52.0 : 56.0;
    final t = tone ?? ListingTone.forest;
    final hasBadge = unread.isNotEmpty;
    final head = ConstrainedBox(
      constraints: BoxConstraints(minHeight: 94 * _scale(context).clamp(1.0, 1.6)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(left, 14, 0, 12),
        child: skeleton
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_bone(42, 12), const SizedBox(height: 10), _bone(118, 16), const SizedBox(height: 10), _bone(150, 11)],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: tagRight),
                    child: Text(
                      tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(10, FontWeight.w700, Colors.white.withValues(alpha: 0.92), letterSpacing: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(right: right),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(title, maxLines: 1, softWrap: false, style: Ink3D.text(narrow ? 16 : 18, FontWeight.w700, Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white.withValues(alpha: 0.95))),
                  ),
                ],
              ),
      ),
    );
    final strip = Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 42 * _scale(context).clamp(1.0, 1.6)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      alignment: Alignment.centerLeft,
      color: skeleton ? ChatLook3D.skeletonStrip : ChatLook3D.strip,
      child: skeleton
          ? _bone(210, 11)
          : Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, hasBadge ? FontWeight.w700 : FontWeight.w400, Colors.white)),
    );
    final side = Positioned(
      right: 16,
      top: 14,
      child: SizedBox(
        width: 46,
        child: Column(
          children: [
            skeleton ? _bone(28, 11) : Text(time, maxLines: 1, style: Ink3D.text(12, FontWeight.w600, Colors.white, height: 1.2)),
            const SizedBox(height: 6),
            if (hasBadge)
              Container(
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: ChatLook3D.badge),
                child: Center(widthFactor: 1, heightFactor: 1, child: Text(unread, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, t.g2, letterSpacing: 0))),
              )
            else
              const SizedBox(height: 28),
          ],
        ),
      ),
    );
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _kRow,
        color: skeleton ? ChatLook3D.skeleton : null,
        gradient: skeleton ? null : t.gradient,
        boxShadow: skeleton || dimmed ? null : ChatLook3D.glow(t, alpha: 0.55),
      ),
      child: ClipRRect(
        borderRadius: _kRow,
        child: Stack(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, strip]),
            side,
          ],
        ),
      ),
    );
    final halo = av + 16;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(14, topRoom, 14, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            left: 6,
            top: -30,
            child: ExcludeSemantics(
              child: Container(
                width: halo,
                height: halo,
                decoration: BoxDecoration(shape: BoxShape.circle, color: skeleton ? Colors.white.withValues(alpha: 0.5) : ChatLook3D.avatarHalo),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: -22,
            child: ExcludeSemantics(
              child: Container(
                width: av,
                height: av,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: skeleton ? ChatLook3D.skeletonBone : null,
                  gradient: skeleton ? null : ChatLook3D.avatarGradient,
                  border: Border.all(color: skeleton ? ChatLook3D.skeletonRing : Colors.white, width: 4),
                  boxShadow: skeleton ? null : ChatLook3D.avatar,
                ),
                child: skeleton
                    ? null
                    : Text(initial, textScaler: TextScaler.noScaling, style: Ink3D.text(narrow ? 31 : 38, FontWeight.w700, Colors.white, letterSpacing: 0)),
              ),
            ),
          ),
          if (!skeleton)
            Positioned(
              left: av * 0.6 + 13,
              top: av * 0.43,
              child: ExcludeSemantics(
                child: Art3D(asset: sticker, size: narrow ? 44 : 52, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.3),
              ),
            ),
        ],
      ),
    );
    if (skeleton) return body;
    return Semantics(
      button: onTap != null,
      label: [tag, title, subtitle, time, if (hasBadge) '$unread unread', preview].join(', '),
      excludeSemantics: true,
      child: Tap3D(
        onTap: onTap,
        child: Opacity(opacity: dimmed ? 0.6 : 1, child: body),
      ),
    );
  }
}

class ChatStateCard3D extends StatelessWidget {
  const ChatStateCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.message,
    this.margin = const EdgeInsets.fromLTRB(18, 110, 18, 0),
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? message;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final size = narrow ? 120.0 : 146.0;
    return Padding(
      padding: margin,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, size - 50, 24, 30),
            decoration: BoxDecoration(color: Colors.white, borderRadius: _kRow, boxShadow: ChatLook3D.glow(tone, alpha: 0.28, blur: 14)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(21, FontWeight.w700, Ink3D.title, height: 1.3)),
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(message!, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, Ink3D.copy, height: 1.45)),
                  ),
              ],
            ),
          ),
          Positioned(
            top: -size / 2,
            child: ExcludeSemantics(
              child: Art3D(asset: art, size: size, halo: size + 10, haloColor: tone.haloBase.withValues(alpha: 0.16)),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatHeader3D extends StatelessWidget {
  const ChatHeader3D({
    super.key,
    required this.tone,
    required this.initial,
    required this.name,
    required this.subtitle,
    required this.sticker,
    required this.art,
    required this.onBack,
    required this.onMore,
    this.moreKey,
  });

  final ListingTone tone;
  final String initial;
  final String name;
  final String subtitle;
  final String sticker;
  final String art;
  final VoidCallback? onBack;
  final ChatMenuTap? onMore;
  final Key? moreKey;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 66.0 : 82.0;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 158 + top),
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 20),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [BoxShadow(color: tone.haloBase.withValues(alpha: 0.35), offset: const Offset(0, 8), blurRadius: 20)],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -4,
            bottom: -14,
            child: ExcludeSemantics(
              child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: ChatLook3D.headerHalo, shadowOffset: const Offset(5, 8), shadowAlpha: 0.3),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ChatRoundButton3D(icon: Icons.chevron_left_rounded, onTap: onBack, tooltip: 'Back', glass: true, size: 42),
                  const Spacer(),
                  Builder(
                    builder: (c) => ChatRoundButton3D(
                      icon: Icons.more_vert_rounded,
                      onTap: onMore == null ? null : () => onMore!(chatRectOf(c)),
                      tooltip: 'More',
                      glass: true,
                      size: 42,
                      tapKey: moreKey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.only(right: artSize + 2),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ChatLook3D.avatarFill,
                        border: Border.all(color: ChatLook3D.avatarRing, width: 3),
                      ),
                      child: Text(initial, textScaler: TextScaler.noScaling, style: Ink3D.text(23, FontWeight.w700, Colors.white, letterSpacing: 0)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            header: true,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                name,
                                maxLines: 1,
                                softWrap: false,
                                style: Ink3D.text(21, FontWeight.w700, Colors.white, letterSpacing: 0.4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              ExcludeSemantics(child: Image.asset(sticker, width: 18, height: 18, fit: BoxFit.contain)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Ink3D.text(12, FontWeight.w400, Colors.white.withValues(alpha: 0.95), letterSpacing: 0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatStripCard3D extends StatelessWidget {
  const ChatStripCard3D({
    super.key,
    required this.barColor,
    required this.title,
    required this.detail,
    required this.pill,
    required this.onTap,
    this.extra,
    this.onMenu,
    this.menuKey,
    this.margin = const EdgeInsets.fromLTRB(18, 16, 18, 0),
  });

  final Color barColor;
  final String title;
  final String detail;
  final Widget pill;
  final Widget? extra;
  final VoidCallback onTap;
  final ChatMenuTap? onMenu;
  final Key? menuKey;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: _kChip, boxShadow: ChatLook3D.card),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: barColor),
            Expanded(
              child: Tap3D(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 0, 10),
                    child: Row(
                      children: [
                        const ExcludeSemantics(
                          child: Art3D(asset: ListingArt.luggage, size: 42, shadowBlur: 3, shadowOffset: Offset(2, 4), shadowAlpha: 0.25),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                              if (detail.isNotEmpty)
                                Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.sub)),
                              Padding(padding: const EdgeInsets.only(top: 3), child: pill),
                              ?extra,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 30,
              child: onMenu == null
                  ? null
                  : Tooltip(
                      message: 'More',
                      excludeFromSemantics: true,
                      child: Builder(
                        builder: (c) => Tap3D(
                          onTap: () => onMenu!(chatRectOf(c)),
                          label: 'More',
                          exclude: true,
                          tapKey: menuKey,
                          child: const Center(child: Icon(Icons.more_vert_rounded, size: 22, color: Ink3D.grey)),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    return Padding(padding: margin, child: body);
  }
}

class ChatSafetyNote3D extends StatelessWidget {
  const ChatSafetyNote3D({super.key, required this.text, this.margin = const EdgeInsets.fromLTRB(18, 14, 18, 0)});

  final String text;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(color: ChatLook3D.bannerFill, borderRadius: _kChip, boxShadow: ChatLook3D.card),
      child: Row(
        children: [
          ExcludeSemantics(child: Image.asset(ListingArt.clipboard, width: 38, height: 38, fit: BoxFit.contain)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Ink3D.text(12.5, FontWeight.w400, ChatLook3D.bannerText, letterSpacing: 0, height: 1.4))),
        ],
      ),
    );
  }
}

class ChatNoticePanel3D extends StatelessWidget {
  const ChatNoticePanel3D({super.key, required this.tone, required this.text, this.actionLabel, this.onAction});

  final ListingTone tone;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const double overhang = 40;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(26, 46, 26, 22 + bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: ChatLook3D.panel,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w500, Ink3D.sub, height: 1.45)),
              ),
              if (actionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: 170,
                    child: GradientPillButton(tone: tone, label: actionLabel!, onTap: onAction, height: 44, fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: -overhang,
          child: ExcludeSemantics(
            child: Art3D(
              asset: ListingArt.pushpin,
              size: 72,
              halo: 76,
              haloColor: tone.haloBase.withValues(alpha: 0.18),
              shadowBlur: 5,
              shadowOffset: const Offset(3, 6),
              shadowAlpha: 0.28,
            ),
          ),
        ),
      ],
    );
  }
}

enum ChatBarKind { primary, negative, plain }

class ChatBarButton3D extends StatelessWidget {
  const ChatBarButton3D({super.key, required this.tone, required this.label, required this.onTap, this.kind = ChatBarKind.plain, this.busy = false, this.icon});

  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final ChatBarKind kind;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final filled = kind == ChatBarKind.primary;
    final live = onTap != null && !busy;
    final ink = filled ? Colors.white : (kind == ChatBarKind.negative ? ChatLook3D.red : tone.text);
    final box = Container(
      constraints: BoxConstraints(minHeight: 44 * _scale(context).clamp(1.0, 1.3)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? null : Colors.white,
        gradient: filled ? tone.gradient : null,
        borderRadius: BorderRadius.circular(24),
        border: filled ? null : Border.all(color: kind == ChatBarKind.negative ? ChatLook3D.redBorder : ChatLook3D.outline, width: 1.5),
        boxShadow: onTap == null && !busy ? null : (filled ? ChatLook3D.glow(tone) : ChatLook3D.grey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.4, color: ink)),
            const SizedBox(width: 8),
          ] else if (icon != null) ...[
            Icon(icon, size: 18, color: ink),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(14, FontWeight.w700, ink)),
            ),
          ),
        ],
      ),
    );
    return Tap3D(
      onTap: live ? onTap : null,
      label: label,
      exclude: true,
      child: Opacity(opacity: onTap == null && !busy ? 0.45 : 1, child: box),
    );
  }
}

class ChatActionBar3D extends StatelessWidget {
  const ChatActionBar3D({super.key, required this.rows, this.note, this.margin = const EdgeInsets.only(top: 14, bottom: 4)});

  final List<List<Widget>> rows;
  final String? note;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340 || _scale(context) > 1.25;
    final out = <Widget>[];
    for (final r in rows) {
      if (out.isNotEmpty) out.add(const SizedBox(height: 10));
      final cells = r.where((w) => w is! ChatBarMenu3D).toList();
      final menus = r.whereType<ChatBarMenu3D>();
      final menu = menus.isEmpty ? null : menus.first;
      if (narrow && cells.length > 1) {
        for (var i = 0; i < cells.length; i++) {
          if (i > 0) out.add(const SizedBox(height: 10));
          out.add(
            i == cells.length - 1 && menu != null
                ? Row(
                    children: [
                      Expanded(child: cells[i]),
                      const SizedBox(width: 10),
                      menu,
                    ],
                  )
                : cells[i],
          );
        }
        continue;
      }
      out.add(
        Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: cells[i])],
            if (menu != null) ...[const SizedBox(width: 10), menu],
          ],
        ),
      );
    }
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: _kChip, boxShadow: ChatLook3D.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, Ink3D.title)),
            ),
          ...out,
        ],
      ),
    );
  }
}

class ChatBarMenu3D extends StatelessWidget {
  const ChatBarMenu3D({super.key, required this.onTap});

  final ChatMenuTap? onTap;

  @override
  Widget build(BuildContext context) {
    final s = 44 * _scale(context).clamp(1.0, 1.3);
    return Tooltip(
      message: 'More',
      excludeFromSemantics: true,
      child: Builder(
        builder: (c) => Tap3D(
          onTap: onTap == null ? null : () => onTap!(chatRectOf(c)),
          label: 'More',
          exclude: true,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: ChatLook3D.outline, width: 1.5),
              boxShadow: ChatLook3D.grey,
            ),
            child: const Icon(Icons.more_vert_rounded, size: 22, color: Ink3D.grey),
          ),
        ),
      ),
    );
  }
}

class ChatSheetLabel3D extends StatelessWidget {
  const ChatSheetLabel3D(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 2),
    child: Text(text.toUpperCase(), style: Ink3D.text(11, FontWeight.w700, Ink3D.grey, letterSpacing: 0.5)),
  );
}

class ChatSheetDivider3D extends StatelessWidget {
  const ChatSheetDivider3D({super.key});

  @override
  Widget build(BuildContext context) => Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 6), color: ChatLook3D.divider);
}

class ChatSheetRow3D extends StatelessWidget {
  const ChatSheetRow3D({super.key, required this.tone, required this.art, required this.label, required this.onTap});

  final ListingTone tone;
  final String art;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: tone.haloBase.withValues(alpha: 0.14)),
                    ),
                    Positioned(
                      left: -2,
                      top: -6,
                      child: Art3D(asset: art, size: 50, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.25),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: Ink3D.text(15, FontWeight.w500, Ink3D.body, height: 1.3))),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatDayPill3D extends StatelessWidget {
  const ChatDayPill3D({super.key, required this.tone, required this.top, required this.day, required this.selected, required this.onTap});

  final ListingTone tone;
  final String top;
  final String day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Colors.white : Ink3D.title;
    return Tap3D(
      onTap: onTap,
      label: '$top $day',
      selected: selected,
      exclude: true,
      child: Container(
        constraints: BoxConstraints(minHeight: 64 * _scale(context).clamp(1.0, 1.4)),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? null : Colors.white,
          gradient: selected ? tone.gradient : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.transparent : ChatLook3D.outline, width: 1.5),
          boxShadow: selected ? ChatLook3D.glow(tone) : const [BoxShadow(color: Color(0x409E9E9E), offset: Offset(2, 4), blurRadius: 8)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(top, maxLines: 1, style: Ink3D.text(10.5, FontWeight.w500, selected ? Colors.white : tone.text, letterSpacing: 0)),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(day, maxLines: 1, style: Ink3D.text(16, FontWeight.w700, ink, letterSpacing: 0)),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatSlotPill3D extends StatelessWidget {
  const ChatSlotPill3D({super.key, required this.tone, required this.label, required this.selected, required this.onTap, this.off = false});

  final ListingTone tone;
  final String label;
  final bool selected;
  final bool off;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      constraints: BoxConstraints(minHeight: 44 * _scale(context).clamp(1.0, 1.4)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? null : Colors.white,
        gradient: selected ? tone.gradient : null,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: selected ? Colors.transparent : ChatLook3D.outline, width: 1.5),
        boxShadow: selected && !off ? ChatLook3D.glow(tone, alpha: 0.45, blur: 8) : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, style: Ink3D.text(14, FontWeight.w600, selected ? Colors.white : Ink3D.body, letterSpacing: 0)),
      ),
    );
    return Tap3D(
      onTap: off ? null : onTap,
      label: label,
      selected: selected,
      exclude: true,
      child: Opacity(opacity: off ? 0.4 : 1, child: pill),
    );
  }
}

class ChatSkeletonBubble3D extends StatelessWidget {
  const ChatSkeletonBubble3D({super.key, required this.width, required this.mine});

  final double width;
  final bool mine;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [Color(0xFFCFD8D1), Color(0xFFEEF2EF), Color(0xFFCFD8D1)]),
        ),
      ),
    ),
  );
}

class ChatThreadFade extends StatelessWidget {
  const ChatThreadFade({super.key, required this.child, this.edge = 16, this.bottom = false});

  final Widget child;
  final double edge;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stop = c.maxHeight.isFinite && c.maxHeight > 0 ? (edge / c.maxHeight).clamp(0.0, 0.5) : 0.0;
        const clear = Color(0x00000000);
        const solid = Color(0xFF000000);
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bottom ? const [solid, solid, clear] : const [clear, solid],
            stops: bottom ? [0, 1 - stop, 1] : [0, stop],
          ).createShader(r),
          child: child,
        );
      },
    );
  }
}
