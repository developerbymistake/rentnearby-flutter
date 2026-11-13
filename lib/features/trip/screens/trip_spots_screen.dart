import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../utils/app_toast.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_spots_controller.dart';
import '../models/trip_city_model.dart';
import '../models/trip_plan_model.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_v2_create.dart';
import '../trip_strings_mca_a2.dart';
import '../trip_strings_spots_x.dart';
import '../utils/trip_spot_picks.dart';
import '../utils/trip_days_rules.dart';
import '../widgets/trip_city_sheet.dart';
import '../widgets/trip_spot_row.dart';
import '../widgets/trip_spots_extras.dart';


class TripSpotsScreen extends StatefulWidget {
  const TripSpotsScreen({super.key});

  @override
  State<TripSpotsScreen> createState() => _TripSpotsScreenState();
}

class _TripSpotsScreenState extends State<TripSpotsScreen> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
  late final TripCityModel _city;
  late final List<TripCityModel> _chain;
  late final int _index;
  late final List<TripDraftLeg> _draftLegs;
  late final bool _adding;
  late final bool _newLeg;
  late final int? _legIndex;
  late final int? _pickDay;
  late final String? _replaceId;
  late final Set<String> _existingIds;
  late final TripSpotsController _ctrl;
  late final TripPlanController _plan;
  final _scroll = ScrollController();
  final _barOpacity = ValueNotifier<double>(0);
  bool _starting = false;
  Worker? _draftWorker;

  bool get _intoTrip => _adding || _newLeg;
  bool get _creating => !_intoTrip;
  int get _days {
    final n = TripDaysRules.autoTotal(_visits(), TripPace.relaxed);
    return n < _chain.length ? _chain.length : n;
  }
  bool get _isLast => _index >= _chain.length - 1;
  TripCityModel? get _next => _isLast ? null : _chain[_index + 1];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map;
    _city = args['city'] as TripCityModel;
    _newLeg = args['newLeg'] == true;
    _adding = !_newLeg && args['adding'] == true;
    _legIndex = args['legIndex'] as int?;
    _pickDay = _adding ? args['pickDay'] as int? : null;
    _replaceId = _pickDay == null ? null : args['replaceSpotId'] as String?;
    _existingIds = (args['existingIds'] as Set<String>?) ?? const <String>{};
    _plan = TripPlanController.to;
    final next = args['next'] as TripCityModel?;
    final cities = args['cities'];
    final chain = <TripCityModel>[
      if (cities is List) ...cities.whereType<TripCityModel>() else ...[_city, ?next],
    ];
    final at = chain.indexWhere((c) => c.cityKey == _city.cityKey);
    if (at < 0) chain.insert(0, _city);
    _chain = _intoTrip ? [_city] : chain;
    _index = _intoTrip ? 0 : (at < 0 ? 0 : at);
    final legs = args['draftLegs'];
    final legacy = args['draftIds'];
    _draftLegs = [
      if (legs is List) ...legs.whereType<TripDraftLeg>(),
      if (legs is! List && legacy is List) TripDraftLeg(_city, legacy.whereType<String>().toList()),
    ];
    final other = _intoTrip ? _plan.spotCount - _existingIds.length : 0;
    final tag = '${_city.cityKey}';
    _ctrl = Get.isRegistered<TripSpotsController>(tag: tag)
        ? Get.find<TripSpotsController>(tag: tag)
        : Get.put(
            TripSpotsController(_city.cityKey, existingIds: _existingIds, otherSpots: other < 0 ? 0 : other),
            tag: tag,
          );
    _enter.forward();
    _plan.openPages++;
    _scroll.addListener(_onScroll);
    if (_creating) {
      _syncLimit();
      final seed = _draftLegs.firstWhereOrNull((l) => l.city.cityKey == _city.cityKey)?.ids ?? const <String>[];
      for (final id in seed) {
        if (_ctrl.selected.length >= TripConstants.maxSpots || _ctrl.atLimit) break;
        _ctrl.selected.add(id);
      }
      _draftWorker = ever(_ctrl.selected, (_) {
        _syncLimit();
        if (!_starting) TripNewDraft.save(_legsNow());
      });
    } else {
      _syncLimit();
    }
  }

  List<int> _counts() => [for (final c in _chain) c.cityKey == _city.cityKey ? _ctrl.selected.length : _idsOf(c).length];

  List<List<int>> _visits() => [
        for (final c in _chain)
          () {
            final byId = {for (final x in _chosenOf(c)) x.id: x.visitMinutes};
            return [for (final id in _idsOf(c)) byId[id] ?? TripConstants.defaultVisitMinutes];
          }(),
      ];

  void _syncLimit() {
    if (_pickDay != null) return;
    if (_newLeg) {
      _ctrl.limit.value = TripConstants.maxSpotsPerDay;
    } else if (_adding) {
      _ctrl.limit.value = _plan.addCapacity(_legIndex ?? _plan.legCount);
    } else {
      _ctrl.limit.value = TripDaysRules.limitForAuto(_visits(), _index, TripPace.relaxed);
    }
  }

  List<String> _idsOfSaved(TripCityModel c) {
    final saved = TripNewDraft.read()?.legs ?? _draftLegs;
    return saved.firstWhereOrNull((l) => l.city.cityKey == c.cityKey)?.ids ?? const <String>[];
  }

  List<String> _idsOf(TripCityModel c) {
    if (c.cityKey == _city.cityKey) return _ctrl.selected.toList();
    final tag = '${c.cityKey}';
    if (Get.isRegistered<TripSpotsController>(tag: tag)) return Get.find<TripSpotsController>(tag: tag).selected.toList();
    return _idsOfSaved(c);
  }

  List<TripDraftLeg> _legsNow() => [for (final c in _chain) TripDraftLeg(c, _idsOf(c))];

  List<TripSpotModel> _chosenOf(TripCityModel c) {
    if (c.cityKey == _city.cityKey) return _ctrl.chosen;
    final tag = '${c.cityKey}';
    return Get.isRegistered<TripSpotsController>(tag: tag) ? Get.find<TripSpotsController>(tag: tag).chosen : const [];
  }

  @override
  void dispose() {
    _draftWorker?.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _barOpacity.dispose();
    _enter.dispose();
    final tag = '${_city.cityKey}';
    if (Get.isRegistered<TripSpotsController>(tag: tag) && identical(Get.find<TripSpotsController>(tag: tag), _ctrl)) {
      Get.delete<TripSpotsController>(tag: tag);
    }
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _plan)) {
      _plan.openPages--;
      _plan.releaseIfIdle();
    }
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    final o = (p.pixels / 24).clamp(0.0, 1.0);
    if (o != _barOpacity.value) _barOpacity.value = o;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent - 300) _ctrl.loadMore();
  }

  Future<void> _addLeg(List<TripSpotModel> chosen) async {
    final block = await _plan.addLeg(_city, chosen);
    if (!mounted) return;
    switch (block) {
      case TripLegEditBlock.none:
        Get.back();
        return;
      case TripLegEditBlock.maxLegs ||
            TripLegEditBlock.noDays ||
            TripLegEditBlock.duplicate ||
            TripLegEditBlock.offline ||
            TripLegEditBlock.bookings:
        break;
      default:
        AppToast.warning(TripStringsMcaA2.cantChangeTrip);
    }
    _starting = false;
  }

  bool get _pickFull {
    final day = _pickDay;
    final p = _plan.plan.value;
    if (day == null || p == null) return false;
    final replaceId = _replaceId;
    if (replaceId != null && p.spotById(replaceId) != null) return false;
    return !TripDaysRules.canAddOnDay(p, day);
  }

  void _pickOne(TripSpotModel spot) {
    final day = _pickDay;
    final p = _plan.plan.value;
    if (day == null || p == null || _starting) return;
    final replaceId = _replaceId;
    final replacing = replaceId != null && p.spotById(replaceId) != null;
    if (!replacing && p.spotCount >= TripConstants.maxSpots) {
      AppToast.warning(TripStringsMcaA2.maxPlaces);
      return;
    }
    if (!replacing && !TripDaysRules.canAddOnDay(p, day)) {
      AppToast.warning(TripStringsV2Create.dayFullMove);
      return;
    }
    _starting = true;
    final leg = p.legIndexOf(day);
    if (replacing) _plan.removeSpot(replaceId, keepEmptyDays: true);
    _plan.addSpots([spot], legIndex: leg, day: day);
    Get.back();
  }

  VoidCallback? _toggleFor(TripSpotModel s) {
    if (_existingIds.contains(s.id)) return null;
    return _pickDay != null ? () => _pickOne(s) : () => _toggle(s.id);
  }

  void _applyBundle(TripQuickStart b) {
    final added = _ctrl.addBundle(b);
    if (added.isEmpty) {
      AppToast.warning(_limitText);
      return;
    }
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(TripStringsSpotsX.bundleAdded(added.length)),
      action: SnackBarAction(label: TripStringsSpotsX.undo, onPressed: () => _ctrl.removeAdded(added)),
    ));
  }

  Widget _buildOffline() => Obx(() => _ctrl.offline.value && !_ctrl.isLoading.value
      ? TripOfflineBanner(onTap: _ctrl.load)
      : const SizedBox.shrink());

  void _toggle(String id) {
    if (_ctrl.toggle(id)) return;
    if (_ctrl.atLimit) AppToast.warning(_limitText);
  }

  String get _limitText => _creating
      ? TripStringsV2Create.limitReached
      : _newLeg
          ? TripStringsV2Create.dayFull
          : TripStringsV2Create.legFull;

  // A city in the chain may stay without places while another one has some.
  bool _canContinue(int selected) =>
      selected > 0 ||
      (!_intoTrip && (!_isLast || _chain.any((c) => c.cityKey != _city.cityKey && _idsOf(c).isNotEmpty)));

  Future<void> _planMyDays() async {
    if (_starting) return;
    if (_ctrl.selected.isEmpty && !_canContinue(0)) return;
    _starting = true;
    if (_creating && _isLast) {
      for (final c in _chain) {
        final tag = '${c.cityKey}';
        if (Get.isRegistered<TripSpotsController>(tag: tag)) {
          await Get.find<TripSpotsController>(tag: tag).ensureSelectedLoaded();
        }
      }
    } else {
      await _ctrl.ensureSelectedLoaded();
    }
    if (!mounted) return;
    final chosen = _ctrl.chosen;
    if (_newLeg) {
      await _addLeg(chosen);
      return;
    }
    if (_adding) {
      _plan.addSpots(chosen.where((s) => !_existingIds.contains(s.id)).toList(), legIndex: _legIndex);
      Get.back();
      return;
    }
    final next = _next;
    if (next != null) {
      TripNewDraft.save(_legsNow());
      await Get.toNamed(
        AppRoutes.tripSpots,
        arguments: {'city': next, 'cities': _chain, 'draftLegs': _legsNow()},
        preventDuplicates: false,
      );
      _starting = false;
      if (mounted) {
        _syncLimit();
        setState(() {});
      }
      return;
    }
    final selections = [
      for (final c in _chain) (city: c, spots: _chosenOf(c)),
    ];
    TripNewDraft.save(_legsNow());
    unawaited(_plan.startFromSelections(selections));
    Get.offNamedUntil(
      AppRoutes.tripPlan,
      (r) => r.settings.name != AppRoutes.tripSpots,
      arguments: {'fresh': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          _buildHeader(context),
          _block(_buildCityChips(), 1, 6),
          _block(_buildOffline(), 2, 6),
          _block(_buildChips(), 3, 6),
          _block(_buildLimitNotice(), 4, 6),
          Expanded(child: _block(_buildBody(), 5, 6)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _block(Widget child, int index, int count) =>
      TemplateEntrance(animation: templateInterval(_enter, index, count), animationController: _enter, child: child);

  String _pickHeading(int day) {
    final p = _plan.plan.value;
    final replaceId = _replaceId;
    final replaced = replaceId == null ? null : p?.spotById(replaceId);
    var n = (p?.dayAt(day)?.spots.length ?? 0) - (replaced == null ? 0 : 1);
    if (n < 0) n = 0;
    return TripStringsV2Create.pickHeading(day, n);
  }

  Widget _buildHeader(BuildContext context) {
    Widget head(String sub) => PageHeader3D(
          tone: ListingTone.indigo,
          title: _city.name,
          subtitle: sub,
          art: ListingArt.roundPushpin,
          artSize: 64,
          inlineTitle: true,
          onBack: () => Get.back(),
        );
    final Widget body;
    if (_pickDay case final day?) {
      body = head(_pickHeading(day));
    } else if (_creating) {
      body = Obx(() => head(_chain.length > 1
          ? TripStringsV2Create.spotsHeader(_index + 1, _chain.length, _days)
          : TripStringsV2Create.spotsHeaderOne(_days)));
    } else {
      body = Obx(() {
        final total = _ctrl.total.value;
        final loaded = !_ctrl.isLoading.value &&
            !_ctrl.loadFailed.value &&
            !_ctrl.plannerOff.value &&
            !_ctrl.isNotReady &&
            total > 0;
        return head(loaded ? TripStringsV2Create.placesLine(total) : 'Places to visit');
      });
    }
    return SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.only(top: 6), child: body));
  }

  void _backTo(int index) {
    var left = _index - index;
    if (left <= 0) return;
    Get.until((_) {
      if (left == 0) return true;
      left--;
      return false;
    });
  }

  Widget _buildCityChips() {
    if (!_creating || _chain.length < 2) return const SizedBox.shrink();
    return Obx(() {
      _ctrl.selected.length;
      return ChipCPRow(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
        children: [
          for (var i = 0; i < _chain.length; i++)
            ChipCP(
              tone: ListingTone.indigo,
              art: i == _index ? ListingArt.roundPushpin : ListingArt.mountain,
              label: i != _index && _idsOf(_chain[i]).isNotEmpty
                  ? TripStringsV2Create.doneCity(_chain[i].name, _idsOf(_chain[i]).length)
                  : _chain[i].name,
              off: i != _index,
              onTap: i < _index ? () => _backTo(i) : null,
            ),
        ],
      );
    });
  }

  Widget _buildChips() {
    return Obx(() {
      final cats = _ctrl.categories;
      if (_ctrl.isLoading.value || _ctrl.plannerOff.value || cats.length <= 1) return const SizedBox.shrink();
      final current = _ctrl.filter.value;
      return ChipCPRow(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
        children: [
          _chip(ListingArt.worldMap, TripStrings.allCategories, current == null, () => _ctrl.setFilter(null)),
          for (final cat in cats)
            _chip(TripSpotLook.assetOf(cat), TripSpotCategory.label(cat), current == cat, () => _ctrl.setFilter(cat)),
        ],
      );
    });
  }

  Widget _chip(String art, String label, bool selected, VoidCallback onTap) =>
      ChipCP(tone: ListingTone.indigo, art: art, label: label, off: !selected, onTap: onTap);

  Widget _buildBody() {
    return Obx(() {
      if (_ctrl.plannerOff.value) {
        return _message(const StateCard(
          title: TripStrings.plannerOff,
          message: TripStrings.plannerOffSubtitle,
          kit: KitTone.brand,
          layout: StateLayout.plain,
        ));
      }
      final items = _ctrl.items;
      if (items.isEmpty && _ctrl.isLoading.value) {
        return _skeleton();
      }
      if (_ctrl.loadFailed.value && items.isEmpty) {
        return _message(StateCard.error(
          title: TripStrings.placesFailed,
          message: _ctrl.loadError.value.isEmpty ? TripStrings.checkConnection : _ctrl.loadError.value,
          kit: KitTone.brand,
          layout: StateLayout.plain,
          actionLabel: TripStrings.retry,
          onAction: _ctrl.load,
        ));
      }
      if (_ctrl.isNotReady) {
        return _message(StateCard(
          asset: TravelIcon.map,
          title: TripStrings.notReadyTitle,
          message: TripStrings.notReadySubtitle(_city.name),
          kit: KitTone.brand,
          layout: StateLayout.plain,
        ));
      }
      final visible = _ctrl.visible;
      final loadingMore = _ctrl.isLoadingMore.value;
      final filter = _ctrl.filter.value;
      if (visible.isEmpty && !loadingMore) {
        if (filter != null) {
          return _message(StateCard(
            asset: TravelIcon.place,
            title: TripStringsSpotsX.noneIn(TripSpotCategory.label(filter)),
            kit: KitTone.brand,
          layout: StateLayout.plain,
            actionLabel: TripStringsSpotsX.showAll,
            onAction: () => _ctrl.setFilter(null),
          ));
        }
        return _message(const StateCard(
          asset: TravelIcon.place,
          title: TripStrings.noPlaces,
          kit: KitTone.brand,
          layout: StateLayout.plain,
        ));
      }
      final selected = _ctrl.selected.toSet();
      final atLimit = _ctrl.atLimit;
      final pickFull = _pickFull;
      final sug = _ctrl.suggestion.value;
      final count = _ctrl.items.length;
      final few = !_ctrl.hasMore.value && count <= 3;
      final mustSee = filter == null && !few ? _ctrl.mustSee : const <TripSpotModel>[];
      final quick = filter == null && !few && _pickDay == null && selected.length < 3
          ? _ctrl.quickStarts.where((b) => TripSpotPicks.bundleAdds(b, selected, 3).isNotEmpty).toList()
          : const <TripQuickStart>[];
      final heads = <Widget>[
        if (few && filter == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Text(
              TripStringsSpotsX.fewPlaces(count),
              style: Ink3D.text(13, FontWeight.w600, Ink3D.grey),
            ),
          ),
        if (quick.isNotEmpty) TripQuickStartRail(bundles: quick, onTap: _applyBundle, nameOf: _nameOf),
        if (mustSee.isNotEmpty)
          TripMustSeeRail(
            city: _city.name,
            spots: mustSee,
            selected: {...selected, ..._existingIds},
            lockedOf: (s) => !_existingIds.contains(s.id) && !selected.contains(s.id) && (_pickDay != null ? pickFull : atLimit),
            toggleOf: _toggleFor,
          ),
      ];
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: heads.length + visible.length + (loadingMore ? 1 : 0),
        itemBuilder: (_, k) {
          if (k < heads.length) return _row(k, heads[k]);
          final i = k - heads.length;
          if (i == visible.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ListingTone.indigo.g2),
                ),
              ),
            );
          }
          final s = visible[i];
          final existing = _existingIds.contains(s.id);
          final card = TripSpotRow(
            key: ValueKey(s.id),
            spot: s,
            selected: existing || selected.contains(s.id),
            locked: !existing && !selected.contains(s.id) && (_pickDay != null ? pickFull : atLimit),
            onToggle: existing ? null : (_pickDay != null ? () => _pickOne(s) : () => _toggle(s.id)),
          );
          if (sug != null && sug.forId == s.id && _pickDay == null) {
            return _row(heads.length + i, Column(
              children: [
                card,
                TripSuggestionCard(
                  text: TripSpotPicks.nearbyText(s, sug.nearby),
                  onAdd: () {
                    _ctrl.dismissSuggestion();
                    _toggle(sug.nearby.spot.id);
                  },
                  onDismiss: _ctrl.dismissSuggestion,
                ),
              ],
            ));
          }
          return _row(heads.length + i, card);
        },
      );
    });
  }

  Widget _message(Widget child) => ListView(
        padding: const EdgeInsets.only(top: 40),
        children: [TemplateStagger(children: [child])],
      );

  Widget _row(int k, Widget child) => TemplateEntrance(
        animation: templateInterval(_enter, math.min(k, 7), 8),
        animationController: _enter,
        child: child,
      );

  Widget _skeleton() => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: 4,
        itemBuilder: (_, _) => const WideCardSkeleton(kind: WideKind.photo),
      );

  String _nameOf(String id) => _ctrl.items.firstWhereOrNull((s) => s.id == id)?.title ?? '';

  Widget _buildBottomBar(BuildContext context) {
    return Obx(() {
      final n = _ctrl.selected.length;
      if (_ctrl.plannerOff.value) return const SizedBox.shrink();
      if (_pickDay != null) {
        if (!_pickFull) return const SizedBox.shrink();
        return _barFrame(context, [
          Text(TripStringsV2Create.dayFullMove, style: Ink3D.text(13, FontWeight.w600, Ink3D.grey)),
        ]);
      }
      final nextName = _next?.name;
      final children = <Widget>[];
      final route = _ctrl.route;
      if (route != null) {
        children
          ..add(TripSpotsRouteStrip(route: route))
          ..add(const SizedBox(height: 6));
      }
      if (_creating) {
        final total = _counts().fold<int>(0, (a, b) => a + b);
        final parts = <(String, int)>[
          for (final c in _chain)
            if (c.cityKey == _city.cityKey || _idsOf(c).isNotEmpty) (c.name, _idsOf(c).length),
        ];
        children.add(Text.rich(
          TextSpan(children: [
            TextSpan(
              text: TripStringsV2Create.barCities(parts),
              style: const TextStyle(fontWeight: FontWeight.w700, color: Ink3D.title),
            ),
            TextSpan(text: TripStringsV2Create.barTotal(total)),
          ]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey),
        ));
      }
      if (_creating && n == 0 && !_canContinue(0)) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 6));
        children.add(Text(TripStringsV2Create.pickOnePlace, style: Ink3D.text(13, FontWeight.w600, Ink3D.grey)));
      }
      if (_canContinue(n)) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 12));
        children.add(GradientPillButton(
          tone: ListingTone.indigo,
          label: _creating
              ? (nextName == null ? TripStringsV2Create.makeMyPlan : TripStringsV2Create.next(nextName))
              : TripStringsMcaA2.spotsAddToTrip(n),
          onTap: _planMyDays,
        ));
      }
      if (children.isEmpty) return const SizedBox.shrink();
      return _barFrame(context, children);
    });
  }

  Widget _barFrame(BuildContext context, List<Widget> children) => Container(
        padding: EdgeInsets.fromLTRB(18, 14, 18, AppInsets.bottomViewPadding(context) + 16),
        decoration: const BoxDecoration(
          color: DesignColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: Ink3D.topEdge,
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.fastOutSlowIn,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );

  Widget _buildLimitNotice() {
    return Obx(() {
      if (_pickDay != null || _ctrl.plannerOff.value || !_ctrl.atLimit) return const SizedBox.shrink();
      return _limitNotice();
    });
  }

  Widget _limitNotice() {
    final tripFull = _counts().fold<int>(0, (a, b) => a + b) >= TripConstants.maxSpots;
    final atMax = _creating && !tripFull;
    return Banner3D(
      kind: BannerKind.warn,
      art: ListingArt.clipboard,
      title: tripFull ? TripStringsMcaA2.maxPlaces : atMax ? TripStringsV2Create.maxDaysReached : _limitText,
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 2),
    );
  }
}
