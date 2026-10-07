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

/// A pet avatar's circle and initial.
typedef AvatarColors = ({Color fill, Color initial});

/// The design's colours that have no place in [ColorScheme].
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.avatars, required this.symptomDots, required this.otherDot});

  /// The theme's, or the design's for its brightness when the theme has none.
  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.light ? _lightColors : _darkColors);
  }

  /// Teal, terracotta, violet and amber, given to pets by their order in the
  /// list and cycling.
  final List<AvatarColors> avatars;

  AvatarColors avatar(int index) => avatars[index % avatars.length];

  /// Catalog symptoms' dots, keyed by symptom key.
  final Map<String, Color> symptomDots;

  /// The dot for `other` logs, and for catalog symptoms without their own.
  final Color otherDot;

  Color symptomDot(String key) => symptomDots[key] ?? otherDot;

  @override
  AppColors copyWith({
    List<AvatarColors>? avatars,
    Map<String, Color>? symptomDots,
    Color? otherDot,
  }) => AppColors(
    avatars: avatars ?? this.avatars,
    symptomDots: symptomDots ?? this.symptomDots,
    otherDot: otherDot ?? this.otherDot,
  );

  @override
  AppColors lerp(AppColors? other, double t) => other != null && t >= .5 ? other : this;
}

const _lightColors = AppColors(
  avatars: [
    (fill: Color(0xFFCFF0EB), initial: Color(0xFF00554D)),
    (fill: Color(0xFFFEE5DC), initial: Color(0xFF833F27)),
    (fill: Color(0xFFEBE3FC), initial: Color(0xFF544272)),
    (fill: Color(0xFFF8EACE), initial: Color(0xFF6B4716)),
  ],
  symptomDots: {
    'seizure': Color(0xFF9274C3),
    'vomit': Color(0xFFCC9C42),
    'diarrhea': Color(0xFFC26B4C),
  },
  otherDot: Color(0xFF948274),
);

// Dark, muted fills with light initials, as accSoft and accText are in dark.
// Dots are lightened to show on the dark background.
const _darkColors = AppColors(
  avatars: [
    (fill: Color(0xFF0C3531), initial: Color(0xFF93E3D8)),
    (fill: Color(0xFF3B2219), initial: Color(0xFFF4B9A2)),
    (fill: Color(0xFF2A2340), initial: Color(0xFFCDBDF0)),
    (fill: Color(0xFF352A12), initial: Color(0xFFEBC98A)),
  ],
  symptomDots: {
    'seizure': Color(0xFFB49CE0),
    'vomit': Color(0xFFE0B762),
    'diarrhea': Color(0xFFE08D70),
  },
  otherDot: Color(0xFFB5A598),
);

/// For times, which the design sets in a monospaced font.
const monoFontFamily = 'IBM Plex Mono';

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
  return ThemeData(
    colorScheme: colorScheme,
    fontFamily: 'Figtree',
    extensions: [if (brightness == Brightness.light) _lightColors else _darkColors],
  );
}

/// Adds the bundled fonts' licenses to the app's license page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (font, file) in [
      ('Figtree', 'Figtree-OFL.txt'),
      (monoFontFamily, 'IBMPlexMono-OFL.txt'),
    ]) {
      final license = await rootBundle.loadString('assets/fonts/$file');
      yield LicenseEntryWithLineBreaks([font], license);
    }
  });
}
