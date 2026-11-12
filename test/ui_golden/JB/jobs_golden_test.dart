import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/jobs/widgets/job_list_card.dart';
import 'package:bakhli/features/jobs/widgets/jobs_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

Widget _cards() => Column(children: [
      JobListCard(
        title: 'Front desk executive for a mountain homestay',
        roleLabel: 'Reception',
        experienceTag: '1+ yrs',
        metaLine: 'Mussoorie, Uttarakhand',
        salaryLabel: '₹18,000 - 25,000',
        salaryUnit: '/month',
        topRightText: '2d ago',
        trailingChip: 'Full time',
        accent: JobsUi.tone.accent,
        accentDark: JobsUi.tone.accentDark,
        onTap: () {},
      ),
      JobListCard(
        title: 'Cook',
        roleLabel: 'Kitchen',
        experienceTag: 'Fresher',
        metaLine: 'Stay name · 3d ago',
        metaIcon: null,
        salaryLabel: '₹12,000',
        topRightBadge: const KitTagChip('ACTIVE', color: DesignColors.primary),
        accent: JobsUi.tone.accent,
        accentDark: JobsUi.tone.accentDark,
        onTap: () {},
        actions: [
          JobListCardAction(icon: Icons.visibility_outlined, label: 'View', color: JobsUi.tone.accentDark, onTap: () {}),
          const JobListCardAction(icon: Icons.close_rounded, label: 'Close', color: DesignColors.error),
        ],
      ),
      JobListCard(
        title: 'Driver',
        roleLabel: 'Transport',
        experienceTag: '3+ yrs',
        metaLine: 'Closed job',
        metaIcon: null,
        salaryLabel: '₹20,000',
        salaryUnit: '/month',
        topRightBadge: const KitTagChip('CLOSED', color: DesignColors.textGrey),
        dimmed: true,
        accent: JobsUi.tone.accent,
        accentDark: JobsUi.tone.accentDark,
        onTap: () {},
      ),
      ListRow.skeleton(),
    ]);

Widget _chips() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, children: [
        JobsDropdownChip(label: 'Department', selected: false, onTap: () {}),
        JobsDropdownChip(label: 'Experience', selected: true, onTap: () {}),
      ]),
      const SizedBox(height: 12),
      JobsChoiceWrap(
        labels: const ['All', 'Kitchen', 'Reception', 'Housekeeping', 'Transport'],
        isActive: (i) => i == 1,
        onTap: (_) {},
      ),
      const SizedBox(height: 12),
      const StateCard(kit: JobsUi.tone, asset: TravelIcon.note, title: 'No jobs yet', message: 'Try another district'),
    ]);

void main() {
  setUpAll(loadGoldenFonts);

  for (final scale in [1.0, 1.3]) {
    final tag = scale == 1.0 ? '1_0' : '1_3';
    for (final entry in {'job_cards': _cards, 'job_chips': _chips}.entries) {
      testWidgets('${entry.key} at $scale', (t) async {
        setGoldenView(t, const Size(360, 1100));
        await t.pumpWidget(goldenHost(entry.value(), scale: scale));
        await settleGolden(t);
        expect(t.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('golden_root')),
          matchesGoldenFile('goldens/${entry.key}_$tag.png'),
        );
      });
    }
  }

  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final entry in {'job_cards': _cards, 'job_chips': _chips}.entries) {
        testWidgets('${entry.key} fits ${w.toInt()}dp at $scale', (t) async {
          setGoldenView(t, Size(w, 1400));
          await t.pumpWidget(goldenHost(entry.value(), scale: scale));
          await settleGolden(t);
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
