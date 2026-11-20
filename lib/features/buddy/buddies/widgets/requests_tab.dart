import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../../shared/widgets/person_row.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/small_pill.dart';
import '../buddies_strings.dart';
import '../controllers/buddies_controller.dart';
import '../controllers/buddy_requests_controller.dart';
import '../models/buddy_models.dart';
import 'buddy_empty_state.dart';
import 'my_buddies_tab.dart';

class RequestsTab extends StatelessWidget {
  const RequestsTab({super.key, required this.controller, required this.onMenu});

  final BuddyRequestsController controller;
  final void Function(ReceivedRequest request) onMenu;

  static EdgeInsets get _label => DS.insets(l: 22, t: 24, r: 22, b: 10);

  @override
  Widget build(BuildContext context) => Obx(() {
        final c = controller;
        switch (c.state.value) {
          case BuddyListState.loading:
            return Padding(padding: EdgeInsets.only(top: DS.s(24)), child: const BuddyListSkeleton());
          case BuddyListState.failed:
            return BuddyLoadFailed(onRetry: c.load);
          case BuddyListState.ready:
            break;
        }
        if (c.isEmpty) {
          return const BuddyEmptyState(art: BuddyArt.panda, title: BuddiesStrings.noRequestsTitle, line: BuddiesStrings.noRequestsLine);
        }
        final busy = c.busy;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (c.received.isNotEmpty) ...[
              SectionLabel(BuddiesStrings.received, padding: _label),
              for (var i = 0; i < c.received.length; i++) ...[
                if (i > 0) Gap.v(12),
                ReceivedRequestCard(
                  key: ValueKey('received-${c.received[i].requestId}'),
                  request: c.received[i],
                  busy: busy.contains(c.received[i].requestId),
                  onAccept: c.accept,
                  onDecline: c.decline,
                  onMenu: onMenu,
                ),
              ],
            ],
            if (c.sent.isNotEmpty) ...[
              SectionLabel(BuddiesStrings.sentWaiting, padding: _label),
              PersonListCard(
                children: [
                  for (final s in c.sent)
                    PersonRow(
                      key: ValueKey('sent-${s.requestId}'),
                      avatar: BuddyAvatar(initial: s.person.initial, seed: s.person.userId),
                      title: s.person.name,
                      subtitle: s.person.username,
                      line2: s.waiting ? BuddyFormat.expiresIn(s.expiresAt) : BuddiesStrings.sendAgainLater,
                      line2Tone: s.waiting ? PersonLineTone.amber : PersonLineTone.grey,
                      trailing: s.waiting
                          ? (s.canCancel
                              ? SmallPill(
                                  label: BuddiesStrings.cancel,
                                  kind: SmallPillKind.dangerOutline,
                                  busy: busy.contains(s.requestId),
                                  onTap: () => c.cancel(s),
                                )
                              : null)
                          : const BuddyBadge(BuddiesStrings.ended, tone: BuddyBadgeTone.grey),
                    ),
                ],
              ),
            ],
            if (c.loadingMore.value) Padding(padding: EdgeInsets.only(top: DS.s(12)), child: const BuddyListSkeleton()),
          ],
        );
      });
}

class ReceivedRequestCard extends StatelessWidget {
  const ReceivedRequestCard({super.key, required this.request, required this.busy, required this.onAccept, required this.onDecline, required this.onMenu});

  final ReceivedRequest request;
  final bool busy;
  final void Function(ReceivedRequest r) onAccept;
  final void Function(ReceivedRequest r) onDecline;
  final void Function(ReceivedRequest r) onMenu;

  @override
  Widget build(BuildContext context) {
    final p = request.person;
    return Container(
      margin: DS.insets(l: 18, r: 18),
      padding: DS.insets(l: 16, t: 14, r: 12, b: 16),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: PersonListCard.radius, boxShadow: BuddyLook.cardShadows(DS.size)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(56)),
            child: Row(
              children: [
                BuddyAvatar(initial: p.initial, seed: p.userId),
                Gap.h(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                      Text(p.username ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, -DS.s(12)),
                  child: Text(BuddyFormat.ago(request.createdAt), style: Ink3D.text(11.5, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0)),
                ),
                BuddyDots(onTap: () => onMenu(request), label: BuddiesStrings.menuLabel),
              ],
            ),
          ),
          Gap.v(12),
          Padding(
            padding: EdgeInsets.only(right: DS.s(4)),
            child: Row(
              children: [
                Expanded(child: SmallPill(label: BuddiesStrings.decline, kind: SmallPillKind.white, tall: true, onTap: busy ? null : () => onDecline(request))),
                Gap.h(12),
                Expanded(child: SmallPill(label: BuddiesStrings.accept, kind: SmallPillKind.teal, tall: true, busy: busy, onTap: () => onAccept(request))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
