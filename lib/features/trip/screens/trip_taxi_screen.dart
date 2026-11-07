import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/selectable_chip.dart';
import '../../taxi/guest/taxi_browse_repository.dart';
import '../../taxi/guest/taxi_navigation.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import '../trip_strings_a3.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_arrange_confirm.dart';
import '../widgets/trip_driver_row.dart';
import '../widgets/trip_filter_chips.dart';
import '../widgets/trip_page_header.dart';
import '../widgets/trip_shimmers.dart';
import '../widgets/trip_taxi_booking_sheet.dart';
import 'trip_taxi_enquiry_sheet.dart';

class TripTaxiScreen extends StatefulWidget {
  const TripTaxiScreen({super.key});

  @override
  State<TripTaxiScreen> createState() => _TripTaxiScreenState();
}

class _TripTaxiScreenState extends State<TripTaxiScreen> {
  static const double _maxWidth = 640;

  late final TripPlanController _plan;
  late final TripSupplyController _supply;
  final _scroll = ScrollController();
  final _days = <int>{}.obs;
  final _contactBusy = <String>{}.obs;
  final _contacts = <String, ({String phone, String whatsApp})>{};
  Worker? _planWorker;
  Worker? _daysWorker;

  TripEasyRowKey get _key => const TripEasyRowKey(TripEasyRowKind.taxi);

  List<int> get _sorted => _days.toList()..sort();

  int get _firstDay => _days.isEmpty ? 1 : _sorted.first;

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    _plan.openPages++;
    _supply = TripSupplyController.to;
    final args = Get.arguments;
    final asked = args is Map ? (args['days'] as List?)?.whereType<int>().toList() : null;
    final all = [for (final d in _plan.plan.value?.days ?? const <TripDay>[]) d.day];
    final start = asked == null || asked.isEmpty ? all : asked.where(all.contains).toList();
    final picked = start.isEmpty ? all : start;
    final coming = picked.where((d) => !_plan.isDayPast(d)).toList();
    _days.assignAll(coming.isEmpty ? picked : coming);
    _supply.minSeats.value = null;
    _supply.onlySuv.value = false;
    _ensure();
    _planWorker = ever(_plan.plan, (_) => _ensure());
    _daysWorker = ever(_days, (_) => _ensure());
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _planWorker?.dispose();
    _daysWorker?.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    if (Get.isRegistered<TripPlanController>() && identical(Get.find<TripPlanController>(), _plan)) {
      _plan.openPages--;
      _plan.releaseIfIdle();
    }
    super.dispose();
  }

  void _ensure() {
    final p = _plan.plan.value;
    if (p == null) return;
    final day = _firstDay;
    _supply.ensureTaxis(p.legIndexOf(day), day: day);
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.maxScrollExtent > 0 && p.pixels >= p.maxScrollExtent - 300) _supply.loadMoreTaxis();
  }

  void _toggle(int day) {
    if (_days.contains(day)) {
      if (_days.length == 1) {
        AppToast.warning(TripStringsV2Find.pickDay);
        return;
      }
      _days.remove(day);
    } else {
      _days.add(day);
    }
  }

  String get _cities {
    final p = _plan.plan.value;
    if (p == null) return _plan.cityName;
    final names = <String>[];
    for (final d in _sorted) {
      final n = p.cityNameOf(d);
      if (!names.contains(n)) names.add(n);
    }
    return names.isEmpty ? _plan.cityName : names.join(' + ');
  }

  void _skip() {
    if (_plan.openRowsOf(_key).isNotEmpty || _plan.confirmedRowOf(_key) != null) {
      AppToast.warning(TripStringsV2Find.cancelFirstTaxi);
      return;
    }
    _plan.skipRow(_key);
    TripNavigation.backToPlan();
  }

  Future<void> _arrange() async {
    if (!await TripArrangeConfirm.show(context, _key) || !mounted) return;
    final res = await TripArrangeConfirm.mark(context, _key);
    if (res == null || !mounted) return;
    if (res is TripMarkBlocked) {
      AppToast.warning(TripStringsV2Find.cancelFirstTaxi);
      return;
    }
    TripNavigation.backToPlan();
  }

  void _open(TaxiBrowseItem t) => TaxiNavigation.openDetail(
        t.id,
        whatsAppMessage: _plan.whatsAppMessage(_firstDay, t.driverName),
      );

  Future<({String phone, String whatsApp})?> _loadContact(TaxiBrowseItem t) async {
    if (_contactBusy.contains(t.id)) return null;
    _contactBusy.add(t.id);
    try {
      final d = await const TaxiBrowseRepository().getById(t.id);
      final phone = d.contactPhone;
      if (phone == null || ContactLauncher.tenDigits(phone).isEmpty) {
        _open(t);
        return null;
      }
      final c = (phone: phone, whatsApp: d.whatsAppNumber ?? phone);
      _contacts[t.id] = c;
      return c;
    } catch (_) {
      AppToast.error(TripStringsA3.contactFailed);
      return null;
    } finally {
      _contactBusy.remove(t.id);
    }
  }

  Future<void> _contact(TaxiBrowseItem t, {required bool whatsApp}) async {
    final c = _contacts[t.id] ?? await _loadContact(t);
    if (c == null) return;
    if (whatsApp) {
      await ContactLauncher.whatsApp(c.whatsApp, message: _plan.whatsAppMessage(_firstDay, t.driverName));
    } else {
      await ContactLauncher.call(c.phone);
    }
  }

  TripEnquiryModel? _askedOf(String taxiId) {
    final p = _plan.plan.value;
    if (p == null) return null;
    final leg = p.legIndexOf(_firstDay);
    for (final e in _plan.taxiEnquiries) {
      if (e.listingId != taxiId || !e.isOpen) continue;
      final day = _plan.firstPlanDayOf(e);
      if ((e.cityLeg ?? (day == null ? leg : p.legIndexOf(day))) == leg) return e;
    }
    return null;
  }

  Future<void> _ask(TaxiBrowseItem t) async {
    final asked = _askedOf(t.id);
    if (asked != null) {
      await TripNavigation.openTaxiReplies(_plan.firstPlanDayOf(asked) ?? _firstDay, enquiryId: asked.id);
      return;
    }
    await TripTaxiEnquirySheet.show(context, driver: t, days: _sorted);
  }

  Future<void> _book(TaxiBrowseItem t) async {
    final e = _askedOf(t.id);
    await TripTaxiBookingSheet.show(context, taxi: t, day: _firstDay, enquiry: e, initialFare: e?.taxi?.driverFare);
  }

  void _clearFilters() {
    _supply.minSeats.value = null;
    _supply.onlySuv.value = false;
  }

  Widget _narrow(Widget child) => Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _maxWidth), child: child),
      );

  Widget _dayChip(int day) {
    final date = _plan.dateOf(day);
    final label = date == null ? TripStrings.dayN(day) : '${TripStrings.dayN(day)} · ${TripFormat.shortDate(date)}';
    final locked = _plan.isDayPast(day);
    return Opacity(
      opacity: locked ? 0.4 : 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: SelectableChip(
          label: label,
          selected: _days.contains(day),
          onTap: () {
            if (!locked) _toggle(day);
          },
          activeColor: TaxiColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    );
  }

  Widget _dayChips() {
    final p = _plan.plan.value;
    if (p == null) return const SizedBox.shrink();
    final groups = <Widget>[];
    for (var k = 1; k <= p.legCount; k++) {
      final days = p.daysOf(k);
      if (days.isEmpty) continue;
      groups.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.isMultiCity)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 6),
              child: Text(p.cityNameOf(days.first.day),
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMedium)),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final d in days) _dayChip(d.day)]),
        ],
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(TripStringsV2Find.taxiDays,
          style: TextStyle(
              fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textMedium)),
      const SizedBox(height: 4),
      ...groups,
      const SizedBox(height: 4),
      const Text(TripStringsV2Find.taxiDayNote,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textMedium)),
    ]);
  }

  Widget _buildTop() => Obx(() {
        _plan.plan.value;
        _days.length;
        final showChips = !_plan.isReadOnly && _supply.taxis.isNotEmpty;
        return _narrow(Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dayChips(),
              if (showChips) ...[
                const SizedBox(height: 12),
                TripFilterChips(accent: TaxiColors.accent, items: [
                  TripFilterChip(
                    label: TripStringsA3.seats4,
                    selected: _supply.minSeats.value == 4,
                    onTap: () => _supply.minSeats.value = _supply.minSeats.value == 4 ? null : 4,
                  ),
                  TripFilterChip(
                    label: TripStringsA3.seats6,
                    selected: _supply.minSeats.value == 6,
                    onTap: () => _supply.minSeats.value = _supply.minSeats.value == 6 ? null : 6,
                  ),
                  TripFilterChip(
                    label: TripStringsA3.suv,
                    selected: _supply.onlySuv.value,
                    onTap: () => _supply.onlySuv.value = !_supply.onlySuv.value,
                  ),
                ]),
              ],
            ],
          ),
        ));
      });

  Widget _stateBox({
    required IconData icon,
    required String title,
    required String subtitle,
    List<Widget> actions = const [],
  }) {
    return SliverToBoxAdapter(
      child: _narrow(Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: TripColors.surface, shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: TripColors.accent),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight, height: 1.4)),
            for (final a in actions) ...[const SizedBox(height: 12), a],
          ],
        ),
      )),
    );
  }

  Widget _outlinedAction(String label, IconData icon, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18, color: TripColors.accent),
          label: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: TripColors.accent)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: TripColors.accent, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _skipButton() => TextButton(
        onPressed: _skip,
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        child: const Text(TripStringsV2Find.skip,
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
      );

  Widget _shimmerList() => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        sliver: SliverList.separated(
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => _narrow(TripShimmers.rowBox(height: TripDriverRow.height)),
        ),
      );

  Widget _buildBody() => Obx(() {
        _plan.plan.value;
        _plan.enquiryList.length;
        _days.length;
        if (_plan.isReadOnly) {
          final hasReplies = _plan.taxiEnquiries.isNotEmpty;
          return _stateBox(
            icon: Iconsax.lock,
            title: TripStringsA3.pastTripTitle,
            subtitle: TripStringsA3.readOnlyBody,
            actions: [
              if (hasReplies)
                _outlinedAction(TripStrings.taxiReplies, Iconsax.message, () => TripNavigation.openRepliesForRow(_key)),
            ],
          );
        }
        final items = _supply.taxis;
        if (items.isEmpty && _supply.taxiDistrictId == null && !_plan.taxiTabOff.value) {
          if (_plan.trip.value == null) return _shimmerList();
          return _stateBox(
            icon: Iconsax.car,
            title: TripStringsV2Find.noTaxiTitle,
            subtitle: TripStringsV2Find.noTaxiBody,
            actions: [_outlinedAction(TripStringsV2Find.arrangeMyself, Iconsax.car, _arrange), _skipButton()],
          );
        }
        if (items.isEmpty) {
          if (_supply.taxiLoading.value) return _shimmerList();
          if (_supply.taxiFailed.value) {
            return SliverToBoxAdapter(
              child: EmptyStateView(
                icon: Iconsax.cloud_cross,
                title: TripStringsV2Find.taxisFailed,
                subtitle: TripStringsV2Find.checkConnection,
                onRetry: () => _supply.loadTaxis(),
                retryLabel: TripStringsV2Find.retry,
                palette: TripColors.palette,
              ),
            );
          }
          return _stateBox(
            icon: Iconsax.car,
            title: _plan.taxiTabOff.value ? TripStringsV2Find.taxisPaused : TripStringsV2Find.noTaxiTitle,
            subtitle: TripStringsV2Find.noTaxiBody,
            actions: [
              _outlinedAction(TripStringsV2Find.arrangeMyself, Iconsax.car, _arrange),
              _skipButton(),
              if (!_plan.taxiTabOff.value)
                TextButton(
                  onPressed: () => TaxiNavigation.openList(),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text(TripStrings.seeAllTaxis,
                      style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
                ),
            ],
          );
        }
        final list = _supply.filteredTaxis;
        if (list.isEmpty) {
          return _stateBox(
            icon: Iconsax.filter,
            title: TripStringsA3.noMatchTitle,
            subtitle: TripStringsA3.noMatchBody,
            actions: [_outlinedAction(TripStringsA3.clearFilters, Iconsax.close_circle, _clearFilters)],
          );
        }
        final n = _days.length;
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final t = list[i];
              final asked = _askedOf(t.id);
              return _narrow(Obx(() => TripDriverRow(
                    key: ValueKey('${t.id}-$n'),
                    item: t,
                    fit: _supply.taxiFitOf(t.id),
                    status: asked?.display,
                    days: n,
                    contactBusy: _contactBusy.contains(t.id),
                    onOpen: () => _open(t),
                    onCall: () => _contact(t, whatsApp: false),
                    onWhatsApp: () => _contact(t, whatsApp: true),
                    onAsk: () => _ask(t),
                    menuItems: _menu(),
                    onMenu: (v) => v == 1 ? _book(t) : _open(t),
                  )));
            },
          ),
        );
      });

  List<PopupMenuEntry<int>> _menu() {
    PopupMenuItem<int> item(int v, IconData icon, String label) => PopupMenuItem<int>(
          value: v,
          child: Row(
            children: [
              Icon(icon, size: 18, color: TripColors.accentDark),
              const SizedBox(width: 10),
              Flexible(
                child: Text(label,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textDark)),
              ),
            ],
          ),
        );
    return [
      item(1, Iconsax.receipt_edit, TripStringsA3.iBookedThis),
      item(2, Iconsax.eye, TripStringsA3.viewDetails),
    ];
  }

  Widget _buildFooter() => Obx(() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: SizedBox(
          height: 24,
          child: _supply.taxiLoadingMore.value
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: TripColors.accent),
                  ),
                )
              : null,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) TripNavigation.backToPlan();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(
          children: [
            Obx(() {
              _plan.plan.value;
              _days.length;
              return TripPageHeader(
                title: TripStringsV2Find.taxiTitle,
                subtitle: TripStringsV2Find.taxiSubtitle(_cities),
                onBack: TripNavigation.backToPlan,
                gradient: TaxiColors.gradient,
                trailing: _plan.isReadOnly
                    ? null
                    : TextButton(
                        onPressed: _skip,
                        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                        child: const Text(TripStringsV2Find.skip,
                            style: TextStyle(
                                fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
              );
            }),
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(child: _buildTop()),
                  _buildBody(),
                  SliverToBoxAdapter(child: _buildFooter()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
