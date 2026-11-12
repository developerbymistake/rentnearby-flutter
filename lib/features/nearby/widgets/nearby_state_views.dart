import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../nearby_strings.dart';

class NearbyEmpty extends StatelessWidget {
  final String title;
  final String body;
  const NearbyEmpty({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => _Block(title: title, body: body);
}

class NearbyThin extends StatelessWidget {
  const NearbyThin({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: Text(NearbyStrings.thin, textAlign: TextAlign.center, style: TypeTokens.body.copyWith(color: DesignColors.textSecondary)),
        ),
      );
}

class NearbyError extends StatelessWidget {
  final VoidCallback onRetry;
  const NearbyError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => _Block(
        title: NearbyStrings.errorTitle,
        body: NearbyStrings.errorBody,
        action: TextButton(onPressed: onRetry, child: const Text(NearbyStrings.tryAgain)),
      );
}

class _Block extends StatelessWidget {
  final String title;
  final String body;
  final Widget? action;
  const _Block({required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, textAlign: TextAlign.center, style: TypeTokens.title.copyWith(color: DesignColors.textStrong)),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: TypeTokens.body.copyWith(color: DesignColors.textSecondary)),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ]),
        ),
      );
}
