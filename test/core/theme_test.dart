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

  test('text uses Figtree', () {
    final theme = appTheme(Brightness.light);

    expect(theme.textTheme.bodyMedium!.fontFamily, 'Figtree');
    expect(theme.textTheme.titleLarge!.fontFamily, 'Figtree');
  });

  test('the Figtree license is registered', () async {
    registerFontLicenses();

    final licenses = await LicenseRegistry.licenses.toList();
    final figtree = licenses.where((license) => license.packages.contains('Figtree'));
    expect(figtree, isNotEmpty);
    expect(
      figtree.first.paragraphs.map((paragraph) => paragraph.text).join('\n'),
      contains('SIL Open Font License'),
    );
  });
}
