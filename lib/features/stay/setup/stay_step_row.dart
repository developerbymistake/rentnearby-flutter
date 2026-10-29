import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../widgets/pulse_once.dart';
import 'stay_option_sets.dart';

enum StayStepState { locked, current, done }

class StayStepRow extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final StayStepState state;
  final VoidCallback? onTap;

  const StayStepRow({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.state,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final locked = state == StayStepState.locked;
    final current = state == StayStepState.current;
    return AnimatedOpacity(
      opacity: locked ? 0.45 : 1,
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: locked ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: current ? StayColors.accent : AppColors.divider,
              width: current ? 1.5 : 1,
            ),
            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            _badge(reduceMotion),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              ]),
            ),
            const SizedBox(width: 8),
            _trailing(),
          ]),
        ),
      ),
    );
  }

  Widget _badge(bool reduceMotion) {
    switch (state) {
      case StayStepState.done:
        return TweenAnimationBuilder<double>(
          key: const ValueKey('done'),
          tween: Tween(begin: reduceMotion ? 1.0 : 0.4, end: 1.0),
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
          child: _circle(AppColors.success, const Icon(Icons.check_rounded, color: Colors.white, size: 18)),
        );
      case StayStepState.current:
        return PulseOnce(
          key: ValueKey('current-$number'),
          pulseCount: 1,
          child: _circle(StayColors.accent, _numberText(Colors.white)),
        );
      case StayStepState.locked:
        return _circle(AppColors.divider, _numberText(AppColors.textLight));
    }
  }

  Widget _circle(Color color, Widget child) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: child),
      );

  Widget _numberText(Color color) => Text('$number',
      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: color));

  Widget _trailing() {
    switch (state) {
      case StayStepState.done:
        return const Text('Edit',
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: StayColors.accentDark));
      case StayStepState.current:
        return const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Start',
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
          SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 20, color: StayColors.accentDark),
        ]);
      case StayStepState.locked:
        return const Icon(Iconsax.lock, size: 18, color: AppColors.textHint);
    }
  }
}
