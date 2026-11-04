import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';

class TripSheetFrame extends StatelessWidget {
  const TripSheetFrame({super.key, required this.title, this.description, required this.children, this.footer});

  final String title;
  final String? description;
  final List<Widget> children;
  final Widget? footer;

  static Future<T?> show<T>(BuildContext context, Widget child) {
    final height = MediaQuery.sizeOf(context).height;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      constraints: BoxConstraints(maxWidth: 560, maxHeight: height * 0.9),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + AppInsets.bottomViewPadding(context) + 16;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(description!, style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4)),
              ],
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...children,
                if (footer != null) ...[const SizedBox(height: 12), footer!],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
