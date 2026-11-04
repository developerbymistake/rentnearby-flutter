import 'package:flutter/material.dart';
import '../../taxi_option_sets.dart';

class JourneyHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> chips;

  const JourneyHeader({super.key, required this.title, this.subtitle, this.chips = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: TaxiColors.gradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: Colors.white70)),
                ]),
              ),
            ]),
            if (chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: chips),
              ),
          ]),
        ),
      ),
    );
  }
}
