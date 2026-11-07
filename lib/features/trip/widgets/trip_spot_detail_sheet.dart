import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_colors.dart';
import '../utils/trip_format.dart';
import 'trip_spot_row.dart';

class TripSpotDetailSheet extends StatefulWidget {
  final TripSpotModel spot;
  final bool selected;
  final bool locked;
  final VoidCallback? onToggle;

  const TripSpotDetailSheet({super.key, required this.spot, required this.selected, required this.locked, this.onToggle});

  static Future<void> show(
    BuildContext context, {
    required TripSpotModel spot,
    required bool selected,
    required bool locked,
    VoidCallback? onToggle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => TripSpotDetailSheet(spot: spot, selected: selected, locked: locked, onToggle: onToggle),
    );
  }

  @override
  State<TripSpotDetailSheet> createState() => _TripSpotDetailSheetState();
}

class _TripSpotDetailSheetState extends State<TripSpotDetailSheet> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final photos = spot.gallery;
    final area = spot.area;
    final description = spot.description;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 240,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (photos.isEmpty)
                      TripSpotMedia(spot: spot)
                    else
                      PageView.builder(
                        controller: _page,
                        itemCount: photos.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (_, i) => TripSpotMedia(spot: spot, url: photos[i]),
                      ),
                    if (photos.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < photos.length; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _index ? 16 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i == _index ? Colors.white : Colors.white54,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spot.title,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _meta(TripSpotCategory.label(spot.category)),
                      if (area != null && area.isNotEmpty) _meta(area),
                      _meta('~${TripFormat.visit(spot.visitMinutes)}'),
                    ],
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.45, color: AppColors.textDark),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onToggle == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onToggle!();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.selected ? Colors.white : TripColors.accent,
                        foregroundColor: widget.selected ? TripColors.accentDark : Colors.white,
                        side: widget.selected ? const BorderSide(color: TripColors.accent) : null,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        widget.selected ? (widget.onToggle == null ? 'Added' : 'Remove') : 'Add to list',
                        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.neutralChip, borderRadius: BorderRadius.circular(6)),
        child: Text(
          label,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.neutralChipText),
        ),
      );
}
