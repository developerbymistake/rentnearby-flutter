import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_live.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/plus_widgets.dart';
import '../data/join_api.dart';
import '../social_strings_b.dart';
import '../widgets/social_widgets_b.dart';

class JoinRequestSheet extends StatefulWidget {
  const JoinRequestSheet({super.key, required this.trip, this.api = const JoinApi()});

  final PublicTrip trip;
  final JoinApi api;

  static const Key noteKey = ValueKey('join_note');
  static const Key sendKey = ValueKey('join_send');

  static Future<bool> show(BuildContext context, PublicTrip trip, {JoinApi api = const JoinApi()}) async {
    final ok = await Sheet3D.show<bool>(context, builder: (_) => JoinRequestSheet(trip: trip, api: api));
    return ok == true;
  }

  @override
  State<JoinRequestSheet> createState() => _JoinRequestSheetState();
}

class _JoinRequestSheetState extends State<JoinRequestSheet> {
  final _note = TextEditingController();
  final String _clientRequestId = const Uuid().v4();
  bool _busy = false;
  String? _error;

  static const Set<String> _staleTypes = {
    SocialErrorTypes.tripFull,
    SocialErrorTypes.joinClosed,
    SocialErrorTypes.alreadyRequested,
    SocialErrorTypes.alreadyMember,
    SocialErrorTypes.askAgainLater,
    SocialErrorTypes.tripGenderMismatch,
  };

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await widget.api.send(widget.trip.tripId, note: _note.text, clientRequestId: _clientRequestId);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case BuddyOk():
        SocialLive.joinRequests.value++;
        SocialMeController.maybe?.refreshQuiet();
        Navigator.of(context).pop(true);
      case BuddyRefused(:final type, :final message, :final data):
        if (PlusSheets.handles(type)) {
          final nav = Navigator.of(context);
          final host = nav.context;
          nav.pop(false);
          if (host.mounted) await PlusSheets.limitReached(host, errorType: type!, data: data, from: 'join');
          return;
        }
        if (_staleTypes.contains(type)) SocialLive.posts.value++;
        setState(() => _error = message ?? SocialStrings.failed);
      case BuddyOffline():
        setState(() => _error = SocialStrings.offline);
      case BuddyFailed():
        setState(() => _error = SocialStrings.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final first = t.owner.name.trim().split(RegExp(r'\s+')).first;
    final limits = SocialMeController.maybe?.me.value?.limits;
    final tone = BuddyLook.teal;
    final seed = SocialLookB.seedOf(t.cityKey, t.tripId);
    return Sheet3D(
      tone: tone,
      title: SocialStringsB.requestToJoin,
      centerTitle: false,
      size: SheetSize.form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: DS.insets(l: 12, t: 10, r: 12, b: 10),
            decoration: BoxDecoration(color: Form3D.fill, borderRadius: DS.circular(16)),
            child: Row(
              children: [
                Container(
                  width: DS.s(54),
                  height: DS.s(54),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: SocialLookB.toneOf(seed).gradient, borderRadius: DS.circular(10)),
                  child: TripCoverArt(cityKey: t.cityKey, seed: seed, size: 38),
                ),
                Gap.h(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(SocialStringsB.sheetSummary(t), maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                      Text(SocialStringsB.sheetSub(t), maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Gap.v(16),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '${SocialStringsB.noteLabel(first)} ', style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
              TextSpan(text: SocialStringsB.optional, style: Ink3D.text(14, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
            ]),
          ),
          Gap.v(8),
          Container(
            padding: DS.sym(h: 14, v: 10),
            constraints: BoxConstraints(minHeight: DS.s(84)),
            decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), border: Border.all(color: Form3D.outline, width: DS.s(1.5))),
            child: TextField(
              key: JoinRequestSheet.noteKey,
              controller: _note,
              enabled: !_busy,
              maxLines: 4,
              minLines: 3,
              inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(JoinApi.noteMax)],
              style: Ink3D.text(14.5, FontWeight.w400, Ink3D.body, height: 1.45, letterSpacing: 0),
              decoration: const InputDecoration(
                isCollapsed: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          Gap.v(6),
          Row(
            children: [
              Expanded(child: Text(SocialStringsB.noteSeen(first), style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0))),
              Text(SocialStringsB.counter(_note.text.characters.length, JoinApi.noteMax), style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
            ],
          ),
          if (limits != null && !limits.isPlus) ...[
            Gap.v(8),
            Text(SocialStringsB.joinFreeLine(limits.joinRequests), style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub, letterSpacing: 0)),
          ],
          if (_error != null) ...[
            Gap.v(10),
            Text(_error!, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, BuddyLook.dangerText, height: 1.4, letterSpacing: 0)),
          ],
          Gap.v(16),
          GradientPillButton(key: JoinRequestSheet.sendKey, tone: tone, label: SocialStringsB.sendRequest, loading: _busy, onTap: _busy ? null : _send),
        ],
      ),
    );
  }
}
