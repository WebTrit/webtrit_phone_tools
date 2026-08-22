import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/constants.dart';

void main() {
  test('a run without an override talks to the configurator backend', () {
    expect(resolveConfiguratorApiUrl(const {}), configuratorProdApiUrl);
  });

  test('the address carries the API version segment', () {
    expect(configuratorProdApiUrl, endsWith('/v1'));
  });

  test('an override points the run at another deployment', () {
    expect(
      resolveConfiguratorApiUrl(
          const {configuratorApiUrlVariable: 'http://127.0.0.1:8080/v1'}),
      'http://127.0.0.1:8080/v1',
    );
  });

  test('an unrelated variable leaves the address alone', () {
    expect(
      resolveConfiguratorApiUrl(const {'SOME_OTHER_URL': 'http://elsewhere'}),
      configuratorProdApiUrl,
    );
  });
}
