import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../config/app_insets.dart';
import '../../../utils/input_formatters.dart';
import '../trip_strings_name.dart';
import '../utils/trip_name_rules.dart';

class TripNameScreen extends StatefulWidget {
  const TripNameScreen({super.key, required this.stateName, required this.cityName, this.initialName});

  final String stateName;
  final String cityName;
  final String? initialName;

  @override
  State<TripNameScreen> createState() => _TripNameScreenState();
}

class _TripNameScreenState extends State<TripNameScreen> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialName ?? TripNameRules.suggest(widget.stateName, widget.cityName),
  );

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

  @override
  Widget build(BuildContext context) {
    final blank = TripNameRules.clean(_ctrl.text).isEmpty;
    return Scaffold(
      backgroundColor: DesignColors.surface,
      body: Column(
        children: [
          ModuleHeader(title: TripStringsName.title, tone: KitTone.trip, onBack: () => Get.back()),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: DS.sym(h: 16, v: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PillField(
                        tone: ListingTone.indigo,
                        label: TripStringsName.label,
                        firstLabel: true,
                        controller: _ctrl,
                        hint: TripStringsName.hint,
                        autofocus: true,
                        errorRing: blank,
                        counterText: '',
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripNameRules.max)],
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _continue(),
                      ),
                      FieldMessage(
                        error: blank ? TripStringsName.empty : null,
                        counter: TripStringsName.counter(_ctrl.text.length),
                        reserve: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(10), DS.s(16), AppInsets.bottomViewPadding(context) + DS.s(10)),
            decoration: BoxDecoration(color: DesignColors.surface, boxShadow: DS.shadows(TripEntryStyle.topShadow)),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: PrimaryButton(label: TripStringsName.next, tone: KitTone.trip, onPressed: _valid ? _continue : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
