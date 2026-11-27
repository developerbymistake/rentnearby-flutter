import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:flutter/material.dart';

import '../tokens/design_colors.dart';
import 'art_3d.dart';

BorderRadius get _kPillRadius => DS.br(const BorderRadius.all(Radius.circular(8)));

enum StatusTone3D {
  shortlisted,
  waiting,
  you,
  both,
  booked,
  red,
  closed;

  // Takes TripDisplayStatus.name so the kit does not import feature code.
  static StatusTone3D of(String statusName) => switch (statusName) {
    'asked' || 'offered' || 'fareSent' => waiting,
    'confirmedByYou' => you,
    'confirmedByBoth' => both,
    'bookedByYou' || 'own' => booked,
    'notAvailable' || 'expired' || 'declined' || 'cancelled' || 'notMe' => red,
    'closed' => closed,
    _ => shortlisted,
  };

  ListingTone get tone => _tones[index];
  Color get pillText => _tones[index].button;

  static final List<ListingTone> _tones = [
    _t(0xFF6F72CA, 0xFF1E1466, 0x8C1E1466, 0xFF1E1466),
    _t(0xFFFFC371, 0xFFFF8A3D, 0x80F57C00, 0xFFE8710A),
    _tc(DesignColors.brandNavy, DesignColors.brandRoyal, DesignColors.brandRoyal60, DesignColors.brandRoyal),
    _t(0xFF66BB6A, 0xFF2E7D32, 0x8C2E7D32, 0xFF2E7D32),
    _t(0xFF54D3C2, 0xFF1FA396, 0x8C1FA396, 0xFF168276),
    _t(0xFFFE95B6, 0xFFFF5287, 0x8CFF5287, 0xFFE0406F),
    _t(0xFFA9B1C4, 0xFF646D84, 0x735A6278, 0xFF5A6278),
  ];

  static ListingTone _t(int g1, int g2, int shadow, int text) => _tc(Color(g1), Color(g2), Color(shadow), Color(text));

  static ListingTone _tc(Color g1, Color g2, Color shadow, Color text) =>
      ListingTone(g1: g1, g2: g2, shadow: shadow, haloBase: g2, text: text, button: text);
}

class StatusPill3D extends StatelessWidget {
  const StatusPill3D({super.key, required this.label, this.status, this.color, this.onGradient = true, this.dot = false});

  final String label;
  final StatusTone3D? status;
  final Color? color;
  final bool onGradient;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (status ?? StatusTone3D.shortlisted).pillText;
    return Container(
      padding: DS.sym(h: 10, v: 4),
      decoration: BoxDecoration(
        color: onGradient ? Colors.white : c.withValues(alpha: 0.12),
        borderRadius: _kPillRadius,
        boxShadow: onGradient ? DS.shadows(const [BoxShadow(color: Color(0x26000000), offset: Offset(0, 2), blurRadius: 6)]) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: DS.s(8), height: DS.s(8), decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
            SizedBox(width: DS.s(6)),
          ],
          Flexible(
            child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w700, c, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class UrgentPill3D extends StatelessWidget {
  const UrgentPill3D({super.key, this.label = 'Urgent'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DS.sym(h: 10, v: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5287),
        borderRadius: _kPillRadius,
        boxShadow: DS.shadows(const [BoxShadow(color: Color(0x26000000), offset: Offset(0, 2), blurRadius: 6)]),
      ),
      child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w700, Colors.white, height: 1.3)),
    );
  }
}

class TagPill3D extends StatelessWidget {
  const TagPill3D({super.key, required this.label, this.color, this.filled = true, this.art});

  final String label;
  final Color? color;
  final bool filled;
  final String? art;

  @override
  Widget build(BuildContext context) {
    final c = color ?? ListingTone.indigo.text;
    final a = art;
    if (a != null) {
      return Container(
        padding: DS.insets(l: 6, t: 5, r: 16, b: 5),
        decoration: BoxDecoration(
          color: filled ? Colors.white : c.withValues(alpha: 0.12),
          borderRadius: DS.circular(20),
          boxShadow: filled ? DS.shadows(const [BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(3, 5), blurRadius: 10)]) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(a, width: DS.s(30), height: DS.s(30), fit: BoxFit.contain),
            SizedBox(width: DS.s(8)),
            Flexible(
              child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, c, letterSpacing: 0.6)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: DS.sym(h: 10, v: 3),
      decoration: BoxDecoration(
        color: filled ? c : Colors.white,
        borderRadius: DS.circular(10),
        boxShadow: filled ? null : DS.shadows(const [BoxShadow(color: Color(0x2E000000), offset: Offset(2, 3), blurRadius: 6)]),
      ),
      child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, filled ? Colors.white : c, letterSpacing: 0.4, height: 1.4)),
    );
  }
}
