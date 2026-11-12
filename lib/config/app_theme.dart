import 'package:animations/animations.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import 'package:bakhli/design/extra/template_ports.dart';
import 'package:bakhli/design/tokens/card_tokens.dart';
import 'package:bakhli/design/tokens/design_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius _cardRadius = CardRadius.tile;
  static const String _font = FitnessAppTheme.fontName;

  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.light,
    primary: DesignColors.primary,
    onPrimary: DesignColors.onPrimary,
    primaryContainer: DesignColors.surfaceTint,
    onPrimaryContainer: DesignColors.primary,
    secondary: DesignColors.primaryLight,
    onSecondary: DesignColors.onPrimary,
    secondaryContainer: DesignColors.infoSoft,
    onSecondaryContainer: DesignColors.textStrong,
    tertiary: DesignColors.accentTeal,
    onTertiary: DesignColors.onPrimary,
    error: DesignColors.error,
    onError: DesignColors.onPrimary,
    errorContainer: DesignColors.errorSoft,
    onErrorContainer: DesignColors.error,
    surface: DesignColors.surface,
    onSurface: DesignColors.textStrong,
    onSurfaceVariant: DesignColors.textSecondary,
    surfaceContainerLowest: DesignColors.surface,
    surfaceContainerLow: DesignColors.surfaceAlt,
    surfaceContainer: DesignColors.scaffold,
    surfaceContainerHigh: DesignColors.surfaceMuted,
    surfaceContainerHighest: DesignColors.surfaceMuted,
    outline: DesignColors.textMuted,
    outlineVariant: DesignColors.divider,
    shadow: DesignColors.shadowBase,
    scrim: DesignColors.scrim,
    surfaceTint: Colors.transparent,
    inverseSurface: DesignColors.snackBackground,
    onInverseSurface: DesignColors.snackText,
    inversePrimary: DesignColors.primaryLight,
  );

  static const TextStyle _button = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: _font,
        colorScheme: _scheme,
        textTheme: FitnessAppTheme.textTheme,
        scaffoldBackgroundColor: DesignColors.scaffold,
        canvasColor: DesignColors.surface,
        dividerColor: DesignColors.divider,
        splashColor: DesignColors.splash,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        splashFactory: InkRipple.splashFactory,
        dividerTheme: const DividerThemeData(
            color: DesignColors.divider, thickness: 1, space: 1),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: SharedAxisPageTransitionsBuilder(
              fillColor: DesignColors.scaffold,
              transitionType: SharedAxisTransitionType.horizontal,
            ),
            TargetPlatform.iOS: SharedAxisPageTransitionsBuilder(
              fillColor: DesignColors.scaffold,
              transitionType: SharedAxisTransitionType.horizontal,
            ),
          },
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          titleTextStyle: TextStyle(
            fontFamily: _font,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: DesignColors.textStrong,
          ),
          iconTheme: IconThemeData(color: DesignColors.textStrong),
          actionsIconTheme: IconThemeData(color: DesignColors.textStrong),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: DesignColors.primary,
            foregroundColor: DesignColors.onPrimary,
            disabledBackgroundColor: DesignColors.surfaceMuted,
            disabledForegroundColor: DesignColors.textDisabled,
            minimumSize: const Size(double.infinity, 54),
            shape: const RoundedRectangleBorder(borderRadius: _radius),
            textStyle: _button,
            elevation: 0,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: DesignColors.primary,
            foregroundColor: DesignColors.onPrimary,
            disabledBackgroundColor: DesignColors.surfaceMuted,
            disabledForegroundColor: DesignColors.textDisabled,
            shape: const RoundedRectangleBorder(borderRadius: _radius),
            textStyle: _button,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: DesignColors.primary,
            disabledForegroundColor: DesignColors.textDisabled,
            side: const BorderSide(color: DesignColors.primary),
            shape: const RoundedRectangleBorder(borderRadius: _radius),
            textStyle: _button,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: DesignColors.primary,
            disabledForegroundColor: DesignColors.textDisabled,
            shape: const RoundedRectangleBorder(borderRadius: _radius),
            textStyle: _button,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: DesignColors.textStrong),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: DesignColors.primary,
          foregroundColor: DesignColors.onPrimary,
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: DesignColors.inputFill,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: _radius,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: _radius,
            borderSide: BorderSide(color: DesignColors.inputBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: _radius,
            borderSide:
                BorderSide(color: DesignColors.inputBorderFocus, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: _radius,
            borderSide: BorderSide(color: DesignColors.inputBorderError),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: _radius,
            borderSide:
                BorderSide(color: DesignColors.inputBorderError, width: 2),
          ),
          hintStyle: TextStyle(
            fontFamily: _font,
            color: DesignColors.inputHint,
            fontSize: 14,
          ),
          labelStyle: TextStyle(
            fontFamily: _font,
            color: DesignColors.inputLabel,
          ),
          errorStyle: TextStyle(fontFamily: _font, color: DesignColors.error),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: DesignColors.inputCursor,
          selectionColor: DesignColors.splash,
          selectionHandleColor: DesignColors.primary,
        ),
        cardTheme: const CardThemeData(
          color: DesignColors.card,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: _cardRadius),
          shadowColor: DesignColors.border,
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: DesignColors.chipBackground,
          selectedColor: DesignColors.chipSelected,
          disabledColor: DesignColors.surfaceMuted,
          surfaceTintColor: Colors.transparent,
          side: BorderSide(color: DesignColors.chipBorder),
          shape: RoundedRectangleBorder(borderRadius: _radius),
          labelStyle: TextStyle(
              fontFamily: _font, fontSize: 14, color: DesignColors.chipLabel),
          secondaryLabelStyle: TextStyle(
              fontFamily: _font,
              fontSize: 14,
              color: DesignColors.chipLabelSelected),
          checkmarkColor: DesignColors.chipLabelSelected,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: DesignColors.navBar,
          selectedItemColor: DesignColors.primary,
          unselectedItemColor: DesignColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: DesignColors.navBar,
          surfaceTintColor: Colors.transparent,
          indicatorColor: DesignColors.primarySoft,
          elevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: DesignColors.dialog,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontFamily: _font,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: DesignColors.textStrong,
          ),
          contentTextStyle: TextStyle(
            fontFamily: _font,
            fontSize: 14,
            color: DesignColors.textPrimary,
          ),
          shape: RoundedRectangleBorder(borderRadius: _cardRadius),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: DesignColors.sheet,
          modalBackgroundColor: DesignColors.sheet,
          surfaceTintColor: Colors.transparent,
          modalBarrierColor: DesignColors.scrim,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: CardRadius.sheet),
        ),
        datePickerTheme: const DatePickerThemeData(
          backgroundColor: DesignColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24))),
          headerBackgroundColor: DesignColors.primary,
          headerForegroundColor: DesignColors.onPrimary,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: DesignColors.primary,
          linearTrackColor: DesignColors.progressTrack,
          circularTrackColor: DesignColors.progressTrack,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: DesignColors.snackBackground,
          contentTextStyle:
              TextStyle(fontFamily: _font, color: DesignColors.snackText),
          actionTextColor: DesignColors.primaryLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: _radius),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? DesignColors.onPrimary
                  : DesignColors.switchThumbOff),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? DesignColors.primary
                  : DesignColors.switchTrackOff),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? DesignColors.primary
                  : Colors.transparent),
          checkColor: WidgetStateProperty.all(DesignColors.onPrimary),
          side: const BorderSide(color: DesignColors.textMuted, width: 1.5),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? DesignColors.primary
                  : DesignColors.textMuted),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: DesignColors.textSecondary,
          textColor: DesignColors.textPrimary,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: DesignColors.primary,
          unselectedLabelColor: DesignColors.textMuted,
          indicatorColor: DesignColors.primary,
          dividerColor: DesignColors.divider,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: DesignColors.primary,
          inactiveTrackColor: DesignColors.progressTrack,
          thumbColor: DesignColors.primary,
          overlayColor: DesignColors.primaryTint,
          trackHeight: 4,
          thumbShape: RingThumbShape(),
          rangeThumbShape: RingRangeThumbShape(),
        ),
        tooltipTheme: const TooltipThemeData(
          decoration: BoxDecoration(
            color: DesignColors.snackBackground,
            borderRadius: _radius,
          ),
          textStyle:
              TextStyle(fontFamily: _font, color: DesignColors.snackText),
        ),
      );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
