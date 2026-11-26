import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../trip/widgets/taxi_status/taxi_driver_card.dart' show TaxiStars;
import 'controllers/driver_rating_controller.dart';
import 'models/driver_request_models.dart';
import 'strings/driver_rating_strings.dart';

class DriverRatingScreen extends StatefulWidget {
  const DriverRatingScreen({super.key, this.controller, this.onBack});

  final DriverRatingController? controller;
  final VoidCallback? onBack;

  @override
  State<DriverRatingScreen> createState() => _DriverRatingScreenState();
}

class _DriverRatingScreenState extends State<DriverRatingScreen> {
  static const double _maxWidth = 640;

  late final DriverRatingController _c = widget.controller ?? DriverRatingController.to;

  @override
  void initState() {
    super.initState();
    _c.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: ModuleHeader(
              title: DriverRatingStrings.title,
              subtitle: DriverRatingStrings.subtitle,
              titleStyle: TripCustomizeLook.headerTitle,
              subtitleWidget: Text(DriverRatingStrings.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TripCustomizeLook.headerSubtitle),
              autoHeight: true,
              compact: true,
              tone: KitTone.brand,
              gradient: ListingTone.indigo.gradient,
              onBack: widget.onBack ?? () => Get.back(),
            ),
          ),
          Expanded(
            child: Obx(() {
              final r = _c.rating.value;
              return r == null ? _empty() : _content(r);
            }),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    if (_c.loading.value) return const Center(child: CircularProgressIndicator());
    if (!_c.failed.value) return const SizedBox.shrink();
    return Center(
      child: Padding(
        padding: DS.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(DriverRatingStrings.loadFailed, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w600, Ink3D.title)),
            Gap.v(12),
            TextButton(
              onPressed: _c.load,
              child: Text(DriverRatingStrings.tryAgain, style: Ink3D.text(14, FontWeight.w600, DesignColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(DriverRating r) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: SingleChildScrollView(
          padding: DS.insets(l: 18, t: 20, r: 18, b: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AverageCard(average: r.average),
              Gap.v(16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _StatCard(value: '${r.ratingCount}', label: DriverRatingStrings.ratings)),
                    Gap.h(14),
                    Expanded(child: _StatCard(value: '${r.ridesCompleted}', label: DriverRatingStrings.completedRides)),
                  ],
                ),
              ),
              if (r.latest.isNotEmpty) ...[
                Gap.v(22),
                Text(DriverRatingStrings.latest, style: Ink3D.text(19, FontWeight.w600, Ink3D.body, letterSpacing: 0)),
                Gap.v(20),
                _LatestCard(rows: r.latest),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AverageCard extends StatelessWidget {
  const _AverageCard({required this.average});

  final double? average;

  @override
  Widget build(BuildContext context) {
    final avg = average;
    return Container(
      padding: DS.sym(h: 24, v: 22),
      decoration: BoxDecoration(
        gradient: ListingTone.indigo.gradient,
        borderRadius: DS.br(CardRadius.hero),
        boxShadow: ListingTone.indigo.glow(blur: 14, dy: 6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DriverRatingStrings.average, style: Ink3D.text(12.5, FontWeight.w400, DesignColors.textInverse, letterSpacing: 0)),
          Text(
            avg == null ? DriverRatingStrings.dash : DriverRatingStrings.averageText(avg),
            style: Ink3D.text(34, FontWeight.w700, DesignColors.textInverse, height: 1.2, letterSpacing: 0),
          ),
          Gap.v(4),
          avg == null
              ? Text(DriverRatingStrings.noRatings, style: Ink3D.text(14, FontWeight.w500, DesignColors.textInverse))
              : TaxiStars(filled: avg.round(), size: 18),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DS.sym(h: 16, v: 14),
      decoration: BoxDecoration(
        color: DesignColors.card,
        borderRadius: DS.br(TripCustomizeLook.errorRadius),
        boxShadow: DS.shadows(TripLook.cardShadowSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.5, letterSpacing: 0)),
          Text(label, style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, height: 1.5, letterSpacing: 0)),
        ],
      ),
    );
  }
}

class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.rows});

  final List<DriverRatingRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DS.sym(h: 16, v: 6),
      decoration: BoxDecoration(
        color: DesignColors.card,
        borderRadius: DS.br(CardRadius.tile),
        boxShadow: DS.shadows(TripLook.cardShadowSoft),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: DS.s(1), thickness: DS.s(1), color: Ink3D.line),
            Padding(
              padding: DS.sym(v: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: DS.s(24)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(DriverRatingStrings.dateText(rows[i].date), style: Ink3D.text(14, FontWeight.w700, Ink3D.title, height: 1.5, letterSpacing: 0)),
                    ),
                    TaxiStars(filled: rows[i].stars, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
