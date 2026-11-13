import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';

class ChatNextSlotBubble extends StatelessWidget {
  final VoidCallback onTap;
  final bool sending;
  final Color accent;
  final ListingTone? tone;

  const ChatNextSlotBubble({super.key, required this.onTap, required this.sending, this.accent = FitnessAppTheme.nearlyDarkBlue, this.tone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: ChatAskSlot(
        tone: tone ?? ListingTone.forest,
        label: 'Ask something',
        onTap: sending ? null : onTap,
        enabled: !sending,
      ),
    );
  }
}
