import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The design's colour tokens for one brightness.
class _Tokens {
  const _Tokens({
    required this.bg,
    required this.surf,
    required this.ink,
    required this.mute,
    required this.line,
    required this.acc,
    required this.onAcc,
    required this.accSoft,
    required this.accText,
  });

  /// Page background.
  final Color bg;

  /// Cards and sheets.
  final Color surf;
  final Color ink;

  /// Secondary text and icons.
  final Color mute;

  /// Borders and dividers.
  final Color line;
  final Color acc;
  final Color onAcc;
  final Color accSoft;

  /// Accent text on [accSoft] or [surf].
  final Color accText;
}

const _light = _Tokens(
  bg: Color(0xFFF9F6F2),
  surf: Color(0xFFFEFDFB),
  ink: Color(0xFF241E1A),
  mute: Color(0xFF69625D),
  line: Color(0xFFE1DDD8),
  acc: Color(0xFF007B70),
  onAcc: Color(0xFFFFFFFF),
  accSoft: Color(0xFFCFF0EB),
  accText: Color(0xFF00554D),
);

const _dark = _Tokens(
  bg: Color(0xFF120F0C),
  surf: Color(0xFF1E1A16),
  ink: Color(0xFFF0EEEA),
  mute: Color(0xFFA9A49E),
  line: Color(0xFF322D29),
  acc: Color(0xFF5CC6B9),
  onAcc: Color(0xFF011613),
  accSoft: Color(0xFF0C3531),
  accText: Color(0xFF93E3D8),
);

ThemeData appTheme(Brightness brightness) {
  final t = brightness == Brightness.light ? _light : _dark;
  // Colours the design doesn't set, such as error, come from the accent.
  final colorScheme = ColorScheme.fromSeed(seedColor: t.acc, brightness: brightness).copyWith(
    primary: t.acc,
    onPrimary: t.onAcc,
    primaryContainer: t.accSoft,
    onPrimaryContainer: t.accText,
    surface: t.bg,
    onSurface: t.ink,
    onSurfaceVariant: t.mute,
    surfaceContainerLowest: t.surf,
    surfaceContainerLow: t.surf,
    surfaceContainer: t.surf,
    surfaceContainerHigh: t.surf,
    surfaceContainerHighest: t.surf,
    outline: t.mute,
    outlineVariant: t.line,
  );
  return ThemeData(colorScheme: colorScheme, fontFamily: 'Figtree');
}

/// Adds the bundled fonts' licenses to the app's license page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/Figtree-OFL.txt');
    yield LicenseEntryWithLineBreaks(['Figtree'], license);
  });
}
