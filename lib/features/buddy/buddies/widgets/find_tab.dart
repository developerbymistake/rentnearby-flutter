import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/note_banner.dart';
import '../../shared/widgets/section_label.dart';
import '../buddies_strings.dart';
import '../buddy_me.dart';
import '../controllers/buddy_find_controller.dart';
import '../models/buddy_models.dart';
import 'buddy_empty_state.dart';
import 'find_result_card.dart';
import 'username_card.dart';

class FindTab extends StatelessWidget {
  const FindTab({super.key, required this.controller, required this.me, required this.onScan, required this.onMyQr, required this.onOpenBuddy});

  final BuddyFindController controller;
  final BuddyMe me;
  final VoidCallback onScan;
  final VoidCallback onMyQr;
  final void Function(FoundPerson person) onOpenBuddy;

  @override
  Widget build(BuildContext context) => Obx(() {
        final c = controller;
        final s = c.state.value;
        final p = c.person.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FindSearchRow(controller: c, onScan: onScan),
            if (s == FindState.self)
              Padding(
                padding: DS.insets(l: 30, t: 10, r: 30),
                child: Text(BuddiesStrings.ownUsername, style: Ink3D.text(13, FontWeight.w600, BuddyLook.amberText, letterSpacing: 0)),
              ),
            ...switch (s) {
              FindState.idle || FindState.searching || FindState.self => [
                  NoteBanner(art: ListingArt.bulb, text: BuddiesStrings.findHint, tone: NoteTone.teal),
                  SectionLabel(BuddiesStrings.orShowYours, padding: DS.insets(l: 22, t: 24, r: 22, b: 10)),
                  UsernameCard(me: me, actionLabel: BuddiesStrings.myQr, onAction: onMyQr, margin: DS.insets(l: 18, r: 18)),
                ],
              FindState.found when p != null => [
                  SectionLabel(BuddiesStrings.onePersonFound, padding: DS.insets(l: 22, t: 24, r: 22, b: 10)),
                  FindResultCard(
                    person: p,
                    sentHere: c.sentHere.value,
                    busy: c.busy.value,
                    onAdd: c.add,
                    onCancel: c.cancelRequest,
                    onAccept: c.accept,
                    onOpenBuddy: () => onOpenBuddy(p),
                  ),
                ],
              FindState.found || FindState.notFound => [
                  const BuddyEmptyState(art: BuddyArt.magnifier, title: BuddiesStrings.notFoundTitle, line: BuddiesStrings.notFoundLine),
                ],
              FindState.failed => [
                  BuddyEmptyState(
                    art: BuddyArt.antenna,
                    title: BuddiesStrings.failedTitle,
                    line: BuddiesStrings.failedLine,
                    red: true,
                    actionLabel: BuddiesStrings.tryAgain,
                    onAction: c.retry,
                  ),
                ],
              FindState.limited => [
                  const BuddyEmptyState(art: BuddyArt.alarm, title: BuddiesStrings.limitedTitle, line: BuddiesStrings.limitedLine, red: true),
                ],
            },
          ],
        );
      });
}

class FindSearchRow extends StatelessWidget {
  const FindSearchRow({super.key, required this.controller, required this.onScan});

  final BuddyFindController controller;
  final VoidCallback onScan;

  static const Key fieldKey = ValueKey('buddy-find-field');
  static const Key searchKey = ValueKey('buddy-find-search');
  static const Key scanKey = ValueKey('buddy-find-scan');

  @override
  Widget build(BuildContext context) => Obx(() {
        final c = controller;
        final off = c.state.value == FindState.limited;
        final searching = c.state.value == FindState.searching;
        final shadow = [BoxShadow(color: Ink3D.soft.withValues(alpha: Alpha.scrim), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(12))];
        return Padding(
          padding: DS.insets(l: 18, t: 18, r: 18),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  constraints: BoxConstraints(minHeight: DS.s(56)),
                  padding: DS.insets(l: 18, t: 6, r: 6, b: 6),
                  decoration: BoxDecoration(
                    color: off ? BuddyLook.pillOff : DesignColors.surface,
                    borderRadius: DS.circular(38),
                    boxShadow: off ? null : shadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: fieldKey,
                          controller: c.text,
                          focusNode: c.focus,
                          enabled: !off,
                          readOnly: searching,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: false,
                          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(40)],
                          onSubmitted: (_) => c.search(),
                          style: Ink3D.text(15, FontWeight.w500, Ink3D.title, letterSpacing: 0),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            hintText: BuddiesStrings.typeUsername,
                            hintStyle: Ink3D.text(15, FontWeight.w400, BuddyLook.greyText, letterSpacing: 0),
                          ),
                        ),
                      ),
                      Gap.h(8),
                      Tap3D(
                        tapKey: searchKey,
                        onTap: off || searching ? null : () => c.search(),
                        label: BuddiesStrings.searchLabel,
                        exclude: true,
                        child: Container(
                          width: DS.s(44),
                          height: DS.s(44),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: off ? BuddyLook.checkOff : null,
                            gradient: off ? null : BuddyLook.teal.gradient,
                            boxShadow: off
                                ? null
                                : [BoxShadow(color: BuddyLook.tealStart.withValues(alpha: Alpha.v45), offset: DS.shadowOffset(const Offset(3, 6)), blurRadius: DS.shadowBlur(10))],
                          ),
                          child: searching
                              ? SizedBox(width: DS.s(20), height: DS.s(20), child: CircularProgressIndicator(strokeWidth: DS.s(2), color: DesignColors.onPrimary))
                              : Opacity(opacity: off ? Alpha.v55 : Alpha.full, child: Art3D(asset: BuddyArt.magnifier, size: 28, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Gap.h(10),
              Tap3D(
                tapKey: scanKey,
                onTap: off || searching ? null : onScan,
                label: BuddiesStrings.scanLabel,
                exclude: true,
                child: Opacity(
                  opacity: off ? Alpha.v60 : Alpha.full,
                  child: Container(
                    width: DS.s(56),
                    height: DS.s(56),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: off ? BuddyLook.pillOff : DesignColors.surface, boxShadow: off ? null : shadow),
                    child: Icon(Icons.qr_code_scanner_rounded, size: DS.s(26), color: BuddyLook.tealEnd),
                  ),
                ),
              ),
            ],
          ),
        );
      });
}
