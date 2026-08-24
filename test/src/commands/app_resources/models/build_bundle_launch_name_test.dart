import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/app_resources/models/build_bundle.dart';

/// What goes under the icon.
///
/// It used to be the brand's `name`, which is also the label an operator files
/// the brand under in the configurator - one field, so renaming the one renamed
/// the other on every phone that updated. The two are separate now, and a brand
/// that has not been given a caption still gets the name, because that is what
/// every build so far has shipped with.
void main() {
  BundleApplication brand({String? name, String? android, String? ios}) =>
      BundleApplication(name: name, androidLaunchName: android, iosLaunchName: ios);

  test('takes the caption a brand gives each store', () {
    final application = brand(name: 'Filed under this', android: 'Acme Phone', ios: 'Acme');

    expect(application.launchNameFor(BuildPlatform.android), 'Acme Phone');
    expect(application.launchNameFor(BuildPlatform.ios), 'Acme');
  });

  test('falls back to the name a brand has always been built with', () {
    final application = brand(name: 'Acme');

    expect(application.launchNameFor(BuildPlatform.android), 'Acme');
    expect(application.launchNameFor(BuildPlatform.ios), 'Acme');
  });

  test('treats a caption of blanks as none at all', () {
    // An operator who clears the field means "use the name", not "ship an app
    // with no label".
    final application = brand(name: 'Acme', android: '   ');

    expect(application.launchNameFor(BuildPlatform.android), 'Acme');
  });

  test('trims what it is given rather than shipping the spaces', () {
    final application = brand(name: 'Acme', android: '  Acme Phone  ');

    expect(application.launchNameFor(BuildPlatform.android), 'Acme Phone');
  });

  test('reads both captions off the wire', () {
    final application = BundleApplication.fromJson({
      'name': 'Filed under this',
      'androidLaunchName': 'Acme Phone',
      'iosLaunchName': 'Acme',
    });

    expect(application.launchNameFor(BuildPlatform.android), 'Acme Phone');
    expect(application.launchNameFor(BuildPlatform.ios), 'Acme');
  });

  test('reads a payload that has never heard of a caption', () {
    // The backend that serves older builds returns neither field.
    final application = BundleApplication.fromJson({'name': 'Acme'});

    expect(application.launchNameFor(BuildPlatform.android), 'Acme');
  });
}
