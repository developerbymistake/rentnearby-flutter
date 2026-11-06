import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:share_plus/share_plus.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/empty_state_view.dart';
import '../controllers/my_trips_controller.dart';
import '../models/trip_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../trip_strings_bar.dart';
import '../utils/trip_bar_rules.dart';
import '../utils/trip_format.dart';
import '../utils/trip_summary_source.dart';
import '../utils/trip_summary_text.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_lifecycle_actions.dart';
import '../widgets/trip_shimmers.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  late final MyTripsController _ctrl;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = MyTripsController.to;
    _ctrl.pastOpen.value = false;
    _ctrl.load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent - 300) _ctrl.loadMore();
  }

  void _openPlan(TripSummaryModel t) {
    TripNavigation.openPlan(tripId: t.id)?.then((_) {
      if (mounted) _ctrl.load();
    });
  }

  void _onAction(TripSummaryModel t, {bool past = false}) {
    if (past || TripBarRules.isReady(t)) {
      TripNavigation.openSummary(t.id);
      return;
    }
    Get.toNamed(AppRoutes.tripPlan, arguments: TripBarRules.continueArgs(t))?.then((_) {
      if (mounted) _ctrl.load();
    });
  }

  Future<void> _share(TripSummaryModel t) async {
    try {
      final snap = await TripSummarySource.load(t.id);
      await SharePlus.instance
          .share(ShareParams(text: TripSummaryText.build(snap.record), subject: TripStrings.shareSubject(t.routeLine)));
    } catch (e) {
      if (TripSummarySource.isGone(e)) {
        _ctrl.removeLocal(t.id);
        AppToast.error(TripStringsA5.tripNotFoundShare);
      } else {
        AppToast.error(TripStringsA5.shareFailed);
      }
    }
  }

  Future<void> _delete(TripSummaryModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(TripStrings.deleteTrip, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text(TripStrings.deleteConfirmBody, style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(TripStrings.cancelAction, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(TripStrings.delete, style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (ok == true) await _ctrl.delete(t.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: RefreshIndicator(
              color: TripColors.accent,
              onRefresh: _ctrl.load,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildOfflineStrip(context),
                  _buildBody(context),
                  SliverToBoxAdapter(child: _buildFooter()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, top + 8, 20, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Text(
              TripStrings.myTrips,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(TripSummaryModel t, {bool past = false}) => TripCard(
        key: ValueKey('${past ? 'p' : 'a'}${t.id}'),
        trip: t,
        past: past,
        onOpen: () => _openPlan(t),
        onAction: () => _onAction(t, past: past),
        onShare: t.spotCount > 0 ? () => _share(t) : null,
        onDelete: () => _delete(t),
        onMarkComplete: past && !t.isCompleted ? () => TripLifecycleActions.markCompleteFromList(context, t) : null,
      );

  Widget _groupLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          text,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textLight),
        ),
      );

  Widget _pastToggle(int n) => InkWell(
        onTap: _ctrl.togglePast,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    TripStringsBar.pastTrips(n),
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: TripColors.accentDark),
                  ),
                ),
                AnimatedRotation(
                  turns: _ctrl.pastOpen.value ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.chevron_right_rounded, color: TripColors.accentDark),
                ),
              ],
            ),
          ),
        ),
      );

  List<Widget> _pastSection() {
    final known = _ctrl.counts.value.completed;
    final n = known > _ctrl.past.length ? known : _ctrl.past.length;
    if (n == 0 && !_ctrl.pastOpen.value) return const [];
    final out = <Widget>[const SizedBox(height: 12), _pastToggle(n)];
    if (!_ctrl.pastOpen.value) return out;
    if (_ctrl.past.isEmpty) {
      if (_ctrl.pastLoading.value) {
        out.add(const TripCardSkeleton());
      } else if (_ctrl.pastFailed.value) {
        out.add(EmptyStateView(
          icon: Iconsax.cloud_cross,
          title: TripStrings.tripsFailed,
          subtitle: TripStrings.checkConnection,
          onRetry: _ctrl.loadPast,
          palette: TripColors.palette,
        ));
      } else {
        out.add(const EmptyStateView(
          icon: Iconsax.routing_2,
          title: TripStringsBar.noPastTrips,
          subtitle: TripStringsBar.noPastSub,
          palette: TripColors.palette,
        ));
      }
      return out;
    }
    for (final t in _ctrl.past) {
      out
        ..add(const SizedBox(height: 4))
        ..add(_card(t, past: true))
        ..add(const SizedBox(height: 8));
    }
    return out;
  }

  Widget _buildBody(BuildContext context) {
    return Obx(() {
      if (_ctrl.plannerOff.value) {
        return const SliverToBoxAdapter(
          child: EmptyStateView(
            icon: Iconsax.routing_2,
            title: TripStrings.plannerOff,
            subtitle: TripStrings.plannerOffSubtitle,
            palette: TripColors.palette,
          ),
        );
      }
      final side = _sidePad(context);
      if (_ctrl.active.isEmpty && _ctrl.isLoading.value) {
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 16, side, 0),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => const TripCardSkeleton(),
          ),
        );
      }
      final groups = _ctrl.groups;
      final children = <Widget>[];
      if (groups.inProgress.isEmpty && groups.ready.isEmpty) {
        children.add(_ctrl.loadFailed.value
            ? EmptyStateView(
                icon: Iconsax.cloud_cross,
                title: TripStrings.tripsFailed,
                subtitle: TripStrings.checkConnection,
                onRetry: _ctrl.load,
                palette: TripColors.palette,
              )
            : EmptyStateView(
                icon: Iconsax.routing_2,
                title: TripStringsBar.noActiveTrips,
                subtitle: TripStrings.noTripsSubtitle,
                onRetry: () => TripNavigation.start(context),
                retryLabel: TripStrings.planATrip,
                palette: TripColors.palette,
              ));
      }
      for (final (label, list) in [
        (TripStringsBar.inProgress, groups.inProgress),
        (TripStringsBar.ready, groups.ready),
      ]) {
        if (list.isEmpty) continue;
        children.add(_groupLabel(TripStringsBar.groupHeader(label, list.length)));
        for (final t in list) {
          children
            ..add(_card(t))
            ..add(const SizedBox(height: 12));
        }
      }
      children.addAll(_pastSection());
      return SliverPadding(padding: EdgeInsets.fromLTRB(side, 4, side, 0), sliver: SliverList.list(children: children));
    });
  }

  Widget _buildOfflineStrip(BuildContext context) {
    return Obx(() {
      final at = _ctrl.offlineCopyAt.value;
      if (at == null || _ctrl.active.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(_sidePad(context), 12, _sidePad(context), 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.neutralChip, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Iconsax.cloud_cross, size: 16, color: AppColors.textMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    TripStringsA5.offlineCopy(TripFormat.time12Of(at)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  static double _sidePad(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w > 640 ? (w - 640) / 2 : 16;
  }

  Widget _buildFooter() {
    return Obx(() => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: SizedBox(
            height: 24,
            child: _ctrl.isLoadingMore.value
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: TripColors.accent),
                    ),
                  )
                : null,
          ),
        ));
  }
}
