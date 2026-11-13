import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art_3d.dart';
import 'pill_buttons_3d.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.requiredMark = false, this.first = false});

  final String text;
  final bool requiredMark;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, first ? 0 : 14, 8, 7),
      child: Text.rich(
        TextSpan(text: text, children: [if (requiredMark) const TextSpan(text: ' *', style: TextStyle(color: Form3D.error))]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Ink3D.text(12.5, FontWeight.w600, Form3D.label, letterSpacing: 0),
      ),
    );
  }
}

class FieldMessage extends StatelessWidget {
  const FieldMessage({super.key, this.error, this.helper, this.counter, this.accent, this.reserve = false});

  final String? error;
  final String? helper;
  final String? counter;
  final Color? accent;
  final bool reserve;

  static TextStyle errorStyle = Ink3D.text(11.5, FontWeight.w600, Form3D.errorText, height: 1.35, letterSpacing: 0);
  static TextStyle helperStyle = Ink3D.text(11.5, FontWeight.w400, Form3D.muted, height: 1.35, letterSpacing: 0);

  @override
  Widget build(BuildContext context) {
    final e = error;
    final h = helper;
    final c = counter;
    final hasError = e != null && e.isNotEmpty;
    final hasHelper = h != null && h.isNotEmpty;
    final hasCounter = c != null && c.isNotEmpty;
    if (!hasError && !hasHelper && !hasCounter) {
      if (!reserve) return const SizedBox.shrink();
      return SizedBox(height: 6 + MediaQuery.textScalerOf(context).scale(11.5) * 1.35);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: hasError
                ? Semantics(liveRegion: true, child: Text(e, maxLines: 3, overflow: TextOverflow.ellipsis, style: errorStyle))
                : Text(hasHelper ? h : '', maxLines: 3, overflow: TextOverflow.ellipsis, style: accent == null ? helperStyle : helperStyle.copyWith(color: accent, fontWeight: FontWeight.w600)),
          ),
          if (hasCounter) Padding(padding: const EdgeInsets.only(left: 8), child: Text(c, maxLines: 1, style: helperStyle)),
        ],
      ),
    );
  }
}

class _FillColor extends WidgetStateColor {
  const _FillColor() : super(0xFFF2F3F8);

  @override
  Color resolve(Set<WidgetState> states) {
    if (states.contains(WidgetState.error)) return Form3D.fillError;
    if (states.contains(WidgetState.disabled)) return Form3D.fillOff;
    return Form3D.fill;
  }
}

class PillField extends StatelessWidget {
  const PillField({
    super.key,
    required this.tone,
    this.controller,
    this.focusNode,
    this.fieldKey,
    this.label,
    this.hint,
    this.leadingArt,
    this.prefixText,
    this.suffixText,
    this.suffix,
    this.errorText,
    this.helperText,
    this.counterText,
    this.reserveMessage = false,
    this.errorRing = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.style,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.autofillHints,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onEditingComplete,
    this.semanticsLabel,
    this.requiredMark = false,
    this.firstLabel = true,
  });

  final ListingTone tone;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final Key? fieldKey;
  final String? label;
  final String? hint;
  final String? leadingArt;
  final String? prefixText;
  final String? suffixText;
  final Widget? suffix;
  final String? errorText;
  final String? helperText;
  final String? counterText;
  final bool reserveMessage;
  final bool errorRing;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final TextStyle? style;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;
  final String? semanticsLabel;
  final bool requiredMark;
  final bool firstLabel;

  static final TextStyle textStyle = Ink3D.text(15, FontWeight.w400, Ink3D.body, letterSpacing: 0);

  static Widget art(String asset, {double size = 30}) => Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Art3D(asset: asset, size: size, shadowBlur: 2, shadowOffset: const Offset(1, 3), shadowAlpha: 0.2),
      );

  static InputDecoration decoration({
    required ListingTone tone,
    String? hint,
    String? errorText,
    String? helperText,
    String? prefixText,
    Widget? prefixIcon,
    Widget? suffix,
    bool area = false,
  }) {
    OutlineInputBorder border(Color color, double width) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(area ? 24 : 26), borderSide: BorderSide(color: color, width: width));
    Widget? prefix;
    if (prefixIcon != null || (prefixText != null && prefixText.isNotEmpty)) {
      prefix = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?prefixIcon,
          if (prefixText != null && prefixText.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: prefixIcon == null ? 18 : 0, right: 8),
              child: Text(prefixText, style: Ink3D.text(15, FontWeight.w700, Form3D.label, letterSpacing: 0)),
            ),
        ],
      );
    }
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: const _FillColor(),
      hintText: hint,
      hintStyle: Ink3D.text(15, FontWeight.w400, Form3D.hint, letterSpacing: 0),
      hintMaxLines: area ? 3 : 1,
      errorText: errorText,
      errorStyle: FieldMessage.errorStyle,
      errorMaxLines: 3,
      helperText: helperText,
      helperStyle: FieldMessage.helperStyle,
      helperMaxLines: 3,
      counterStyle: FieldMessage.helperStyle,
      contentPadding: EdgeInsets.fromLTRB(prefix == null ? 18 : 0, area ? 14 : 15, suffix == null ? 18 : 0, area ? 14 : 15),
      constraints: area ? const BoxConstraints(minHeight: 100) : null,
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix == null ? null : Padding(padding: const EdgeInsets.only(left: 8, right: 18), child: suffix),
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: border(Colors.transparent, 1.5),
      enabledBorder: border(Colors.transparent, 1.5),
      disabledBorder: border(Colors.transparent, 1.5),
      focusedBorder: border(tone.g2, 2),
      errorBorder: border(Form3D.error, 1.5),
      focusedErrorBorder: border(Form3D.error, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final area = (maxLines ?? 2) > 1;
    final l = label;
    final e = errorText;
    final hasError = e != null && e.isNotEmpty;
    final st = suffixText;
    Widget? tail = suffix;
    if (tail == null && st != null && st.isNotEmpty) {
      tail = Text(st, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, tone.text, letterSpacing: 0));
    }
    var deco = decoration(
      tone: tone,
      hint: hint,
      errorText: hasError ? e : null,
      helperText: helperText ?? (reserveMessage && !hasError ? ' ' : null),
      prefixText: prefixText,
      prefixIcon: leadingArt == null ? null : art(leadingArt!),
      suffix: tail,
      area: area,
    );
    if (counterText != null) deco = deco.copyWith(counterText: counterText);
    if (errorRing && !hasError) deco = deco.copyWith(error: const SizedBox.shrink());

    Widget field = TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines ?? (area ? 3 : null),
      style: enabled ? (style ?? textStyle) : (style ?? textStyle).copyWith(color: Form3D.hint),
      textAlignVertical: area ? TextAlignVertical.top : TextAlignVertical.center,
      cursorColor: tone.g2,
      autofocus: autofocus,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      autofillHints: autofillHints,
      validator: validator,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      decoration: deco,
    );
    field = TextSelectionTheme(
      data: TextSelectionThemeData(cursorColor: tone.g2, selectionHandleColor: tone.g2, selectionColor: tone.g2.withValues(alpha: 0.25)),
      child: field,
    );
    if (semanticsLabel != null) field = Semantics(label: semanticsLabel, child: field);
    if (l == null || l.isEmpty) return field;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [FieldLabel(l, requiredMark: requiredMark, first: firstLabel), field],
    );
  }
}

class PillPickerField extends StatelessWidget {
  const PillPickerField({
    super.key,
    required this.tone,
    required this.onTap,
    this.label,
    this.value,
    this.hint,
    this.sublabel,
    this.leadingArt,
    this.errorText,
    this.helperText,
    this.errorRing = false,
    this.enabled = true,
    this.trailing,
    this.reserveMessage = false,
    this.semanticsLabel,
    this.raised = false,
    this.requiredMark = false,
    this.firstLabel = true,
  });

  final ListingTone tone;
  final VoidCallback? onTap;
  final String? label;
  final String? value;
  final String? hint;
  final String? sublabel;
  final String? leadingArt;
  final String? errorText;
  final String? helperText;
  final bool errorRing;
  final bool enabled;
  final Widget? trailing;
  final bool reserveMessage;
  final String? semanticsLabel;
  final bool raised;
  final bool requiredMark;
  final bool firstLabel;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final has = v != null && v.isNotEmpty;
    final e = errorText;
    final bad = errorRing || (e != null && e.isNotEmpty);
    final l = label;
    final s = sublabel;
    final a = leadingArt;
    final live = enabled && onTap != null;
    final h = raised ? 56.0 : 52.0;

    Widget build0(bool showArt) => Container(
      constraints: BoxConstraints(minHeight: h),
      padding: EdgeInsets.fromLTRB(a == null || !showArt ? 18 : 10, 6, 14, 6),
      decoration: BoxDecoration(
        color: bad ? Form3D.fillError : (raised ? Colors.white : (enabled ? Form3D.fill : Form3D.fillOff)),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: bad ? Form3D.error : Colors.transparent, width: 1.5),
        boxShadow: raised && !bad ? Ink3D.softShadow : null,
      ),
      child: Row(
        children: [
          if (a != null && showArt) ...[
            Art3D(asset: a, size: raised ? 40 : 34, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.22),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s != null && s.isNotEmpty) Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w500, Form3D.todoText, letterSpacing: 0, height: 1.25)),
                FitLine3D(
                  text: has ? v : (hint ?? ''),
                  style: Ink3D.text(15, s == null ? FontWeight.w400 : FontWeight.w600, has && enabled ? Ink3D.body : Form3D.hint, letterSpacing: 0),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          trailing ?? Icon(Icons.arrow_drop_down_rounded, size: 24, color: tone.text),
        ],
      ),
    );
    final pill = LayoutBuilder(builder: (context, box) => build0(box.maxWidth >= 132));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (l != null && l.isNotEmpty) FieldLabel(l, requiredMark: requiredMark, first: firstLabel),
        Tap3D(
          onTap: live ? onTap : null,
          label: semanticsLabel ?? [?l, ?s, has ? v : (hint ?? '')].join(', '),
          exclude: true,
          child: pill,
        ),
        FieldMessage(error: e, helper: helperText, reserve: reserveMessage),
      ],
    );
  }
}

class PillStatusBox extends StatelessWidget {
  const PillStatusBox.loading({super.key, required this.tone})
      : text = null,
        onTap = null;
  const PillStatusBox.retry({super.key, required this.tone, required String this.text, required this.onTap});

  final ListingTone tone;
  final String? text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = text;
    if (t == null) {
      return Semantics(
        label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
        child: Container(
          height: 52,
          decoration: BoxDecoration(color: Form3D.fill, borderRadius: BorderRadius.circular(26)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: tone.g2.withValues(alpha: 1 - i * 0.3)),
                ),
            ],
          ),
        ),
      );
    }
    return Tap3D(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Form3D.fillError, borderRadius: BorderRadius.circular(26)),
        child: Text(t, maxLines: 3, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w700, Form3D.errorText, letterSpacing: 0)),
      ),
    );
  }
}
