import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/core/theme.dart';

void main() {
  // Loading the license file needs the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the light theme uses the light design tokens', () {
    final theme = appTheme(Brightness.light);
    final colors = theme.colorScheme;

    expect(colors.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF9F6F2));
    expect(colors.surface, const Color(0xFFF9F6F2));
    expect(colors.surfaceContainerLow, const Color(0xFFFEFDFB));
    expect(colors.onSurface, const Color(0xFF241E1A));
    expect(colors.onSurfaceVariant, const Color(0xFF69625D));
    expect(colors.outline, const Color(0xFF69625D));
    expect(colors.outlineVariant, const Color(0xFFE1DDD8));
    expect(colors.primary, const Color(0xFF007B70));
    expect(colors.onPrimary, const Color(0xFFFFFFFF));
    expect(colors.primaryContainer, const Color(0xFFCFF0EB));
    expect(colors.onPrimaryContainer, const Color(0xFF00554D));
  });

  test('the dark theme uses the dark design tokens', () {
    final theme = appTheme(Brightness.dark);
    final colors = theme.colorScheme;

    expect(colors.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF120F0C));
    expect(colors.surface, const Color(0xFF120F0C));
    expect(colors.surfaceContainerLow, const Color(0xFF1E1A16));
    expect(colors.onSurface, const Color(0xFFF0EEEA));
    expect(colors.onSurfaceVariant, const Color(0xFFA9A49E));
    expect(colors.outline, const Color(0xFFA9A49E));
    expect(colors.outlineVariant, const Color(0xFF322D29));
    expect(colors.primary, const Color(0xFF5CC6B9));
    expect(colors.onPrimary, const Color(0xFF011613));
    expect(colors.primaryContainer, const Color(0xFF0C3531));
    expect(colors.onPrimaryContainer, const Color(0xFF93E3D8));
  });

  test('every surface container is the surf token', () {
    for (final brightness in Brightness.values) {
      final colors = appTheme(brightness).colorScheme;
      expect({
        colors.surfaceContainerLowest,
        colors.surfaceContainerLow,
        colors.surfaceContainer,
        colors.surfaceContainerHigh,
        colors.surfaceContainerHighest,
      }, hasLength(1));
    }
  });

  test('pet avatars cycle through 4 colour pairs in each theme', () {
    final light = appTheme(Brightness.light).extension<AppColors>()!;
    final dark = appTheme(Brightness.dark).extension<AppColors>()!;

    expect(light.avatar(0), (fill: const Color(0xFFCFF0EB), initial: const Color(0xFF00554D)));
    expect(light.avatar(4), light.avatar(0));
    expect(dark.avatar(0), (fill: const Color(0xFF0C3531), initial: const Color(0xFF93E3D8)));
    expect(dark.avatars, hasLength(4));
    for (final pair in dark.avatars) {
      expect(pair.fill.computeLuminance(), lessThan(pair.initial.computeLuminance()));
    }
  });

  test('each catalog symptom has its dot, and others the other dot', () {
    final light = appTheme(Brightness.light).extension<AppColors>()!;
    final dark = appTheme(Brightness.dark).extension<AppColors>()!;

    expect(light.symptomDot('seizure'), const Color(0xFF9274C3));
    expect(light.symptomDot('vomit'), const Color(0xFFCC9C42));
    expect(light.symptomDot('diarrhea'), const Color(0xFFC26B4C));
    expect(light.symptomDot('limping'), const Color(0xFF948274));
    for (final key in ['seizure', 'vomit', 'diarrhea', 'other']) {
      expect(
        dark.symptomDot(key).computeLuminance(),
        greaterThan(light.symptomDot(key).computeLuminance()),
      );
    }
  });

  test('avatar colours switch halfway through a theme change', () {
    final light = appTheme(Brightness.light).extension<AppColors>()!;
    final dark = appTheme(Brightness.dark).extension<AppColors>()!;

    expect(light.lerp(dark, .4), light);
    expect(light.lerp(dark, .6), dark);
    expect(light.lerp(null, 1), light);
    final copy = light.copyWith();
    expect(
      (copy.avatars, copy.symptomDots, copy.otherDot),
      (light.avatars, light.symptomDots, light.otherDot),
    );
    final changed = light.copyWith(
      avatars: dark.avatars,
      symptomDots: dark.symptomDots,
      otherDot: dark.otherDot,
    );
    expect(
      (changed.avatars, changed.symptomDots, changed.otherDot),
      (dark.avatars, dark.symptomDots, dark.otherDot),
    );
  });

  testWidgets('a theme without avatar colours falls back to the design\'s', (tester) async {
    late AppColors colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(
          builder: (context) {
            colors = AppColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(colors.avatars, appTheme(Brightness.dark).extension<AppColors>()!.avatars);
  });

  test('text uses Figtree', () {
    final theme = appTheme(Brightness.light);

    expect(theme.textTheme.bodyMedium!.fontFamily, 'Figtree');
    expect(theme.textTheme.titleLarge!.fontFamily, 'Figtree');
  });

  test('the bundled fonts\' licenses are registered', () async {
    registerFontLicenses();

    final licenses = await LicenseRegistry.licenses.toList();
    for (final font in ['Figtree', monoFontFamily]) {
      final license = licenses.where((license) => license.packages.contains(font));
      expect(license, isNotEmpty, reason: font);
      expect(
        license.first.paragraphs.map((paragraph) => paragraph.text).join('\n'),
        contains('SIL Open Font License'),
        reason: font,
      );
    }
  });
}
