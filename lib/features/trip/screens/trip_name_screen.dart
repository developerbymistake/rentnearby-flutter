import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../utils/input_formatters.dart';
import '../trip_strings_name.dart';
import '../utils/trip_name_rules.dart';
import '../widgets/trip_plan_header.dart';

class TripNameScreen extends StatefulWidget {
  const TripNameScreen({super.key, required this.stateName, required this.cityName, this.initialName});

  final String stateName;
  final String cityName;
  final String? initialName;

  @override
  State<TripNameScreen> createState() => _TripNameScreenState();
}

class _TripNameScreenState extends State<TripNameScreen> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialName ?? TripNameRules.suggest(widget.stateName, widget.cityName));

  static const BorderRadius _fieldRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(28), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _valid => TripNameRules.isValid(_ctrl.text);

  void _continue() {
    if (!_valid) return;
    Get.back(result: TripNameRules.clean(_ctrl.text));
  }

  Widget _field(bool bad) {
    final tone = ListingTone.indigo;
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(56)),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(_fieldRadius),
        border: Border.all(color: bad ? DesignColors.error : tone.g2, width: DS.s(2)),
        boxShadow: DS.shadows(TripLook.cardShadowSoft),
      ),
      child: TextSelectionTheme(
        data: TextSelectionThemeData(
          cursorColor: tone.g2,
          selectionHandleColor: tone.g2,
          selectionColor: tone.g2.withValues(alpha: Alpha.v25),
        ),
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripNameRules.max)],
          cursorColor: tone.g2,
          cursorWidth: DS.s(2),
          cursorHeight: DS.s(22),
          style: Ink3D.text(16, FontWeight.w600, TripLook.ink, letterSpacing: 0),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            hintText: TripStringsName.hint,
            hintStyle: Ink3D.text(16, FontWeight.w400, TripLook.mutedText, letterSpacing: 0),
            contentPadding: DS.sym(h: 20, v: 14),
          ),
          onChanged: (_) => setState(() {}),
          onFieldSubmitted: (_) => _continue(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = TripNameRules.problem(_ctrl.text);
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          TripFlowHeader(title: TripStringsName.title, onBack: () => Get.back()),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(28), DS.s(18), DS.gv(20)),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(DS.s(4), 0, DS.s(4), DS.s(10)),
                          child: Text(TripStringsName.label, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, DesignColors.textPrimary, letterSpacing: 0)),
                        ),
                        _field(error != null),
                        Padding(
                          padding: EdgeInsets.fromLTRB(DS.s(6), DS.s(10), DS.s(6), 0),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: DS.s(24)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: error == null
                                      ? const SizedBox.shrink()
                                      : Semantics(
                                          liveRegion: true,
                                          child: Text(error, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w600, TripLook.badText, letterSpacing: 0)),
                                        ),
                                ),
                                Gap.h(12),
                                Text(TripStringsName.counter(_ctrl.text.length), maxLines: 1, style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _bar(),
        ],
      ),
    );
  }

  Widget _bar() {
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(12), DS.s(16), DS.s(16)),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(const BorderRadius.vertical(top: Radius.circular(24))),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: TripNameContinue(onPressed: _valid ? _continue : null),
        ),
      ),
    );
  }
}

class TripNameContinue extends StatelessWidget {
  const TripNameContinue({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final live = onPressed != null;
    final h = DS.s(54);
    return Tap3D(
      onTap: onPressed,
      label: TripStringsName.next,
      exclude: true,
      child: Container(
        height: h,
        alignment: Alignment.center,
        padding: DS.sym(h: 16),
        decoration: BoxDecoration(
          gradient: live ? ListingTone.indigo.gradient : null,
          color: live ? null : TripLook.disabledFill,
          borderRadius: BorderRadius.circular(h / 2),
          boxShadow: live ? DS.shadows(TripLook.pillShadow) : null,
        ),
        child: Text(TripStringsName.next, maxLines: 1, style: Ink3D.text(16, FontWeight.w700, DesignColors.surface, letterSpacing: 0)),
      ),
    );
  }
}
