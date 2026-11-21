import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import '../controllers/auth_controller.dart';
import '../features/stay/stay_share_strings.dart';
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

  String? get _myFirstName {
    if (!message.isMine || !Get.isRegistered<AuthController>()) return null;
    final n = Get.find<AuthController>().user.value?.name?.trim() ?? '';
    if (n.isEmpty) return null;
    final i = n.indexOf(' ');
    return i > 0 ? n.substring(0, i) : n;
  }

  @override
  Widget build(BuildContext context) {
    final upi = _value('upiId');
    final wa = _value('whatsAppNumber') ?? _value('whatsApp');
    final stay = _value('stayName');
    if (upi == null && wa == null) return ChatSystemNote(_value('text') ?? StayShareStrings.previewText);
    final tone = ListingTone.forest;
    final first = _myFirstName;
    final sub = message.isMine ? StayShareStrings.sharedByYou : stay;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: DS.gv(6)),
      child: Align(
        alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: DS.s(300)),
          child: Container(
            padding: DS.insets(l: 14, t: 14, r: 14, b: 12),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: DS.circular(14),
              border: Border.all(color: tone.g1.withValues(alpha: Alpha.half)),
              boxShadow: DS.shadows(Ink3D.softShadow),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  ExcludeSemantics(child: Art3D(asset: ListingArt.key, size: 30)),
                  Gap.h(10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(first == null ? StayShareStrings.contactDetails : StayShareStrings.contactDetailsOf(first),
                          style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                      if (sub != null) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                    ]),
                  ),
                ]),
                if (upi != null)
                  _row(
                    label: StayShareStrings.upiLabel,
                    value: upi,
                    action: StayShareStrings.copy,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: upi));
                      AppToast.success(StayShareStrings.upiCopied);
                    },
                  ),
                if (wa != null)
                  _row(
                    label: StayShareStrings.whatsAppLabel,
                    value: '+91 ${_spaced(wa)}',
                    action: StayShareStrings.openWhatsApp,
                    onTap: () => ContactLauncher.whatsApp(wa),
                  ),
                Gap.v(8),
                Text(StayShareStrings.cardFooter, style: Ink3D.text(11, FontWeight.w400, Ink3D.grey, height: 1.35, letterSpacing: 0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _spaced(String wa) => wa.length == 10 ? '${wa.substring(0, 5)} ${wa.substring(5)}' : wa;

  Widget _row({required String label, required String value, required String action, required VoidCallback onTap}) {
    final ink = ListingTone.indigo.text;
    return Container(
      margin: EdgeInsets.only(top: DS.gv(10)),
      padding: EdgeInsets.only(top: DS.gv(10)),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ink3D.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Ink3D.text(11, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
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
              padding: DS.sym(h: 12, v: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(17), border: Border.all(color: ink)),
              child: Text(action, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, ink, letterSpacing: 0)),
            ),
          ),
        ],
      ),
    );
  }
}
