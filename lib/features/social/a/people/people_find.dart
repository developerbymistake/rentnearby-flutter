import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../../buddy/buddies/data/buddies_api.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/scan/scan_rules.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/follow_button.dart';
import '../social_strings_a.dart';
import 'people_widgets.dart';

abstract final class FoundFollowStates {
  static const String following = 'following';
  static const String requested = 'requested';
}

enum PeopleFindState { idle, searching, found, notFound, own, failed, limited }

/// People page top: one row with the username search and the scan QR button, and the found person below it.
class PeopleFindSection extends StatefulWidget {
  const PeopleFindSection({super.key, required this.onScan, this.api = const BuddiesApi()});

  final VoidCallback onScan;
  final BuddiesApi api;

  static const Key fieldKey = ValueKey('people_find_field');
  static const Key searchKey = ValueKey('people_find_search');
  static const Key scanKey = ValueKey('people_find_scan');
  static const Key resultKey = ValueKey('people_find_result');
  static const Key noteKey = ValueKey('people_find_note');

  @override
  State<PeopleFindSection> createState() => _PeopleFindSectionState();
}

class _PeopleFindSectionState extends State<PeopleFindSection> {
  final _text = TextEditingController();
  PeopleFindState _state = PeopleFindState.idle;
  FoundPerson? _person;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _set(PeopleFindState s, [FoundPerson? p]) {
    if (!mounted) return;
    setState(() {
      _state = s;
      _person = p;
    });
  }

  Future<void> _search() async {
    if (_state == PeopleFindState.searching) return;
    final q = ScanRules.normalize(_text.text);
    if (q.isEmpty) return;
    if (_text.text != q) _text.text = q;
    FocusScope.of(context).unfocus();
    if (!ScanRules.isBakhliUsername(q)) {
      _set(PeopleFindState.notFound);
      return;
    }
    final me = Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value : null;
    if (me != null && q == me.username) {
      _set(PeopleFindState.own);
      return;
    }
    _set(PeopleFindState.searching);
    final r = await widget.api.find(q, source: BuddySource.search);
    switch (r) {
      case BuddyOk(:final value):
        final p = value.person;
        if (!value.found || p == null || p.userId.isEmpty) {
          _set(PeopleFindState.notFound);
        } else if (p.relation == BuddyRelation.self || me != null && p.userId == me.id) {
          _set(PeopleFindState.own);
        } else {
          _set(PeopleFindState.found, p);
        }
      case BuddyRefused(:final rateLimited) when rateLimited:
        _set(PeopleFindState.limited);
      case BuddyRefused():
        _set(PeopleFindState.notFound);
      case BuddyOffline() || BuddyFailed():
        _set(PeopleFindState.failed);
    }
  }

  String? get _note => switch (_state) {
        PeopleFindState.notFound => SocialStringsA.noTravellerFound,
        PeopleFindState.own => SocialStringsA.ownUsername,
        PeopleFindState.limited => SocialStringsA.scanTryLater,
        PeopleFindState.failed => SocialStrings.failed,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final note = _note;
    final p = _person;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(),
        if (note != null)
          Padding(
            padding: DS.insets(l: 30, t: 10, r: 30),
            child: Text(note, key: PeopleFindSection.noteKey, style: Ink3D.text(13, FontWeight.w600, BuddyLook.amberText, letterSpacing: 0)),
          ),
        if (_state == PeopleFindState.found && p != null)
          Padding(
            padding: DS.gapInsets(t: 14),
            child: PeopleCard(children: [
              SocialPersonTile(
                key: PeopleFindSection.resultKey,
                person: SocialPerson(userId: p.userId, name: p.name, username: p.username, photoUrl: p.photoUrl, initial: p.initial),
                subtitle: p.username ?? '',
                onTap: () => SocialNav.openTraveller(p.userId),
                actions: Align(
                  alignment: Alignment.centerLeft,
                  child: FollowButton(
                    userId: p.userId,
                    iFollow: p.followState == FoundFollowStates.following,
                    followRequested: p.followState == FoundFollowStates.requested,
                    followsMe: false,
                    compact: true,
                  ),
                ),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _row() {
    final searching = _state == PeopleFindState.searching;
    final shadow = [BoxShadow(color: Ink3D.soft.withValues(alpha: Alpha.scrim), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(12))];
    return Padding(
      padding: DS.insets(l: 18, t: 16, r: 18),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(minHeight: DS.s(56)),
              padding: DS.insets(l: 18, t: 6, r: 6, b: 6),
              decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(38), boxShadow: shadow),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: PeopleFindSection.fieldKey,
                      controller: _text,
                      readOnly: searching,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      enableSuggestions: false,
                      inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(40)],
                      onSubmitted: (_) => _search(),
                      style: Ink3D.text(15, FontWeight.w500, Ink3D.title, letterSpacing: 0),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: SocialStringsA.typeUsername,
                        hintStyle: Ink3D.text(15, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0),
                      ),
                    ),
                  ),
                  Gap.h(8),
                  Tap3D(
                    tapKey: PeopleFindSection.searchKey,
                    onTap: searching ? null : _search,
                    label: SocialStringsA.searchUsername,
                    exclude: true,
                    child: Container(
                      width: DS.s(44),
                      height: DS.s(44),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: BuddyLook.teal.gradient,
                        boxShadow: [BoxShadow(color: BuddyLook.tealStart.withValues(alpha: Alpha.v45), offset: DS.shadowOffset(const Offset(3, 6)), blurRadius: DS.shadowBlur(10))],
                      ),
                      child: searching
                          ? SizedBox(width: DS.s(20), height: DS.s(20), child: CircularProgressIndicator(strokeWidth: DS.s(2), color: DesignColors.onPrimary))
                          : Art3D(asset: BuddyArt.magnifier, size: 28, shadowBlur: 2, shadowOffset: const Offset(1, 2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Gap.h(10),
          Tap3D(
            tapKey: PeopleFindSection.scanKey,
            onTap: searching ? null : widget.onScan,
            label: SocialStringsA.scanQr,
            exclude: true,
            child: Container(
              width: DS.s(56),
              height: DS.s(56),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.surface, boxShadow: shadow),
              child: Icon(Icons.qr_code_scanner_rounded, size: DS.s(26), color: BuddyLook.tealEnd),
            ),
          ),
        ],
      ),
    );
  }
}
