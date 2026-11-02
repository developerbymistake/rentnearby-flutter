import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../widgets/trip_day_tile.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_summary_strip.dart';

class TripPlanScreen extends StatefulWidget {
  const TripPlanScreen({super.key});

  @override
  State<TripPlanScreen> createState() => _TripPlanScreenState();
}

enum _MenuAction { rename, addPlaces, delete, myTrips }

class _TripPlanScreenState extends State<TripPlanScreen> {
  late final TripPlanController _c;
  Timer? _savedTimer;
  bool _saving = false;
  bool _justSaved = false;

  @override
  void initState() {
    super.initState();
    _c = TripPlanController.to;
    _c.openPages++;
    final args = Get.arguments;
    final tripId = args is Map ? args['tripId'] as String? : null;
    if (tripId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _c.open(tripId);
      });
    }
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _c)) {
      _c.openPages--;
      _c.releaseIfIdle();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await _c.saveNow(markPlanned: true);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _justSaved = ok;
    });
    if (ok) {
      _savedTimer?.cancel();
      _savedTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _justSaved = false);
      });
    }
  }

  Future<void> _onMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.rename:
        await _rename();
      case _MenuAction.addPlaces:
        _addPlaces();
      case _MenuAction.delete:
        await _delete();
      case _MenuAction.myTrips:
        if (Get.previousRoute == AppRoutes.myTrips) {
          Get.back();
        } else {
          TripNavigation.replaceWithMyTrips();
        }
    }
  }

  void _addPlaces() {
    final picked = _c.picked;
    final plan = _c.plan.value;
    if (picked == null || plan == null) return;
    TripNavigation.openSpots(picked, tripId: _c.trip.value?.id, existingIds: plan.spotIds);
  }

  Future<void> _rename() async {
    final ctrl = TextEditingController(text: _c.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename trip', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(80)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: const InputDecoration(hintText: 'Trip name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || title == _c.title) return;
    await _c.rename(title);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete this trip?', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text('This cannot be undone.', style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (await _c.deleteTrip()) Get.until((r) => r.settings.name == AppRoutes.main);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          _buildNotSaved(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: const BoxDecoration(
        gradient: TripColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(12, top + 8, 4, 16),
      child: Obx(() {
        final plan = _c.plan.value;
        _c.trip.value;
        _c.isSaving.value;
        final off = _c.plannerOff.value;
        final days = _c.dayCount;
        final spots = _c.spotCount;
        return Row(
          children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan == null ? 'Trip' : _c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  if (plan != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$days ${days == 1 ? 'day' : 'days'} · $spots ${spots == 1 ? 'spot' : 'spots'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (plan != null && !off) ...[
              _mapChip(),
              _menu(),
            ],
          ],
        );
      }),
    );
  }

  Widget _mapChip() {
    return GestureDetector(
      onTap: () => TripNavigation.openMap(day: 1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.map, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text('Map', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _menu() {
    return PopupMenuButton<_MenuAction>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: _onMenu,
      itemBuilder: (_) => [
        _menuItem(_MenuAction.rename, Iconsax.edit_2, 'Rename'),
        _menuItem(_MenuAction.addPlaces, Iconsax.add_circle, 'Add places'),
        _menuItem(_MenuAction.myTrips, Iconsax.routing_2, 'My Trips'),
        _menuItem(_MenuAction.delete, Iconsax.trash, 'Delete trip', color: AppColors.error),
      ],
    );
  }

  PopupMenuItem<_MenuAction> _menuItem(_MenuAction value, IconData icon, String label, {Color color = AppColors.textDark}) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: color)),
          ],
        ),
      );

  Widget _buildNotSaved() {
    return Obx(() {
      if (!_c.saveFailed.value || _c.plannerOff.value || _c.plan.value == null) return const SizedBox.shrink();
      final saving = _c.isSaving.value;
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Iconsax.warning_2, size: 15, color: AppColors.warningText),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                TripStrings.notSavedYet,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warningText),
              ),
            ),
            SizedBox(
              height: 36,
              child: saving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warningText),
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: () => _c.saveNow(),
                      child: const Text(
                        TripStrings.retry,
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warningText),
                      ),
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBody() {
    return Obx(() {
      if (_c.plannerOff.value) {
        return ListView(children: const [
          EmptyStateView(
            icon: Iconsax.routing_2,
            title: TripStrings.plannerOff,
            subtitle: TripStrings.plannerOffSubtitle,
            palette: TripColors.palette,
          ),
        ]);
      }
      final plan = _c.plan.value;
      if (plan == null) {
        if (_c.openFailed.value) {
          return ListView(children: [
            EmptyStateView(
              icon: Iconsax.cloud_cross,
              title: TripStrings.tripFailed,
              subtitle: TripStrings.checkConnection,
              onRetry: _c.retryOpen,
              palette: TripColors.palette,
            ),
          ]);
        }
        return _skeletons();
      }
      if (_c.isPlanning.value && _c.result.value == null && !_c.planFailed.value) return _skeletons();
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          if (_c.planFailed.value) ...[
            EmptyStateView(
              icon: Iconsax.cloud_cross,
              title: TripStrings.planFailed,
              subtitle: _c.planError.value ?? TripStrings.checkConnection,
              onRetry: _c.planRetryable.value ? _c.retryPlan : null,
              palette: TripColors.palette,
            ),
            const SizedBox(height: 20),
          ],
          for (final d in plan.days) ...[
            TripDayTile(d.day, key: ValueKey('trip-day-${d.day}')),
            const SizedBox(height: 14),
          ],
          const TripSummaryStrip(),
        ],
      );
    });
  }

  Widget _skeletons() => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, _) => const TripDayTileSkeleton(),
      );

  Widget _buildBottomBar(BuildContext context) {
    return Obx(() {
      if (_c.plannerOff.value || _c.plan.value == null) return const SizedBox.shrink();
      return Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, AppInsets.bottomViewPadding(context) + 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: GradientButton(
          label: _justSaved ? 'Saved' : TripStrings.saveTrip,
          height: 52,
          isLoading: _saving,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
          onPressed: _save,
        ),
      );
    });
  }
}
