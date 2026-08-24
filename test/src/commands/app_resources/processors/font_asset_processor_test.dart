import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_resources/processors/font_asset_processor.dart';

/// Which typeface a build fetches.
///
/// It used to be whatever the configuration mentioned anywhere, collected by
/// walking every nested object - so the style of the initials drawn on an avatar
/// placeholder counted as a second choice, and a second choice was refused. That
/// refusal blocked three brands in production. A theme declares its typeface in
/// one place, and that is the one place this reads.
void main() {
  late FontAssetProcessor processor;
  late Logger logger;

  setUp(() {
    logger = Logger(level: Level.quiet);
    processor = FontAssetProcessor(logger: logger);
  });

  Map<String, dynamic> config({String? declared, String? nested}) => {
        if (declared != null) 'fonts': {'fontFamily': declared},
        if (nested != null)
          'avatar': {
            'metadata': {
              'initialsTextStyle': {'fontFamily': nested, 'fontSize': 16},
            },
          },
      };

  test('a font named inside an avatar style is not a second choice', () async {
    // Ten applications in production carry exactly this: a nested style whose
    // family differs from the theme's. Only one family is ever bundled, so a
    // style naming another renders in the platform default - silently.
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

    expect(attempted, contains('Be_Vietnam_Pro'), reason: 'the declared family is what gets fetched');
    expect(attempted, isNot(contains('Montserrat')), reason: 'the nested one is not a choice at all');
  });

  test('a theme that declares nothing leaves the app alone', () async {
    var touched = false;

    await processor.process(
      lightConfig: config(nested: 'Montserrat'),
      darkConfig: config(),
      resolvePath: (path) {
        touched = true;
        return '/tmp/$path';
      },
    );

    expect(touched, isFalse, reason: 'nothing to fetch, so nothing to write');
  });
}
