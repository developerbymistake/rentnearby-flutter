import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/models/listing_report_model.dart';
import 'package:bakhli/models/role_model.dart';
import 'package:bakhli/widgets/plan_badge_chip.dart';
import 'package:bakhli/widgets/plan_compare_table.dart';
import 'package:bakhli/widgets/plan_cycle_option.dart';
import 'package:bakhli/widgets/report_row.dart';
import 'package:bakhli/widgets/role_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

String _s(double s) => s == 1.0 ? '1.0' : '1.3';

void _golden(String name, Widget Function() build) {
  for (final scale in [1.0, 1.3]) {
    testWidgets('SA golden $name @${_s(scale)}', (t) async {
      setGoldenView(t);
      await t.pumpWidget(goldenHost(build(), scale: scale));
      await settleGolden(t);
      expect(t.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('golden_root')),
        matchesGoldenFile('goldens/${name}_${_s(scale)}.png'),
      );
    });
  }
}

RoleModel _role(String key) => RoleModel(
      key: key,
      name: RoleVisuals.displayName(key),
      description: 'Plan trips, find stays and taxis near you.',
      sortOrder: 1,
    );

ListingReportModel _report(String type, String status) => ListingReportModel(
      id: '1',
      listingId: 'a',
      listingType: type,
      reasonName: 'Wrong price or details',
      details: '',
      status: status,
      createdAt: DateTime(2026, 1, 2),
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });

  _golden(
    'role_cards',
    () => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RoleOptionCard(role: _role(UserRoleKeys.seeker), selected: true, onTap: () {}),
      const SizedBox(height: 12),
      RoleOptionCard(role: _role(UserRoleKeys.stayOwner), isCurrent: true),
      const SizedBox(height: 12),
      RoleOptionCard(role: _role(UserRoleKeys.taxiDriver), onTap: () {}),
    ]),
  );

  _golden(
    'report_rows',
    () => Column(children: [
      ReportRow(report: _report('Stay', 'Pending'), onTap: () {}),
      ReportRow(report: _report('Taxi', 'Resolved'), onTap: () {}),
      ReportRow(report: _report('Stay', 'Pending'), showKind: false, onTap: () {}),
    ]),
  );

  _golden(
    'plan_blocks',
    () {
      final accent = PlanAccent.of('Stay');
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PlanCompareTable(
          rows: const [
            CompareRow('Shown first', [CompareCell.flag(false), CompareCell.flag(true)]),
            CompareRow('Job posts', [CompareCell.number(1), CompareCell.number(10)]),
          ],
          paidNames: const ['Plus'],
          accent: accent,
        ),
        const SizedBox(height: 20),
        PlanCycleOption(
            title: '3 months',
            subtitle: 'Billed Rs 897 every 3 months',
            price: 'Rs 299',
            perMonth: '/ mo · Save 10%',
            best: true,
            selected: true,
            onTap: () {},
            accent: accent),
        const SizedBox(height: 14),
        PlanCycleOption(
            title: '1 month',
            subtitle: 'Billed monthly',
            price: 'Rs 333',
            perMonth: 'Rs 333 / mo',
            best: false,
            selected: false,
            onTap: () {},
            accent: accent),
        const SizedBox(height: 14),
        Row(children: [PlanBadgeChip(color: accent), const SizedBox(width: 8), PlanBadgeChip(color: accent, compact: false)]),
        const SizedBox(height: 14),
        HeroBanner.skeleton(),
        const SizedBox(height: 12),
        ListRow.skeleton(compact: true, margin: EdgeInsets.zero),
      ]);
    },
  );
}
