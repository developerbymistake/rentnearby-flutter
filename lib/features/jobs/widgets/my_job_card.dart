import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../models/my_job_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final active = job.isActive;
    final badgeColor = active ? AppColors.success : AppColors.textHint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: active ? 1 : 0.6,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
            boxShadow: AppShadows.premium(StayColors.accent, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(job.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(active ? 'ACTIVE' : 'CLOSED',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(job.roleName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
            const SizedBox(height: 2),
            Text(job.metaLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: job.salaryLabel),
                if (job.salaryUnit.isNotEmpty)
                  TextSpan(text: ' ${job.salaryUnit}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.gold),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _action(Iconsax.eye, 'View', StayColors.accentDark, onTap)),
              const SizedBox(width: 8),
              Expanded(
                child: active
                    ? _action(Iconsax.close_circle, 'Close', AppColors.error, onClose)
                    : _action(Iconsax.close_circle, 'Closed', AppColors.textHint, null),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback? onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}
