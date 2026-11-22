import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../config/app_routes.dart';
import '../../design/design.dart';
import '../../design/tokens/owner_tokens.dart';
import '../buddy/buddy_navigation.dart';
import '../trip/controllers/trip_plan_controller.dart';
import '../trip/models/trip_plan_model.dart';
import '../trip/trip_navigation.dart';
import 'seeker_feed_controller.dart';
import 'seeker_feed_model.dart';
import 'seeker_status_rule.dart';
import 'strings/seeker_home_strings.dart';

abstract final class SeekerTripActions {
  static void planTrip() => TripNavigation.openTripsTab();

  static void openMyTrips() => Get.toNamed(AppRoutes.myTrips);

  // Owner: the overview, then the step named by nextStep on top of it (D-18), so Back is the overview.
  // Viewer: the read-only trip view; the owner routes answer 404 for a joined trip.
  static Future<void> continueTrip(SeekerTripCard card) async {
    SeekerFeedController.maybe?.markStatusOpened();
    final id = card.tripId;
    if (id == null || id.isEmpty) return;
    if (card.isViewer) {
      await BuddyNavigation.openTripView(id);
      return;
    }
    final step = card.nextStep;
    final overview = TripNavigation.continueTrip(id);
    if (step != null) unawaited(openStepWhenReady(id, step));
    await overview;
  }

  static const Duration stepWait = Duration(seconds: 10);

  @visibleForTesting
  static Future<bool> openStepWhenReady(String tripId, SeekerNextStep step, {Duration timeout = stepWait}) async {
    final kind = step.kind;
    if (kind == SeekerStepKind.journey || kind == SeekerStepKind.unknown) return false;
    if (!await _overviewReady(tripId, timeout)) return false;
    final context = Get.context;
    if (context == null || !context.mounted) return false;
    switch (kind) {
      case SeekerStepKind.stay:
        return TripNavigation.openStayFlow(context, leg: TripEasyRowKey.parse(step.key)?.legIndex);
      case SeekerStepKind.taxi:
        return TripNavigation.openTaxiFlow(context);
      case SeekerStepKind.plan:
        await TripNavigation.openPlan(tripId: tripId);
        return true;
      case SeekerStepKind.journey:
      case SeekerStepKind.unknown:
        return false;
    }
  }

  static Future<bool> _overviewReady(String tripId, Duration timeout) async {
    bool ready() {
      if (!Get.isRegistered<TripPlanController>()) return false;
      final c = TripPlanController.to;
      return c.trip.value?.id == tripId && c.plan.value != null && !c.tripGone.value;
    }

    bool onOverview() => Get.currentRoute == AppRoutes.tripOverview;
    if (ready() && onOverview()) return true;
    if (!Get.isRegistered<TripPlanController>()) return false;
    final c = TripPlanController.to;
    final done = Completer<bool>();
    void check(Object? _) {
      if (done.isCompleted) return;
      if (c.tripGone.value) {
        done.complete(false);
      } else if (ready()) {
        done.complete(true);
      }
    }

    final workers = [ever(c.trip, check), ever(c.plan, check), ever(c.tripGone, check)];
    check(null);
    try {
      final ok = await done.future.timeout(timeout, onTimeout: () => false);
      return ok && onOverview();
    } finally {
      for (final w in workers) {
        w.dispose();
      }
    }
  }

  static void openToday(SeekerTripCard card) {
    final id = card.tripId;
    if (id == null || id.isEmpty) return;
    final day = card.today?.dayNumber;
    if (card.isViewer) {
      BuddyNavigation.openDayPlan(id, day: day);
    } else {
      TripNavigation.openPlan(tripId: id, day: day);
    }
  }

  static void openStatus(SeekerStatus status, SeekerTripCard card) {
    SeekerFeedController.maybe?.markStatusOpened();
    final tripId = status.tripId ?? card.tripId;
    if (tripId == null || tripId.isEmpty || card.isViewer) return;
    if (status.kind == SeekerStatusKind.reply) {
      Get.toNamed(AppRoutes.tripReplies, arguments: {'tripId': tripId, 'enquiryId': status.enquiryId});
    } else {
      TripNavigation.continueTrip(tripId);
    }
  }
}

class SeekerTripSlide extends StatelessWidget {
  const SeekerTripSlide({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SeekerFeedController.maybe;
    if (c == null) return const SeekerTripCardView(feed: SeekerFeed.empty);
    return Obx(() {
      final feed = c.feed.value;
      final failed = c.failed.value;
      if (feed == null) {
        if (failed && !c.loading.value) return SeekerTripCardView(feed: SeekerFeed.empty, failed: true, onRetry: c.reload);
        return const SeekerTripCardSkeleton();
      }
      return SeekerTripCardView(feed: feed, status: c.visibleStatus);
    });
  }
}

class SeekerTripCardView extends StatelessWidget {
  const SeekerTripCardView({
    super.key,
    required this.feed,
    this.status,
    this.onPlan,
    this.onContinue,
    this.onToday,
    this.onMyTrips,
    this.onStatus,
    this.failed = false,
    this.onRetry,
  });

  final bool failed;
  final VoidCallback? onRetry;

  final SeekerFeed feed;
  final SeekerStatus? status;
  final VoidCallback? onPlan;
  final VoidCallback? onContinue;
  final VoidCallback? onToday;
  final VoidCallback? onMyTrips;
  final VoidCallback? onStatus;

  static const BorderRadius radius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(54),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
  static const BorderRadius pillRadius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(20),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    final card = feed.tripCard;
    final tone = ListingTone.indigo;
    final hasTrip = card.hasTrip;
    final onTrip = hasTrip && card.state == SeekerTripState.onTrip && card.today != null;
    final big = !hasTrip;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artBox = big ? (narrow ? 104.0 : 132.0) : (narrow ? 84.0 : 104.0);
    final textRight = DS.s(artBox + 20);
    final white = DesignColors.onPrimary;
    final eyebrowStyle = Ink3D.text(13, FontWeight.w600, white.withValues(alpha: Alpha.high));
    final titleStyle = Ink3D.text(big ? 26 : 24, FontWeight.w700, white, height: 1.25);
    final bodyStyle = Ink3D.text(13.5, FontWeight.w400, white.withValues(alpha: Alpha.high), height: 1.45);

    final String eyebrow;
    final String title;
    String? body;
    String? progress;
    double? fraction;
    String? next;
    final String action;
    final VoidCallback? onAction;
    if (!hasTrip && failed) {
      eyebrow = SeekerHomeStrings.tripEyebrow;
      title = SeekerHomeStrings.failedTitle;
      body = SeekerHomeStrings.railsErrorBody;
      action = SeekerHomeStrings.retry;
      onAction = onRetry;
    } else if (!hasTrip) {
      eyebrow = SeekerHomeStrings.tripEyebrow;
      title = SeekerHomeStrings.noTripTitle;
      body = SeekerHomeStrings.noTripBody;
      action = SeekerHomeStrings.planTrip;
      onAction = onPlan ?? SeekerTripActions.planTrip;
    } else if (onTrip) {
      final today = card.today;
      eyebrow = SeekerTripWords.eyebrow(card);
      title = SeekerHomeStrings.todayIn(SeekerTripWords.todayCity(card));
      final count = today?.placeCount ?? 0;
      body = count > 0 ? SeekerHomeStrings.placesToday(count) : null;
      final seen = today?.placesSeen;
      if (seen != null && count > 0 && !card.isViewer) {
        progress = SeekerHomeStrings.placesSeen(seen.clamp(0, count), count);
        fraction = (seen / count).clamp(0.0, 1.0);
      }
      action = SeekerHomeStrings.todayPlan;
      onAction = onToday ?? () => SeekerTripActions.openToday(card);
    } else if (card.isViewer) {
      eyebrow = SeekerTripWords.eyebrow(card);
      title = SeekerHomeStrings.viewerTitle;
      action = SeekerHomeStrings.openTrip;
      onAction = onContinue ?? () => SeekerTripActions.continueTrip(card);
    } else {
      eyebrow = SeekerTripWords.eyebrow(card);
      title = SeekerHomeStrings.continueTitle;
      if (card.total > 0) {
        progress = SeekerHomeStrings.progress(card.done.clamp(0, card.total), card.total);
        fraction = (card.done / card.total).clamp(0.0, 1.0);
      }
      final step = SeekerTripWords.step(card.nextStep);
      next = step == null ? null : SeekerHomeStrings.next(step);
      action = SeekerHomeStrings.continueAction;
      onAction = onContinue ?? () => SeekerTripActions.continueTrip(card);
    }
    final s = hasTrip && !card.isViewer ? status : null;
    final statusLine = SeekerStatusRule.line(s);
    final slots = feed.slots;
    final full = slots != null && slots.full;

    final children = <Widget>[
      Padding(
        padding: EdgeInsets.only(right: textRight),
        child: Text(eyebrow, maxLines: 1, overflow: TextOverflow.ellipsis, style: eyebrowStyle),
      ),
      Padding(
        padding: EdgeInsets.only(top: DS.s(4), right: textRight),
        child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
      ),
      if (body != null)
        Padding(
          padding: EdgeInsets.only(top: DS.s(6), right: textRight),
          child: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: bodyStyle),
        ),
      if (progress != null && fraction != null)
        Padding(
          padding: EdgeInsets.only(top: DS.s(16), right: DS.s(artBox + 16)),
          child: _ProgressLine(fraction: fraction, label: progress),
        ),
      if (next != null)
        Padding(
          padding: EdgeInsets.only(top: DS.s(10)),
          child: Text(next, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w700, white)),
        ),
      if (statusLine != null && s != null)
        Padding(
          padding: EdgeInsets.only(top: DS.s(14)),
          child: _StatusPill(text: statusLine, reply: s.kind == SeekerStatusKind.reply, onTap: onStatus ?? () => SeekerTripActions.openStatus(s, card)),
        ),
      if (full)
        Padding(
          padding: EdgeInsets.only(top: DS.s(14)),
          child: _LimitStrip(text: SeekerHomeStrings.plansFull(slots.count, slots.limit), onTap: onMyTrips ?? SeekerTripActions.openMyTrips),
        ),
      Padding(
        padding: EdgeInsets.only(top: DS.s(18)),
        child: Align(alignment: Alignment.centerLeft, child: SeekerPillButton(label: action, onTap: onAction)),
      ),
    ];

    final semantics = [
      title,
      if (hasTrip) card.displayTitle,
      ?progress,
      ?next,
    ].join(', ');

    return Padding(
      padding: DS.insets(l: 18, t: 20, r: 18),
      child: Semantics(
        container: true,
        label: semantics,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(borderRadius: DS.br(radius), gradient: tone.gradient, boxShadow: tone.glow()),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: DS.s(big ? 230 : 0), minWidth: double.infinity),
                child: Padding(
                  padding: DS.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
                ),
              ),
            ),
            Positioned(
              right: DS.s(16),
              top: DS.s(big ? 22 : 16),
              child: ExcludeSemantics(
                child: SizedBox(
                  width: DS.s(artBox),
                  height: DS.s(artBox),
                  child: DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: Alpha.v22)),
                    child: Center(child: Art3D(asset: onTrip ? ListingArt.compass : ListingArt.luggage, size: artBox * 0.76)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.fraction, required this.label});

  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final white = DesignColors.onPrimary;
    return Semantics(
      value: label,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: DS.circular(4),
              child: SizedBox(
                height: DS.s(7),
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: white.withValues(alpha: Alpha.v30))),
                    FractionallySizedBox(widthFactor: fraction, heightFactor: 1, child: ColoredBox(color: white)),
                  ],
                ),
              ),
            ),
          ),
          Gap.h(10),
          ExcludeSemantics(child: Text(label, maxLines: 1, style: Ink3D.text(13, FontWeight.w600, white))),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.reply, required this.onTap});

  final String text;
  final bool reply;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final white = DesignColors.onPrimary;
    final bg = reply ? OwnerTokens.amberSoft : ListingPalette.forest.tint;
    final fg = reply ? OwnerTokens.amber : ListingPalette.forest.text;
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinInteractiveDimension, minWidth: double.infinity),
          child: DecoratedBox(
            decoration: BoxDecoration(color: white.withValues(alpha: Alpha.soft), borderRadius: DS.br(SeekerTripCardView.pillRadius)),
            child: Padding(
              padding: DS.sym(h: 12, v: 9),
              child: Row(
                children: [
                  Container(
                    width: DS.s(22),
                    height: DS.s(22),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: Icon(reply ? Icons.chat_bubble_rounded : Icons.check_rounded, size: DS.s(14), color: fg),
                  ),
                  Gap.h(10),
                  Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w600, white, height: 1.35))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LimitStrip extends StatelessWidget {
  const _LimitStrip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: DesignColors.onPrimary, borderRadius: DS.br(SeekerTripCardView.pillRadius)),
        child: Padding(
          padding: DS.insets(l: 14, t: 8, r: 8, b: 8),
          child: Row(
            children: [
              Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, ListingPalette.sunrise.text, height: 1.35))),
              Gap.h(10),
              SeekerPillButton(label: SeekerHomeStrings.myTrips, onTap: onTap, filled: true, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class SeekerPillButton extends StatelessWidget {
  const SeekerPillButton({super.key, required this.label, required this.onTap, this.filled = false, this.compact = false});

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
          child: Center(
            widthFactor: 1,
            child: Container(
              constraints: BoxConstraints(minHeight: DS.s(compact ? 40 : 44)),
              padding: DS.sym(h: compact ? 16 : 20),
              decoration: BoxDecoration(
                color: filled ? null : DesignColors.onPrimary,
                gradient: filled ? tone.gradient : null,
                borderRadius: DS.circular(22),
                boxShadow: filled ? tone.glow() : DS.shadows(Ink3D.whiteBtn),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(compact ? 13 : 14, FontWeight.w700, filled ? DesignColors.onPrimary : DesignColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SeekerTripCardSkeleton extends StatelessWidget {
  const SeekerTripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 18, t: 20, r: 18),
        child: Semantics(
          label: SeekerHomeStrings.loading,
          child: ExcludeSemantics(child: SkeletonBox(width: double.infinity, height: DS.s(230), borderRadius: DS.br(SeekerTripCardView.radius), tone: SkeletonTone.sunrise)),
        ),
      );
}

