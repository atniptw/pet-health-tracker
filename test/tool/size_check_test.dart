import 'package:flutter_test/flutter_test.dart';

import '../../tool/size_check.dart';

/// A method body of [lines] lines in total, signature and braces included.
String _method(String name, int lines) =>
    ['  void $name() {', for (var i = 0; i < lines - 2; i++) '    print($i);', '  }'].join('\n');

Map<String, int> _sizes(String path, String content) => {
  for (final m in measure(path, content)) m.key: m.lines,
};

void main() {
  group('measure', () {
    test('counts the lines of the file', () {
      expect(_sizes('lib/a.dart', 'void a() {}\n\nvoid b() {}\n')['lib/a.dart'], 3);
      expect(_sizes('lib/a.dart', 'void a() {}\n\nvoid b() {}')['lib/a.dart'], 3);
    });

    test('counts a method from its signature to its closing brace', () {
      final content = 'class A {\n  /// Docs.\n  @override\n${_method('run', 5)}\n}\n';
      expect(_sizes('lib/a.dart', content)['lib/a.dart A.run'], 5);
    });

    test('names top-level functions, getters, constructors and local functions', () {
      const content = '''
int top() => 1;
class A {
  A();
  A.named() {
    print(1);
  }
  int get value => 1;
}
void outer() {
  void inner() {}
}
''';
      expect(
        _sizes('lib/a.dart', content).keys,
        containsAll(<String>[
          'lib/a.dart top',
          'lib/a.dart A.new',
          'lib/a.dart A.named',
          'lib/a.dart A.value',
          'lib/a.dart outer',
          'lib/a.dart outer.inner',
        ]),
      );
      expect(_sizes('lib/a.dart', content)['lib/a.dart A.named'], 3);
    });

    test('names methods of mixins, extensions and enums', () {
      const content = '''
mixin M { void m() {} }
extension E on int { void e() {} }
enum N { a; void n() {} }
''';
      expect(
        _sizes('lib/a.dart', content).keys,
        containsAll(<String>['lib/a.dart M.m', 'lib/a.dart E.e', 'lib/a.dart N.n']),
      );
    });
  });

  group('check', () {
    const file = Measure('lib/a.dart', 10, fileLimit);
    const big = Measure('lib/a.dart A.run', 50, functionLimit);

    test('passes when everything is within its limit', () {
      expect(check([file, const Measure('lib/a.dart A.run', 40, functionLimit)], {}), isEmpty);
    });

    test('fails a file or function over its limit that the baseline lacks', () {
      final errors = check([const Measure('lib/a.dart', 301, fileLimit), big], {});
      expect(errors, hasLength(2));
      expect(errors[0], contains('lib/a.dart has 301 lines (limit 300)'));
      expect(errors[1], contains('lib/a.dart A.run has 50 lines (limit 40)'));
    });

    test('passes a baseline entry at its recorded size', () {
      expect(check([file, big], {'lib/a.dart A.run': 50}), isEmpty);
    });

    test('fails a baseline entry that grew', () {
      expect(
        check([file, big], {'lib/a.dart A.run': 45}).single,
        contains('lib/a.dart A.run grew to 50 lines (baseline 45)'),
      );
    });

    test('fails a baseline entry that shrank until the baseline is lowered', () {
      expect(
        check([file, big], {'lib/a.dart A.run': 60}).single,
        contains('lower its baseline entry to 50'),
      );
    });

    test('fails a baseline entry that is back within its limit until it is removed', () {
      expect(
        check(
          [file, const Measure('lib/a.dart A.run', 30, functionLimit)],
          {'lib/a.dart A.run': 60},
        ).single,
        contains('remove its baseline entry'),
      );
    });

    test('fails a baseline entry for something that no longer exists', () {
      expect(
        check([file], {'lib/gone.dart': 400}).single,
        contains('lib/gone.dart no longer exists'),
      );
    });
  });

  test('sourceFiles keeps the Dart files in lib/ except the generated one, sorted', () {
    expect(
      sourceFiles([
        'lib/b.dart',
        'lib/firebase_options.dart',
        'lib/notes.txt',
        'test/a_test.dart',
        'lib/sub/a.dart',
        'lib/a.dart',
      ]),
      ['lib/a.dart', 'lib/b.dart', 'lib/sub/a.dart'],
    );
  });

  group('baseline', () {
    test('round-trips the entries over their limits, sorted', () {
      final text = formatBaseline([
        const Measure('lib/b.dart', 400, fileLimit),
        const Measure('lib/a.dart A.run', 50, functionLimit),
        const Measure('lib/a.dart', 10, fileLimit),
      ]);
      expect(text, '50 lib/a.dart A.run\n400 lib/b.dart\n');
      expect(parseBaseline(text), {'lib/a.dart A.run': 50, 'lib/b.dart': 400});
    });

    test('ignores blank lines and comments', () {
      expect(parseBaseline('# note\n\n12 lib/a.dart\n'), {'lib/a.dart': 12});
    });
  });
}
