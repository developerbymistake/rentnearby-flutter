import 'package:bakhli/design/design.dart';
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
              autoHeight: true,
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: SingleChildScrollView(
          padding: DS.sym(h: 16, v: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AverageCard(average: r.average),
              Gap.v(12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _StatCard(value: '${r.ratingCount}', label: DriverRatingStrings.ratings)),
                    Gap.h(12),
                    Expanded(child: _StatCard(value: '${r.ridesCompleted}', label: DriverRatingStrings.completedRides)),
                  ],
                ),
              ),
              if (r.latest.isNotEmpty) ...[
                Gap.v(20),
                Padding(
                  padding: DS.sym(h: 4),
                  child: Text(DriverRatingStrings.latest, style: Ink3D.text(18, FontWeight.w600, Ink3D.title)),
                ),
                Gap.v(12),
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
      padding: DS.sym(h: 20, v: 18),
      decoration: BoxDecoration(
        gradient: ListingTone.indigo.gradient,
        borderRadius: DS.br(CardRadius.hero),
        boxShadow: DS.shadows(ListingTone.indigo.glow()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DriverRatingStrings.average, style: Ink3D.text(14, FontWeight.w500, DesignColors.textInverse)),
          Gap.v(4),
          Text(
            avg == null ? DriverRatingStrings.dash : DriverRatingStrings.averageText(avg),
            style: Ink3D.text(40, FontWeight.w700, DesignColors.textInverse, height: 1.1),
          ),
          Gap.v(6),
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
        borderRadius: DS.br(CardRadius.tile),
        boxShadow: DS.shadows(Ink3D.softShadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Ink3D.text(22, FontWeight.w700, Ink3D.title)),
          Gap.v(2),
          Text(label, style: Ink3D.text(13, FontWeight.w400, Ink3D.copy)),
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
      padding: DS.sym(h: 16, v: 4),
      decoration: BoxDecoration(
        color: DesignColors.card,
        borderRadius: DS.br(CardRadius.hero),
        boxShadow: DS.shadows(Ink3D.softShadow),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: DS.s(1), thickness: DS.s(1), color: Ink3D.line),
            Padding(
              padding: DS.sym(v: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(DriverRatingStrings.dateText(rows[i].date), style: Ink3D.text(14, FontWeight.w600, Ink3D.title)),
                  ),
                  TaxiStars(filled: rows[i].stars, size: 18),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
