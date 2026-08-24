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

  test('names a face the way the app looks for it', () async {
    // Not a naming preference: the app finds a bundled face by asking whether an
    // asset name ends with what the google_fonts package builds from the weight.
    // A file named anything else is not found, and the text renders in the
    // platform font without a word about it.
    const expected = {
      100: 'Thin',
      200: 'ExtraLight',
      300: 'Light',
      400: 'Regular',
      500: 'Medium',
      600: 'SemiBold',
      700: 'Bold',
      800: 'ExtraBold',
      900: 'Black',
    };

    for (final entry in expected.entries) {
      expect(
        FontAssetProcessor.weightNames[entry.key],
        entry.value,
        reason: 'weight ${entry.key} must be spelled the way google_fonts spells it',
      );
    }
  });

  test('covers every weight a theme can name, not only the four it used to', () async {
    // A brand in production asks for 800, and the step threw on it - so the
    // brand chose a typeface and shipped with the platform one.
    expect(FontAssetProcessor.weightNames.keys, containsAll(<int>[100, 200, 300, 800, 900]));
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
