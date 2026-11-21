import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bakhli/design/design.dart';
import '../features/stay/stay_share_strings.dart';
import '../features/trip/trip_strings.dart';
import '../models/message_model.dart';
import '../utils/app_toast.dart';
import '../utils/contact_launcher.dart';

class StayContactShareCard extends StatelessWidget {
  const StayContactShareCard({super.key, required this.message});

  static const String type = 'stay_contact_share';

  final MessageModel message;

  String? _value(String key) {
    final v = message.payload[key];
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final upi = _value('upiId');
    final wa = _value('whatsApp');
    final stay = _value('stayName');
    if (upi == null && wa == null) return ChatSystemNote(_value('text') ?? StayShareStrings.previewText);
    final tone = ListingTone.forest;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: DS.gv(6)),
      child: Align(
        alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: DS.s(320)),
          child: Container(
            padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(14), DS.s(16), DS.s(12)),
            decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.circular(22), boxShadow: tone.glow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(StayShareStrings.title, style: Ink3D.text(16, FontWeight.w700, Colors.white)),
                if (stay != null) ...[
                  Gap.v(2),
                  Text(stay, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white)),
                ],
                Gap.v(10),
                if (upi != null)
                  _row(
                    label: StayShareStrings.upiLabel,
                    value: upi,
                    action: StayShareStrings.copy,
                    ink: tone.button,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: upi));
                      AppToast.success(StayShareStrings.upiCopied);
                    },
                  ),
                if (upi != null && wa != null) Gap.v(8),
                if (wa != null)
                  _row(
                    label: StayShareStrings.whatsAppLabel,
                    value: '+91 $wa',
                    action: StayShareStrings.openWhatsApp,
                    ink: tone.button,
                    onTap: () => ContactLauncher.whatsApp(wa),
                  ),
                Gap.v(10),
                Text(TripStrings.noPaymentTail, style: Ink3D.text(11.5, FontWeight.w500, Colors.white, height: 1.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row({
    required String label,
    required String value,
    required String action,
    required Color ink,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: DS.s(12), vertical: DS.s(8)),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: Alpha.soft), borderRadius: DS.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Ink3D.text(11.5, FontWeight.w500, Colors.white)),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Colors.white)),
              ],
            ),
          ),
          Gap.h(8),
          Tap3D(
            onTap: onTap,
            label: action,
            exclude: true,
            child: Container(
              constraints: BoxConstraints(minHeight: DS.s(34), minWidth: DS.s(52)),
              padding: EdgeInsets.symmetric(horizontal: DS.s(12), vertical: DS.s(6)),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(17)),
              child: Text(action, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, ink)),
            ),
          ),
        ],
      ),
    );
  }
}
