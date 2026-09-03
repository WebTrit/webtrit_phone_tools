// Holds `docs/` together: every link resolves, and every page is reachable.
//
// The same gate the configurator and its backend run. It exists for the failure
// a review does not catch: a page moved or renamed leaves links behind it that
// still look like links, and a page nobody links to is a page nobody reads -
// both are invisible until somebody follows one.
//
//   dart run tool/docs_gate.dart
//
// Reachable means **from a README**, not from any page at all: two pages that
// link to each other and to nothing else are as lost as one nobody links to.
//
// A path in backticks is checked too, because a document that names a file
// which is not there is wrong in the way that costs the most: it sends somebody
// looking. A sibling repository is written as the path from here and is left
// alone: this checkout cannot answer for what is in another one.
import 'dart:io';

final _link = RegExp(r'\[[^\]]*\]\(([^)]+)\)');
final _codePath = RegExp(r'`((?:lib|bin|test|tool|docs)/[A-Za-z0-9_\-./]*)`');

void main() {
  final root = Directory.current;
  final pages = <String>[
    'README.md',
    'AGENTS.md',
    'CLAUDE.md',
    ...Directory(
      'docs',
    ).listSync(recursive: true).whereType<File>().map((file) => file.path).where((path) => path.endsWith('.md')),
  ]..sort();

  final failures = <String>[];
  final linkedTo = <String>{};

  for (final page in pages) {
    final text = File(page).readAsStringSync();
    final directory = File(page).parent.path;

    for (final match in _link.allMatches(text)) {
      final raw = match.group(1)!.split('#').first;
      if (raw.isEmpty || raw.startsWith('http') || raw.startsWith('mailto:')) continue;
      final target = File('$directory/$raw').absolute.uri.normalizePath().toFilePath();
      // A link that leaves this checkout names another repository beside it,
      // which this gate has no business having an opinion about.
      if (!target.startsWith(root.path)) continue;
      final exists = File(target).existsSync() || Directory(target).existsSync();
      if (!exists) {
        failures.add('$page: $raw does not exist');
        continue;
      }
      final relative = target.replaceFirst('${root.path}/', '');
      final indexes = page.endsWith('README.md');
      if (indexes) {
        linkedTo.add(relative.endsWith('/') ? '${relative}README.md' : relative);
        if (Directory(target).existsSync()) linkedTo.add('$relative/README.md');
      }
    }

    for (final match in _codePath.allMatches(text)) {
      final cited = match.group(1)!.replaceAll(RegExp(r'[.,;:)]+$'), '');
      if (File(cited).existsSync() || Directory(cited).existsSync()) continue;
      failures.add('$page: `$cited` does not exist');
    }
  }

  for (final page in pages) {
    if (page == 'README.md' || page == 'AGENTS.md' || page == 'CLAUDE.md') continue;
    if (page == 'docs/README.md') continue;
    if (!linkedTo.contains(page)) failures.add('$page: no README leads here');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('[docs-gate] ${failures.length} problem(s):');
    for (final failure in failures) {
      stderr.writeln('  $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('[docs-gate] ${pages.length} pages, every link resolves, every page is reachable.');
}
