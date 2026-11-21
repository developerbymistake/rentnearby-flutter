import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../strings/owner_shared_strings.dart';
import 'owner_home_models.dart';

class AttentionRowView {
  const AttentionRowView({required this.title, this.sub, this.art, this.action, this.onTap, this.urgent = false});

  final String title;
  final String? sub;
  final String? art;
  final String? action;
  final VoidCallback? onTap;
  final bool urgent;
}

typedef AttentionCopy = AttentionRowView? Function(OwnerAttention row);

class AttentionList extends StatelessWidget {
  const AttentionList({super.key, required this.rows, required this.copy, this.onSeeAll, this.shown = 2, this.all = false});

  final List<OwnerAttention> rows;
  final AttentionCopy copy;
  final VoidCallback? onSeeAll;
  final int shown;
  final bool all;

  static List<AttentionRowView> views(List<OwnerAttention> rows, AttentionCopy copy) =>
      [for (final r in rows) ?copy(r)];

  @override
  Widget build(BuildContext context) {
    final views = AttentionList.views(rows, copy);
    if (views.isEmpty) return const SizedBox.shrink();
    final visible = all ? views : views.take(shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(OwnerSharedStrings.needsAttention, style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
            if (!all && views.length > shown && onSeeAll != null)
              TextButton(
                onPressed: onSeeAll,
                child: Text(OwnerSharedStrings.seeAll(views.length), style: Ink3D.text(13, FontWeight.w600, DesignColors.primary)),
              ),
          ],
        ),
        Gap.v(6),
        for (final v in visible) ...[
          _AttentionTile(view: v),
          Gap.v(8),
        ],
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({required this.view});

  final AttentionRowView view;

  @override
  Widget build(BuildContext context) {
    final radius = DS.br(CardRadius.hero);
    return Material(
      color: DesignColors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: view.onTap,
        child: Padding(
          padding: DS.sym(h: 14, v: 12),
          child: Row(
            children: [
              if (view.art != null) ...[Art3D(asset: view.art!, size: 34), Gap.h(10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(view.title,
                        style: Ink3D.text(13.5, FontWeight.w700, view.urgent ? DesignColors.error : Ink3D.title, height: 1.3, letterSpacing: 0)),
                    if (view.sub != null)
                      Text(view.sub!, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, height: 1.35, letterSpacing: 0)),
                  ],
                ),
              ),
              if (view.action != null) ...[
                Gap.h(8),
                Text(view.action!, style: Ink3D.text(13, FontWeight.w700, DesignColors.primary, letterSpacing: 0)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
