import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../data/trip_repository.dart';
import '../trip_colors.dart';
import '../trip_strings_a4.dart';
import 'trip_city_sheet.dart';

class TripPlanHintStrip extends StatefulWidget {
  const TripPlanHintStrip({super.key, this.legIndex = 1});

  final int legIndex;

  @override
  State<TripPlanHintStrip> createState() => _TripPlanHintStripState();
}

class _TripPlanHintStripState extends State<TripPlanHintStrip> {
  static final _dismissed = <String>{};
  final _c = TripPlanController.to;
  int? _loadedKey;
  TripCitySupply? _supply;

  void _ensureSupply(int cityKey) {
    if (_loadedKey == cityKey) return;
    _loadedKey = cityKey;
    _supply = TripCitySupplyCache.cached(cityKey);
    if (_supply != null) return;
    TripCitySupplyCache.load(cityKey).then((s) {
      if (mounted && _loadedKey == cityKey) setState(() => _supply = s);
    }).catchError((Object _) {});
  }

  bool _hasActivity() {
    final p = _c.plan.value;
    if (p == null) return false;
    if (_c.enquiryList.isNotEmpty) return true;
    return p.days.any((d) => d.stay != null || d.taxi != null || d.stayShortlist.isNotEmpty || d.taxiShortlist.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = _c.plan.value;
      _c.trip.value;
      _c.enquiryList.length;
      _c.isSaving.value;
      final leg = p?.legAt(widget.legIndex);
      if (p == null || leg == null || _c.isReadOnly || _c.supplyPending) return const SizedBox.shrink();
      if (widget.legIndex > 1 && _c.supplyPendingFor(p.legStart(widget.legIndex))) return const SizedBox.shrink();
      if (leg.districtId != null) _ensureSupply(leg.cityKey);
      final supply = _supply;
      final noSupply = leg.districtId == null || (supply != null && supply.stays == 0 && supply.drivers == 0);
      if (noSupply) {
        return _strip(
          icon: Iconsax.info_circle,
          title: TripStringsA4.noSupplyTitle(p.isMultiCity ? leg.cityName : _c.cityName),
          body: TripStringsA4.noSupplyBody,
          fill: AppColors.neutralChip,
          tone: AppColors.textMedium,
        );
      }
      final id = _c.trip.value?.id ?? '';
      if (widget.legIndex != 1) return const SizedBox.shrink();
      if (_hasActivity() || _dismissed.contains(id)) return const SizedBox.shrink();
      return _strip(
        icon: Iconsax.edit_2,
        title: TripStringsA4.hintTitle,
        body: TripStringsA4.hintBody,
        fill: TripColors.surface,
        tone: TripColors.accentDark,
        onClose: () => setState(() => _dismissed.add(id)),
      );
    });
  }

  Widget _strip({
    required IconData icon,
    required String title,
    required String body,
    required Color fill,
    required Color tone,
    VoidCallback? onClose,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 10, onClose == null ? 12 : 0, 10),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tone.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 16, color: tone),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: tone),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
                  ),
                ],
              ),
            ),
            if (onClose != null)
              IconButton(
                onPressed: onClose,
                tooltip: TripStringsA4.dismiss,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(Icons.close_rounded, size: 18, color: tone),
              ),
          ],
        ),
      ),
    );
  }
}
