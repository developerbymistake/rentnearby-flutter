import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../jobs_colors.dart';
import '../models/my_job_model.dart';
import 'job_list_card.dart';

class MyJobCard extends StatelessWidget {
  final MyJobModel job;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const MyJobCard({
    super.key,
    required this.job,
    required this.onTap,
    required this.onClose,
  });

  static Future<bool> confirmClose(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Close this job?', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text("It will stop showing. You can't reopen it.", style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close job', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Widget _pill(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: fg)),
      );

  @override
  Widget build(BuildContext context) {
    final active = job.isActive;
    return JobListCard(
      title: job.title,
      roleLabel: job.roleName,
      experienceTag: job.experienceLabel,
      metaLine: job.metaLabel,
      metaIcon: null,
      salaryLabel: job.salaryLabel,
      salaryUnit: job.salaryUnit,
      topRightBadge: active
          ? _pill('ACTIVE', AppColors.successSurface, AppColors.successText)
          : _pill('CLOSED', AppColors.neutralChip, AppColors.textLight),
      dimmed: !active,
      onTap: onTap,
      accent: JobColors.accent,
      accentDark: JobColors.accentDark,
      actions: [
        JobListCardAction(icon: Iconsax.eye, label: 'View', color: JobColors.accentDark, onTap: onTap),
        active
            ? JobListCardAction(icon: Iconsax.close_circle, label: 'Close', color: AppColors.error, onTap: onClose)
            : const JobListCardAction(icon: Iconsax.close_circle, label: 'Closed', color: AppColors.textHint),
      ],
    );
  }
}
