import 'package:flutter/material.dart';

const abritProductName = 'abritdesk';
const abritWebsite = 'https://abritdesk.ir';

enum AbritDestination { home, connection, devices, addressBook, settings }

class AbritLayoutMetrics {
  final double width;
  final double height;
  const AbritLayoutMetrics(this.width, this.height);
  bool get drawer => width < 600;
  bool get compactNavigation => width < 900;
  bool get sideBySide => width >= 1100;
  bool get short => height < 700;
  bool get compactHome => width < 1100 || short;
  bool get homeSideBySide => width - navigationWidth - padding * 2 >= 600;
  double get navigationWidth => drawer
      ? 0
      : compactNavigation
          ? 72
          : 230;
  double get padding => compactNavigation ? 16 : 24;
  bool get compactContent => width - navigationWidth - padding * 2 < 700;
}

class AbritScope extends InheritedWidget {
  final AbritLayoutMetrics metrics;
  final ValueNotifier<AbritDestination> destination;
  const AbritScope(
      {super.key,
      required this.metrics,
      required this.destination,
      required super.child});
  static AbritScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AbritScope>()!;
  @override
  bool updateShouldNotify(AbritScope oldWidget) =>
      metrics.width != oldWidget.metrics.width ||
      metrics.height != oldWidget.metrics.height ||
      destination != oldWidget.destination;
}

String abritText(BuildContext context, String english, String persian) =>
    Localizations.localeOf(context).languageCode == 'fa' ? persian : english;

class AbritColors {
  static const blue = Color(0xFF0071FF);
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF101B2D) : const Color(0xFFF2F7FD);
  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1B2A40) : Colors.white;
  static Color field(BuildContext context) =>
      isDark(context) ? const Color(0xFF253750) : const Color(0xFFF2F6FC);
  static Color foreground(BuildContext context) =>
      isDark(context) ? const Color(0xFFF0F5FF) : const Color(0xFF111827);
  static Color muted(BuildContext context) =>
      isDark(context) ? const Color(0xFFAFBDD0) : const Color(0xFF717B8B);
}

ThemeData abritTheme(ThemeData base, {required bool persian}) {
  final dark = base.brightness == Brightness.dark;
  final background = dark ? const Color(0xFF101B2D) : const Color(0xFFF2F7FD);
  final surface = dark ? const Color(0xFF1B2A40) : Colors.white;
  final field = dark ? const Color(0xFF253750) : const Color(0xFFF2F6FC);
  return base.copyWith(
    primaryColor: AbritColors.blue,
    colorScheme: base.colorScheme.copyWith(
        primary: AbritColors.blue,
        secondary: AbritColors.blue,
        onPrimary: Colors.white,
        surface: surface,
        // Existing settings and peer widgets still read ColorScheme.background.
        // ignore: deprecated_member_use
        background: background),
    scaffoldBackgroundColor: background,
    textTheme: base.textTheme.apply(
      fontFamily: persian ? 'Vazirmatn' : 'NotoSans',
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamily: persian ? 'Vazirmatn' : 'NotoSans',
    ),
    cardColor: surface,
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: field,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: dark ? Colors.white24 : const Color(0xFFDDE5EF))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AbritColors.blue))),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled)
                    ? null
                    : AbritColors.blue),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.disabled) ? null : Colors.white),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))))),
  );
}
