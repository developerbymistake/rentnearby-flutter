import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class SwapOption {
  final String id;
  final String title;
  final String subtitle;
  const SwapOption({required this.id, required this.title, required this.subtitle});
}

class SwapLiveSheet {
  static Future<String?> show(
    BuildContext context, {
    required List<SwapOption> options,
    required Color accent,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                const Text('Swap live listing',
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 4),
                const Text('Pick one to pause. This listing goes live.',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final o = options[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(ctx, o.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accent.withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textDark)),
                                  if (o.subtitle.isNotEmpty)
                                    Text(o.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Pause',
                                style: TextStyle(
                                    fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
