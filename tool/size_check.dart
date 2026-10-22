// Fails when a file in lib/ is over 300 lines or a function, method or
// constructor is over 40, unless tool/size_baseline.txt lists it at exactly
// its size. An entry also fails when its size changes, when it is back within
// its limit, or when it no longer exists, until the baseline is edited to
// match. Edits may only lower or remove entries; clean-code reviews them.
//
//   dart tool/size_check.dart                   check
//   dart tool/size_check.dart --print-baseline  print what is over a limit
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

const fileLimit = 300;
const functionLimit = 40;
const baselinePath = 'tool/size_baseline.txt';
const _generated = {'lib/firebase_options.dart'};

/// The size of a file (key `path`) or a function in it (key `path Name`).
class Measure {
  const Measure(this.key, this.lines, this.limit);

  final String key;
  final int lines;
  final int limit;

  bool get overLimit => lines > limit;
}

List<Measure> measure(String path, String content) {
  final result = parseString(content: content, path: path, throwIfDiagnostics: false);
  final lines = content.endsWith('\n') ? result.lineInfo.lineCount - 1 : result.lineInfo.lineCount;
  final visitor = _FunctionSizes(path, result.lineInfo);
  result.unit.accept(visitor);
  return [Measure(path, lines, fileLimit), ...visitor.sizes];
}

class _FunctionSizes extends RecursiveAstVisitor<void> {
  _FunctionSizes(this.path, this.lineInfo);

  final String path;
  final LineInfo lineInfo;
  final sizes = <Measure>[];
  final _names = <String>[];

  void _within(String name, void Function() visitChildren) {
    _names.add(name);
    visitChildren();
    _names.removeLast();
  }

  void _record(String name, AnnotatedNode node, void Function() visitChildren) {
    final first = lineInfo.getLocation(node.firstTokenAfterCommentAndMetadata.offset).lineNumber;
    final last = lineInfo.getLocation(node.end).lineNumber;
    _within(name, () {
      sizes.add(Measure('$path ${_names.join('.')}', last - first + 1, functionLimit));
      visitChildren();
    });
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) =>
      _within(node.namePart.typeName.lexeme, () => super.visitClassDeclaration(node));

  @override
  void visitMixinDeclaration(MixinDeclaration node) =>
      _within(node.name.lexeme, () => super.visitMixinDeclaration(node));

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) =>
      _within(node.name?.lexeme ?? 'extension', () => super.visitExtensionDeclaration(node));

  @override
  void visitEnumDeclaration(EnumDeclaration node) =>
      _within(node.namePart.typeName.lexeme, () => super.visitEnumDeclaration(node));

  @override
  void visitMethodDeclaration(MethodDeclaration node) =>
      _record(node.name.lexeme, node, () => super.visitMethodDeclaration(node));

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) =>
      _record(node.name.lexeme, node, () => super.visitFunctionDeclaration(node));

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final Token? name = node.name;
    _record(name?.lexeme ?? 'new', node, () => super.visitConstructorDeclaration(node));
  }
}

/// Errors for every measure that doesn't match the baseline (over its limit and
/// unlisted, listed at a different size, or listed but within its limit), and
/// for every baseline entry that no longer exists.
List<String> check(List<Measure> measures, Map<String, int> baseline) {
  final errors = <String>[];
  final measured = <String>{};
  for (final m in measures) {
    measured.add(m.key);
    final recorded = baseline[m.key];
    if (recorded == null) {
      if (m.overLimit) errors.add('${m.key} has ${m.lines} lines (limit ${m.limit}).');
    } else if (m.lines > recorded) {
      errors.add('${m.key} grew to ${m.lines} lines (baseline $recorded).');
    } else if (!m.overLimit) {
      errors.add('${m.key} is within its limit: remove its baseline entry.');
    } else if (m.lines < recorded) {
      errors.add('${m.key} shrank to ${m.lines} lines: lower its baseline entry to ${m.lines}.');
    }
  }
  for (final key in baseline.keys) {
    if (!measured.contains(key)) errors.add('$key no longer exists: remove its baseline entry.');
  }
  return errors;
}

/// Baseline lines are `<lines> <key>`; blank lines and `#` comments are skipped.
Map<String, int> parseBaseline(String text) {
  final entries = <String, int>{};
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final space = trimmed.indexOf(' ');
    entries[trimmed.substring(space + 1)] = int.parse(trimmed.substring(0, space));
  }
  return entries;
}

String formatBaseline(List<Measure> measures) {
  final over = measures.where((m) => m.overLimit).toList()..sort((a, b) => a.key.compareTo(b.key));
  return over.map((m) => '${m.lines} ${m.key}\n').join();
}

/// The files to measure, sorted: Dart files in lib/ except generated ones.
List<String> sourceFiles(Iterable<String> paths) =>
    paths
        .where((p) => p.startsWith('lib/') && p.endsWith('.dart') && !_generated.contains(p))
        .toList()
      ..sort();

void main(List<String> args) {
  final files = sourceFiles(
    Directory('lib').listSync(recursive: true).whereType<File>().map((f) => f.path),
  );
  final measures = [for (final p in files) ...measure(p, File(p).readAsStringSync())];

  if (args.contains('--print-baseline')) {
    stdout.write(formatBaseline(measures));
    return;
  }

  final baseline = File(baselinePath);
  final errors = check(
    measures,
    baseline.existsSync() ? parseBaseline(baseline.readAsStringSync()) : {},
  );
  if (errors.isEmpty) {
    stdout.writeln('size limits ok');
    return;
  }
  errors.forEach(stderr.writeln);
  exitCode = 1;
}
