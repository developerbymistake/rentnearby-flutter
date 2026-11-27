import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../design/design.dart';
import '../../../nearby/nearby_strings.dart';
import '../../../nearby/widgets/nearby_state_views.dart';
import '../../ways/widgets/taxi_ways_entry_card.dart';
import '../taxi_card.dart';
import '../taxi_navigation.dart';
import 'route_cities_strip.dart';
import 'taxi_feed_repository.dart';
import 'taxi_journey_date.dart';
import 'taxi_results_controller.dart';
import 'taxi_search_strings.dart';

export 'taxi_results_controller.dart' show TaxiResultsArgs;

class TaxiResultsScreen extends StatefulWidget {
  const TaxiResultsScreen({super.key});

  @visibleForTesting
  static TaxiResultsController Function(TaxiResultsArgs args) create = _make;

  static TaxiResultsController _make(TaxiResultsArgs args) => TaxiResultsController(args: args);

  @override
  State<TaxiResultsScreen> createState() => _TaxiResultsScreenState();
}

class _TaxiResultsScreenState extends State<TaxiResultsScreen> {
  static int _seq = 0;

  TaxiResultsController? _ctrl;
  String _tag = TaxiResultsController.tag;
  final _scroll = ScrollController();
  Timer? _dayTimer;
  AppLifecycleListener? _life;

  static final _tone = ListingTone.coral;

  @override
  void initState() {
    super.initState();
    final args = TaxiResultsArgs.fromMap(Get.arguments, TaxiJourneyDate.today());
    if (args == null) {
      if (Get.isRegistered<TaxiResultsController>(tag: _tag)) {
        _ctrl = Get.find<TaxiResultsController>(tag: _tag);
        _watchDay();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return;
    }
    // Own tag per page: a page still animating out keeps its controller until its own dispose.
    _tag = '${TaxiResultsController.tag}-${++_seq}';
    _ctrl = Get.put(TaxiResultsScreen.create(args), tag: _tag, permanent: true);
    _watchDay();
  }

  void _watchDay() {
    _life = AppLifecycleListener(onResume: _dayChanged);
    _armDay();
  }

  void _armDay() {
    final c = _ctrl;
    _dayTimer?.cancel();
    if (c != null) _dayTimer = Timer(c.untilNextDay + const Duration(seconds: 1), _dayChanged);
  }

  void _dayChanged() {
    if (!mounted) return;
    _ctrl?.checkDay();
    _armDay();
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    _life?.dispose();
    _scroll.dispose();
    final c = _ctrl;
    if (c != null && Get.isRegistered<TaxiResultsController>(tag: _tag) && identical(Get.find<TaxiResultsController>(tag: _tag), c)) {
      Get.delete<TaxiResultsController>(tag: _tag, force: true);
    }
    // The page owns its controller: close it even if the registry entry was already dropped.
    if (c != null && !c.isClosed) c.onDelete();
    super.dispose();
  }

  void _back() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: KitStatusBar(
        lightIcons: false,
        child: SafeArea(
          bottom: false,
          child: c == null
              ? TopBar3D(tone: _tone, title: TaxiSearchStrings.pageTitle, subtitle: TaxiSearchStrings.pageSubtitle, onBack: _back)
              : RefreshIndicator(
                  color: _tone.g2,
                  backgroundColor: DesignColors.surface,
                  onRefresh: c.pullRefresh,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _header(c)),
                      _body(c),
                      SliverToBoxAdapter(child: SizedBox(height: DS.s(32) + MediaQuery.paddingOf(context).bottom)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _header(TaxiResultsController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TopBar3D(tone: _tone, title: TaxiSearchStrings.pageTitle, subtitle: TaxiSearchStrings.pageSubtitle, onBack: _back),
        Obx(() {
          c.date.value;
          final error = c.loadFailed.value && c.route.value == null;
          return TaxiRouteCard(
            fromName: c.from.name,
            toName: c.to.name,
            dateText: error ? null : TaxiSearchStrings.barText(c.date.value, isToday: c.isToday),
            canPrev: c.canPrev,
            canNext: c.canNext,
            onPrev: c.prevDay,
            onNext: c.nextDay,
            onChange: _back,
          );
        }),
        Obx(() {
          final r = c.route.value;
          final error = c.loadFailed.value && r == null;
          final empty = r != null && r.isEmpty;
          if (error || empty) return const SizedBox.shrink();
          final count = c.freeCount;
          final showCount = count != null && r != null && !(c.isLoading.value && r.tiers.isEmpty);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SortRow(value: c.sort.value, onChanged: c.setSort),
              if (showCount)
                Padding(
                  padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(4), DS.s(18), 0),
                  child: Text(
                    TaxiSearchStrings.freeCount(count, c.date.value),
                    style: Ink3D.text(12.5, FontWeight.w500, Ink3D.sub, height: 1.45),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }

  void _open(TaxiFeedItem f) => TaxiNavigation.openDetail(
        f.id,
        matchedFare: f.item.isMatch ? f.item.matchedFare : null,
        matchedToName: f.item.isMatch ? f.item.matchedToName : null,
      );

  Widget _title(String text) => TitleRow3D(title: text, tone: _tone);

  Widget _card(TaxiFeedItem f, {int index = 0}) => EntranceOnce(
        key: ValueKey('${f.id}-$index'),
        index: index,
        child: TaxiCard(item: f.item, onOpen: () => _open(f), distance: f.distance),
      );

  Widget _tierTitle(TaxiTier t, TaxiResultsController c) {
    switch (t.key) {
      case TaxiTierKey.onRoute:
        return _title(NearbyStrings.driversOnRoute);
      case TaxiTierKey.passing:
        return _title(NearbyStrings.driversPassing);
      case TaxiTierKey.basedNearFrom:
        return _title(NearbyStrings.driversBasedNearby);
      default:
        return _title(NearbyStrings.taxisInTo(t.header?.centreCityName ?? c.to.name));
    }
  }

  Widget _showMore(TaxiTier t, TaxiResultsController c) {
    return Obx(() {
      final loading = c.loadingTiers.contains(t.key);
      return Padding(
        padding: EdgeInsets.fromLTRB(DS.s(KitMetrics.gutter), DS.gv(4), DS.s(KitMetrics.gutter), DS.gv(8)),
        child: loading
            ? Center(child: SizedBox(height: DS.s(24), width: DS.s(24), child: CircularProgressIndicator(strokeWidth: DS.s(2), color: _tone.g2)))
            : Center(child: ListingFilterChip(tone: _tone, label: NearbyStrings.showMore, selected: false, onTap: () => c.showMoreOf(t.key))),
      );
    });
  }

  Widget _body(TaxiResultsController c) {
    return Obx(() {
      final r = c.route.value;
      final waysAvailable = c.waysCheck.isAvailable;
      if (r == null) {
        if (c.loadFailed.value) {
          return SliverList.list(children: [
            StateCard3D(
              tone: _tone,
              art: ListingArt.warning,
              title: TaxiSearchStrings.errorTitle,
              message: TaxiSearchStrings.errorBody,
              actionLabel: TaxiSearchStrings.tryAgain,
              onAction: c.retry,
            ),
          ]);
        }
        return SliverList.builder(itemCount: 4, itemBuilder: (_, _) => const TaxiCardSkeleton());
      }
      final children = <Widget>[];
      final shown = [for (final t in r.tiers) if (t.items.isNotEmpty) t];
      if (shown.isEmpty) {
        children.add(NearbyEmpty(
          title: TaxiSearchStrings.emptyTitle(c.date.value),
          body: TaxiSearchStrings.emptyBody,
          tone: _tone,
          art: ListingArt.search,
        ));
      } else {
        children.add(RouteCitiesStrip(
          fromLat: c.from.latLng.latitude,
          fromLng: c.from.latLng.longitude,
          toLat: c.to.latLng.latitude,
          toLng: c.to.latLng.longitude,
          fromName: c.fromNearYou ? null : c.from.name,
          toName: c.to.name,
        ));
      }
      for (final t in shown) {
        final open = !t.collapsed || c.isExpanded(t.key);
        children.add(_tierTitle(t, c));
        if (open) {
          for (var i = 0; i < t.items.length; i++) {
            children.add(_card(t.items[i], index: i));
          }
        }
        if ((t.collapsed && !open) || (open && t.hasMore)) children.add(_showMore(t, c));
      }
      if (waysAvailable) {
        children.add(TaxiWaysEntryCard(from: c.from, to: c.to, empty: !r.hasRouteDrivers, fromMyLocation: c.fromNearYou));
      }
      return SliverList.list(children: children);
    });
  }
}

// Route summary on top of the results: From -> To, a Change chip back to the search card, the date between day arrows.
class TaxiRouteCard extends StatelessWidget {
  const TaxiRouteCard({
    super.key,
    required this.fromName,
    required this.toName,
    required this.dateText,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onChange,
  });

  final String fromName;
  final String toName;
  final String? dateText;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onChange;

  static const changeKey = ValueKey('taxi-route-change');

  Widget _name(String text, TextStyle style) => Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style));

  @override
  Widget build(BuildContext context) {
    final p = ListingPalette.coral;
    final style = Ink3D.text(14, FontWeight.w600, Ink3D.body);
    final date = dateText;
    return WhiteCard3D(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: TaxiSearchStrings.routeSemantics(fromName, toName),
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      Art3D(asset: ListingArt.roundPushpin, size: 24, shadowBlur: 3, shadowOffset: const Offset(1, 2)),
                      Gap.h(6),
                      _name(fromName, style),
                      Padding(
                        padding: DS.sym(h: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: DS.s(16), color: p.g2),
                      ),
                      Art3D(asset: ListingArt.search, size: 24, shadowBlur: 3, shadowOffset: const Offset(1, 2)),
                      Gap.h(6),
                      _name(toName, style),
                    ],
                  ),
                ),
              ),
              Gap.h(8),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Semantics(
                    label: TaxiSearchStrings.changeLabel,
                    button: true,
                    onTap: onChange,
                    excludeSemantics: true,
                    child: ListingFilterChip(key: changeKey, tone: ListingTone.coral, label: TaxiSearchStrings.change, selected: false, onTap: onChange),
                  ),
                ),
              ),
            ],
          ),
          if (date != null) ...[
            Container(height: DS.s(1), margin: EdgeInsets.only(top: DS.gv(6)), color: p.line),
            Row(
              children: [
                _ArrowButton(icon: Icons.chevron_left_rounded, label: TaxiSearchStrings.prevDay, onTap: canPrev ? onPrev : null),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ExcludeSemantics(child: Art3D(asset: ListingArt.calendar, size: 22, shadowBlur: 3, shadowOffset: const Offset(1, 2))),
                      Gap.h(8),
                      Flexible(
                        child: Text(
                          date,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0),
                        ),
                      ),
                    ],
                  ),
                ),
                _ArrowButton(icon: Icons.chevron_right_rounded, label: TaxiSearchStrings.nextDay, onTap: canNext ? onNext : null),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: SizedBox(
        width: DS.s(44),
        height: DS.s(44),
        child: Center(
          child: Container(
            width: DS.s(36),
            height: DS.s(36),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              shape: BoxShape.circle,
              boxShadow: on ? DS.shadows(Ink3D.softShadow) : null,
              border: on ? null : Border.all(color: Ink3D.line),
            ),
            child: Icon(icon, size: DS.s(22), color: on ? ListingPalette.coral.text : DesignColors.textDisabled),
          ),
        ),
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  Widget _chip(String label, String key) {
    final on = value == key;
    return Semantics(
      selected: on,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(44)),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: ListingFilterChip(tone: ListingTone.coral, label: label, selected: on, onTap: () {
            if (!on) onChanged(key);
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(6), DS.s(18), 0),
      child: Wrap(
        spacing: DS.gh(8),
        runSpacing: DS.gv(6),
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            TaxiSearchStrings.sort,
            style: FitnessAppTheme.caption.copyWith(fontSize: DS.f(12), fontWeight: FontWeight.w600, color: DesignColors.textSecondary),
          ),
          _chip(TaxiSearchStrings.nearest, TaxiRouteSort.nearest),
          _chip(TaxiSearchStrings.cheapest, TaxiRouteSort.cheapest),
        ],
      ),
    );
  }
}
