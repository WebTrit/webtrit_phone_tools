import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_resources/processors/font_asset_processor.dart';

/// Which typeface a build fetches, and when it fetches none.
///
/// It used to demand exactly one, collected by walking every nested object - so
/// a theme that names no family at all was refused, and so was one whose avatar
/// placeholder styled its initials with a second family. Both are ordinary
/// configurations the app renders perfectly well.
void main() {
  late FontAssetProcessor processor;

  setUp(() => processor = FontAssetProcessor(logger: Logger(level: Level.quiet)));

  Map<String, dynamic> config({String? declared, String? nested}) => {
        if (declared != null) 'fonts': {'fontFamily': declared},
        if (nested != null)
          'avatar': {
            'metadata': {
              'initialsTextStyle': {'fontFamily': nested, 'fontSize': 16},
            },
          },
      };

  test('a theme that names no font is left on the platform typeface', () async {
    // The case that stopped a build of a live brand: `fonts.fontFamily` null,
    // which is a decision rather than an omission. There is nothing to
    // download, and refusing here refuses a configuration that renders.
    var reached = false;
    await processor.process(
      lightConfig: {
        'fonts': {'fontFamily': null},
      },
      darkConfig: {
        'fonts': {'fontFamily': null},
      },
      resolvePath: (path) {
        reached = true;
        return '/tmp/does-not-matter/$path';
      },
    );

    expect(reached, isFalse, reason: 'nothing is fetched, and nothing is refused');
  });

  test('a configuration with no fonts block at all is the same answer', () async {
    var reached = false;
    await processor.process(
      lightConfig: const {},
      darkConfig: const {},
      resolvePath: (path) {
        reached = true;
        return '/tmp/does-not-matter/$path';
      },
    );

    expect(reached, isFalse);
  });

  test('a font named inside an avatar style is not a second choice', () async {
    // A nested style whose family differs from the theme's used to count as a
    // second choice, and a second choice was refused. Only one family is ever
    // bundled, so a style naming another renders in the platform default.
    var attempted = '';
    await processor
        .process(
          lightConfig: config(declared: 'Be Vietnam Pro', nested: 'Montserrat'),
          darkConfig: config(declared: 'Be Vietnam Pro'),
          resolvePath: (path) {
            attempted = path;
            return '/tmp/does-not-matter/$path';
          },
        )
        .catchError((_) {});

    expect(attempted, contains('Be'), reason: 'the declared family is what gets fetched');
    expect(attempted, isNot(contains('Montserrat')), reason: 'the nested one is not a choice at all');
  });
}
