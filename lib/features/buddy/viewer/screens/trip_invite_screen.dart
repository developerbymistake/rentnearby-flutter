import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_plan_header.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/strings_shared.dart';
import '../../shared/widgets/buddy_bottom_bar.dart';
import '../../shared/widgets/buddy_page.dart';
import '../controllers/trip_invite_controller.dart';
import '../data/trip_viewer_api.dart';
import '../models/viewer_models.dart';
import '../viewer_deps.dart';
import '../viewer_look.dart';
import '../viewer_strings.dart';
import '../widgets/trip_ended_view.dart';

class TripInviteScreen extends StatefulWidget {
  const TripInviteScreen({super.key, required this.memberId, this.api});

  final String memberId;
  final TripViewerApi? api;

  static String endedReason(String reason) => switch (reason) {
        'Cancelled' => ViewerStrings.reasonCancelled,
        'Expired' => ViewerStrings.reasonExpired,
        'Declined' => ViewerStrings.reasonDeclined,
        _ => '',
      };

  @override
  State<TripInviteScreen> createState() => _TripInviteScreenState();
}

class _TripInviteScreenState extends State<TripInviteScreen> {
  late final TripInviteController _c;
  late final String _tag = 'invite:${widget.memberId}';

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<TripInviteController>(tag: _tag)) Get.delete<TripInviteController>(tag: _tag);
    _c = Get.put(TripInviteController(widget.memberId, api: widget.api ?? ViewerDeps.viewer), tag: _tag);
  }

  @override
  void dispose() {
    if (Get.isRegistered<TripInviteController>(tag: _tag) && identical(Get.find<TripInviteController>(tag: _tag), _c)) Get.delete<TripInviteController>(tag: _tag);
    super.dispose();
  }

  void _back() => Get.back<void>();

  Widget _menu() => PopupMenuButton<int>(
        key: const ValueKey('invite_menu'),
        tooltip: ViewerStrings.moreOptions,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: DS.circular(12)),
        color: DesignColors.surface,
        onSelected: (_) => _c.decline(),
        itemBuilder: (_) => [
          PopupMenuItem<int>(
            key: const ValueKey('invite_decline'),
            value: 0,
            child: Text(ViewerStrings.decline, style: Ink3D.text(13, FontWeight.w600, BuddyLook.dangerText, letterSpacing: 0)),
          ),
        ],
        child: TripMenuDots.box(),
      );

  @override
  Widget build(BuildContext context) => Obx(() {
        final s = _c.state.value;
        final p = _c.preview.value;
        if (s == TripInviteState.ended) return _ended();
        if (s == TripInviteState.ready && p != null) return _ready(p);
        return BuddyPage(
          title: ViewerStrings.inviteTitle,
          onBack: _back,
          body: s == TripInviteState.failed
              ? StateCard3D(
                  tone: BuddyLook.teal,
                  art: BuddyArt.antenna,
                  title: BuddySharedStrings.couldNotLoad,
                  message: BuddySharedStrings.couldNotLoadLine,
                  actionLabel: BuddySharedStrings.retry,
                  onAction: _c.load,
                  layout: StateLayout.tall,
                )
              : const _InviteSkeleton(),
        );
      });

  Widget _ready(InvitePreview p) {
    final range = BuddyFormat.dateRange(p.startDate, p.endDate);
    return BuddyPage(
      title: ViewerStrings.inviteTitle,
      subtitle: ViewerStrings.fromOwner(p.owner.name, p.owner.username),
      onBack: _back,
      trailing: [_menu()],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ViewerStateHero(art: BuddyArt.luggage, small: ViewerStrings.youAreInvited, title: ViewerStrings.joinAsViewer(p.owner.name, p.title)),
          _Card(
            radius: 40,
            margin: DS.insets(l: 18, t: 20, r: 18),
            padding: DS.insets(l: 18, t: 14, r: 18, b: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (p.legCities.isNotEmpty) Padding(padding: EdgeInsets.only(bottom: DS.s(12)), child: _Route(cities: p.legCities)),
                _Kv(label: ViewerStrings.dates, value: range.isEmpty ? ViewerStrings.notSet : range),
                _Kv(label: ViewerStrings.days, value: ViewerStrings.dayCount(p.dayCount)),
                _Kv(label: ViewerStrings.travellers, value: ViewerStrings.travellerCount(p.travellerCount)),
              ],
            ),
          ),
          const _ListCard(title: ViewerStrings.youWillSee, rows: ViewerStrings.willSee, yes: true),
          const _ListCard(title: ViewerStrings.youWillNotSee, rows: ViewerStrings.willNotSee, yes: false),
        ],
      ),
      bottomBar: BuddyBottomBar(
        children: [
          Obx(() => WhitePillButton(
                key: const ValueKey('invite_not_now'),
                tone: BuddyLook.teal,
                label: ViewerStrings.notNow,
                enabled: !_c.busy,
                onTap: _back,
              )),
          Obx(() => GradientPillButton(
                key: const ValueKey('invite_join'),
                tone: BuddyLook.teal,
                label: ViewerStrings.joinTrip,
                loading: _c.joining.value,
                enabled: !_c.declining.value,
                onTap: _c.join,
              )),
        ],
      ),
    );
  }

  Widget _ended() {
    final e = _c.ended.value;
    final owner = _c.ownerName;
    final full = _c.full.value;
    final title = e?.title ?? _c.preview.value?.title;
    final reason = full ? '' : TripInviteScreen.endedReason(e?.reason ?? 'Unknown');
    return BuddyPage(
      title: ViewerStrings.inviteTitle,
      subtitle: owner == null || owner.isEmpty ? null : ViewerStrings.fromOwnerShort(owner),
      onBack: _back,
      body: TripEndedView(
        art: BuddyArt.alarm,
        haloColor: ViewerLook.redHalo,
        title: full ? ViewerStrings.tripFull : ViewerStrings.inviteEnded,
        line: full ? ViewerStrings.askToMakeRoom(owner) : ViewerStrings.askForNew(owner),
        ghostTitle: reason.isEmpty ? null : title,
        ghostLine: reason,
      ),
      bottomBar: BuddyBottomBar(
        children: [
          GradientPillButton(key: const ValueKey('invite_go_trips'), tone: BuddyLook.teal, label: ViewerStrings.goToMyTrips, onTap: () => ViewerDeps.toMyTrips()),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.radius, this.margin, this.padding});

  final Widget child;
  final double radius;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.br(BorderRadius.only(topLeft: const Radius.circular(8), topRight: Radius.circular(radius), bottomLeft: const Radius.circular(8), bottomRight: const Radius.circular(8))),
          boxShadow: DS.shadows(ViewerLook.card),
        ),
        child: child,
      );
}

class _Route extends StatelessWidget {
  const _Route({required this.cities});

  final List<String> cities;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < cities.length; i++) {
      if (i > 0) children.add(Text(ViewerStrings.arrow, style: Ink3D.text(13, FontWeight.w400, ViewerLook.grey, letterSpacing: 0)));
      children.add(Container(
        padding: DS.sym(h: 12, v: 4),
        decoration: BoxDecoration(color: ViewerLook.routeChipBg, borderRadius: DS.circular(10)),
        child: Text(cities[i], style: Ink3D.text(12.5, FontWeight.w700, BuddyLook.tealEnd, letterSpacing: 0)),
      ));
    }
    return Wrap(key: const ValueKey('invite_route'), spacing: DS.gh(6), runSpacing: DS.gv(6), crossAxisAlignment: WrapCrossAlignment.center, children: children);
  }
}

class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(v: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: ViewerLook.line))),
        child: Row(
          children: [
            Text(label, style: Ink3D.text(13, FontWeight.w400, ViewerLook.greyKey, letterSpacing: 0)),
            Gap.h(14),
            Expanded(child: Text(value, textAlign: TextAlign.right, style: Ink3D.text(13, FontWeight.w700, ViewerLook.ink, letterSpacing: 0))),
          ],
        ),
      );
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.title, required this.rows, required this.yes});

  final String title;
  final List<String> rows;
  final bool yes;

  @override
  Widget build(BuildContext context) => _Card(
        radius: 28,
        margin: DS.insets(l: 18, t: 16, r: 18),
        padding: DS.sym(h: 16, v: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: DS.s(4)),
              child: Text(title, style: Ink3D.text(13, FontWeight.w700, ViewerLook.heading, letterSpacing: 0.4)),
            ),
            for (final r in rows)
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: DS.s(38)),
                child: Row(
                  children: [
                    Container(
                      width: DS.s(24),
                      height: DS.s(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: yes ? ViewerLook.yesBg : ViewerLook.noBg, shape: BoxShape.circle),
                      child: Icon(yes ? Icons.check_rounded : Icons.close_rounded, size: DS.s(15), color: yes ? ViewerLook.yesInk : ViewerLook.noInk, semanticLabel: yes ? ViewerStrings.tick : ViewerStrings.cross),
                    ),
                    Gap.h(12),
                    Expanded(child: Text(r, style: Ink3D.text(13.5, FontWeight.w400, ViewerLook.ink, letterSpacing: 0))),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _InviteSkeleton extends StatelessWidget {
  const _InviteSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        key: const ValueKey('invite_loading'),
        padding: DS.insets(l: 18, t: 24, r: 18),
        child: Column(
          children: [
            Container(width: DS.s(120), height: DS.s(120), decoration: const BoxDecoration(color: ViewerLook.ghostBg, shape: BoxShape.circle)),
            Gap.v(20),
            for (final h in const [24.0, 160.0, 120.0]) ...[
              Container(height: DS.s(h), decoration: BoxDecoration(color: ViewerLook.ghostBg, borderRadius: DS.circular(16))),
              Gap.v(16),
            ],
          ],
        ),
      );
}
