import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../jobs/models/job_summary_model.dart';
import '../../jobs/models/my_job_model.dart';
import '../../owner_core/home/numbers_row.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/stay_gate_strings_work.dart';
import '../strings/stay_work_strings.dart';

const double _btnFont = 13;

class StayJobCard extends StatelessWidget {
  const StayJobCard({super.key, required this.job, required this.onView, this.onEdit, this.onClose, this.inactiveReason});

  final MyJobModel job;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onClose;
  final String? inactiveReason;

  static String _salary(MyJobModel j) {
    final amount = j.minSalary == j.maxSalary ? jobSalaryLabel(j.minSalary, j.maxSalary) : jobSalaryCompact(j.minSalary, j.maxSalary);
    return j.salaryTypeName == 'Monthly' ? '$amount ${StayWorkStrings.perMonth}' : amount;
  }

  @override
  Widget build(BuildContext context) {
    final green = OwnerLook.stay.tone;
    final active = job.isActive;
    final inactive = inactiveReason != null;
    final status = active ? StayWorkStrings.jobActive : (inactive ? OwnerSharedStrings.inactive : StayWorkStrings.jobClosed);
    final stay = job.stayName;
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        StatusPill3D(label: status, color: active ? StatusTone3D.both.pillText : StatusTone3D.closed.pillText, onGradient: false),
        const Spacer(),
        Text(StayWorkStrings.ago(job.createdAt, DateTime.now()), style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
      ]),
      Gap.v(6),
      Text(job.title, maxLines: 2, style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
      if (stay != null && stay.isNotEmpty) Text(stay, maxLines: 2, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
      Gap.v(10),
      Divider(height: 1, thickness: 1, color: OwnerLook.greySoft),
      OwnerFacts(labelFirst: true, facts: [
        NumberTile(value: _salary(job), label: StayWorkStrings.salary),
        NumberTile(value: StayWorkStrings.experience(job.minimumExperienceYears), label: StayGateStringsWork.experienceLabel),
        NumberTile(value: job.foodAndStay ? StayWorkStrings.foodAndStay : NumberTile.missing, label: StayGateStringsWork.benefitsLabel),
      ]),
      Divider(height: 1, thickness: 1, color: OwnerLook.greySoft),
    ]);
    final view = onView;
    return Semantics(
      container: true,
      label: '${job.title}, $status',
      child: Opacity(
        opacity: active || inactive ? Alpha.full : Alpha.strong,
        child: Container(
          margin: DS.gapInsets(l: 14, t: 12, r: 14),
          padding: DS.insets(l: 14, t: 14, r: 14, b: 14),
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: OwnerLook.cardRadius(), boxShadow: DS.shadows(Ink3D.softShadow)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            inactive ? Opacity(opacity: Alpha.v72, child: body) : body,
            if (active || inactive) ...[
              Gap.v(8),
              Text(inactiveReason ?? StayWorkStrings.applicantsLine, style: Ink3D.text(12, FontWeight.w500, Ink3D.body, letterSpacing: 0)),
            ],
            Gap.v(12),
            Row(children: [
              Expanded(child: GradientPillButton(tone: green, label: StayWorkStrings.view, height: 42, fontSize: _btnFont, enabled: view != null, onTap: view)),
              if (onEdit != null || inactive) ...[
                Gap.h(8),
                Expanded(child: WhitePillButton(tone: green, label: StayWorkStrings.edit, height: 42, fontSize: _btnFont, enabled: onEdit != null, onTap: onEdit)),
              ],
              if (onClose != null) ...[
                Gap.h(8),
                Expanded(child: WhitePillButton(tone: green, label: StayWorkStrings.close, height: 42, fontSize: _btnFont, danger: true, onTap: onClose)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
