import 'dart:io';

void main() {
  final root = Directory('lib');
  if (!root.existsSync()) {
    stderr.writeln('lib directory not found.');
    exitCode = 1;
    return;
  }

  final violations = <String>[];

  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }

    final path = entity.path.replaceAll('\\', '/');
    final lines = entity.readAsLinesSync();
    final imports = lines
        .where((line) => line.trimLeft().startsWith('import '))
        .map((line) => line.trim())
        .toList(growable: false);

    if (path.contains('/features/') && path.contains('/domain/')) {
      _assertNoMatch(
        violations,
        path,
        imports,
        <String>[
          "import 'package:flutter",
          "import 'package:flutter_riverpod",
          "import 'package:http",
          "import 'package:web",
          '/presentation/',
          '/infrastructure/',
        ],
        'Domain layer imports forbidden dependency',
      );
    }

    if (path.contains('/features/') && path.contains('/application/')) {
      _assertNoMatch(
        violations,
        path,
        imports,
        <String>[
          "import 'package:flutter/material.dart'",
          "import 'package:flutter/widgets.dart'",
        ],
        'Application layer imports Flutter UI dependency',
      );
    }

    if ((path.contains('/features/') || path.contains('/shared/')) &&
        path.contains('/infrastructure/')) {
      _assertNoMatch(
        violations,
        path,
        imports,
        <String>['/presentation/'],
        'Infrastructure layer imports presentation dependency',
      );
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('Architecture dependency check passed.');
    return;
  }

  stderr.writeln('Architecture dependency violations:');
  for (final violation in violations) {
    stderr.writeln('- $violation');
  }

  exitCode = 1;
}

void _assertNoMatch(
  List<String> violations,
  String path,
  List<String> imports,
  List<String> forbidden,
  String message,
) {
  for (final importLine in imports) {
    for (final pattern in forbidden) {
      if (importLine.contains(pattern)) {
        violations.add('$path :: $message :: $importLine');
      }
    }
  }
}
