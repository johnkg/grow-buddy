import 'package:flutter/material.dart';

const _bodyFont = 'Figtree';
const _displayFont = 'Bricolage';

/// Sun amber. Reserved for sun and warnings, so it stays the same in both themes.
const sunAmber = Color(0xFFF5A524);
const onSunAmber = Color(0xFF12261C);

const _light = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF1F5B3A),
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFCFE5D3),
  onPrimaryContainer: Color(0xFF12261C),
  secondary: Color(0xFF3F6E52),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFE3EFE4),
  onSecondaryContainer: Color(0xFF12261C),
  tertiary: sunAmber,
  onTertiary: onSunAmber,
  tertiaryContainer: Color(0xFFFFF1D6),
  onTertiaryContainer: Color(0xFF12261C),
  error: Color(0xFFB3361F),
  onError: Colors.white,
  errorContainer: Color(0xFFF6D9D2),
  onErrorContainer: Color(0xFF5A1708),
  surface: Color(0xFFF4F7F2),
  onSurface: Color(0xFF12261C),
  onSurfaceVariant: Color(0xFF4A5F53),
  outline: Color(0xFF6B7F73),
  outlineVariant: Color(0xFFDCE5DA),
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Colors.white,
  surfaceContainer: Color(0xFFEEF2EC),
  surfaceContainerHigh: Color(0xFFE8EEE6),
  surfaceContainerHighest: Color(0xFFE3EAE1),
);

const _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF8FD0A6),
  onPrimary: Color(0xFF0B2316),
  primaryContainer: Color(0xFF24533A),
  onPrimaryContainer: Color(0xFFD7EEDD),
  secondary: Color(0xFFA9CDB5),
  onSecondary: Color(0xFF0B2316),
  secondaryContainer: Color(0xFF263A2F),
  onSecondaryContainer: Color(0xFFD7EEDD),
  tertiary: sunAmber,
  onTertiary: onSunAmber,
  tertiaryContainer: Color(0xFF4A3510),
  onTertiaryContainer: Color(0xFFFFE3AD),
  error: Color(0xFFFFB4A3),
  onError: Color(0xFF561100),
  errorContainer: Color(0xFF6B2415),
  onErrorContainer: Color(0xFFFFDAD2),
  surface: Color(0xFF0F1A14),
  onSurface: Color(0xFFE4EDE6),
  onSurfaceVariant: Color(0xFFA9B9AE),
  outline: Color(0xFF7F9186),
  outlineVariant: Color(0xFF2B3B32),
  surfaceContainerLowest: Color(0xFF0B130F),
  surfaceContainerLow: Color(0xFF16231B),
  surfaceContainer: Color(0xFF1B2A21),
  surfaceContainerHigh: Color(0xFF22332A),
  surfaceContainerHighest: Color(0xFF2A3C32),
);

ThemeData growBuddyTheme(Brightness brightness) {
  final scheme = brightness == Brightness.light ? _light : _dark;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _bodyFont,
    scaffoldBackgroundColor: scheme.surface,
  );
  TextStyle display(TextStyle? s, double size, FontWeight w) =>
      (s ?? const TextStyle()).copyWith(
        fontFamily: _displayFont,
        fontSize: size,
        fontWeight: w,
        height: 1.15,
        color: scheme.onSurface,
      );
  final t = base.textTheme;
  final textTheme = t.copyWith(
    headlineMedium: display(t.headlineMedium, 34, FontWeight.w800),
    titleLarge: display(t.titleLarge, 22, FontWeight.w700),
    titleMedium: display(t.titleMedium, 18, FontWeight.w700),
    titleSmall: display(t.titleSmall, 16, FontWeight.w700),
  );
  final pill = StadiumBorder(side: BorderSide(color: scheme.outlineVariant));
  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: display(null, 28, FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: _bodyFont, fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: scheme.onSurface)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: sunAmber,
      foregroundColor: onSunAmber,
      elevation: 3,
      extendedTextStyle: const TextStyle(fontFamily: _bodyFont, fontSize: 16, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    chipTheme: ChipThemeData(
      shape: pill,
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.secondaryContainer,
      selectedColor: scheme.primary,
      checkmarkColor: scheme.onPrimary,
      labelStyle: TextStyle(fontFamily: _bodyFont, fontWeight: FontWeight.w600, color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(fontFamily: _bodyFont, fontWeight: FontWeight.w700, color: scheme.onPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: _bodyFont, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: scheme.outline),
        textStyle: const TextStyle(fontFamily: _bodyFont, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
  );
}
