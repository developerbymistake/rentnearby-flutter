import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../jobs/models/job_summary_model.dart';
import '../../jobs/models/my_job_model.dart';
import '../../owner_core/look/owner_look.dart';
import '../strings/stay_work_strings.dart';

const double _btnFont = 13;

class StayJobCard extends StatelessWidget {
  const StayJobCard({super.key, required this.job, required this.onView, this.onEdit, this.onClose});

  final MyJobModel job;
  final VoidCallback onView;
  final VoidCallback? onEdit;
  final VoidCallback? onClose;

  static String _meta(MyJobModel j) {
    final ago = StayWorkStrings.ago(j.createdAt, DateTime.now());
    final stay = j.stayName;
    return stay == null || stay.isEmpty ? ago : '$stay · $ago';
  }

  @override
  Widget build(BuildContext context) {
    final green = OwnerLook.stay.tone;
    final active = job.isActive;
    final chips = [StayWorkStrings.experience(job.minimumExperienceYears), if (job.foodAndStay) StayWorkStrings.foodAndStay];
    return Semantics(
      container: true,
      label: '${job.title}, ${active ? StayWorkStrings.jobActive : StayWorkStrings.jobClosed}',
      child: Opacity(
        opacity: active ? Alpha.full : Alpha.strong,
        child: Container(
          margin: DS.gapInsets(l: 14, t: 12, r: 14),
          padding: DS.insets(l: 14, t: 14, r: 14, b: 14),
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.tile), boxShadow: DS.shadows(Ink3D.softShadow)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              ExcludeSemantics(
                child: Container(
                  width: DS.s(64),
                  height: DS.s(64),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: green.tint),
                  child: Art3D(asset: ListingArt.briefcase, size: 38),
                ),
              ),
              Gap.h(12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  StatusPill3D(label: active ? StayWorkStrings.jobActive : StayWorkStrings.jobClosed, color: active ? StatusTone3D.both.pillText : StatusTone3D.closed.pillText, onGradient: false),
                  Gap.v(4),
                  Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                  Text(_meta(job), maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                ]),
              ),
            ]),
            Gap.v(8),
            Wrap(spacing: DS.gh(6), runSpacing: DS.gv(6), children: [
              for (final c in chips)
                Container(
                  padding: DS.sym(h: 8, v: 3),
                  decoration: BoxDecoration(color: green.tint, borderRadius: DS.circular(8)),
                  child: Text(c, style: Ink3D.text(11, FontWeight.w700, green.text, letterSpacing: 0)),
                ),
            ]),
            Gap.v(10),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${StayWorkStrings.salary}  ', style: Ink3D.text(10, FontWeight.w700, Ink3D.sub, letterSpacing: 0.6)),
                TextSpan(text: jobSalaryLabel(job.minSalary, job.maxSalary), style: Ink3D.text(17, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                if (job.salaryTypeName == 'Monthly') TextSpan(text: '  ${StayWorkStrings.perMonth}', style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
              ]),
            ),
            if (active) ...[
              Gap.v(8),
              Row(children: [
                ExcludeSemantics(child: Art3D(asset: ListingArt.speechBalloon, size: 16)),
                Gap.h(8),
                Expanded(child: Text(StayWorkStrings.applicantsLine, style: Ink3D.text(12, FontWeight.w500, Ink3D.body, letterSpacing: 0))),
              ]),
            ],
            Gap.v(12),
            Row(children: [
              Expanded(child: WhitePillButton(tone: green, label: StayWorkStrings.view, height: 42, fontSize: _btnFont, onTap: onView)),
              if (onEdit != null) ...[
                Gap.h(8),
                Expanded(child: WhitePillButton(tone: green, label: StayWorkStrings.edit, height: 42, fontSize: _btnFont, onTap: onEdit)),
              ],
              if (onClose != null) ...[
                Gap.h(8),
                Expanded(child: WhitePillButton(tone: green, label: StayWorkStrings.close, height: 42, fontSize: _btnFont, onTap: onClose)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
