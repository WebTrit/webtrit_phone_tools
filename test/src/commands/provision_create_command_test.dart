import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/provision_create/provision_create.dart';

import 'signing_fixtures.dart';

const _certificateBytes = [0x30, 0x82, 0x01, 0x02];
const _certificateId = 'CERT01';
const _bundleIdResourceId = 'BUNDLE01';

void main() {
  late Logger logger;
  late Directory directory;

  setUp(() {
    logger = Logger();
    directory = Directory.systemTemp.createTempSync('provision_create');
    writeSigningFixtures(directory.path);
    File(path.join(directory.path, 'ios_distribution.cer')).writeAsBytesSync(_certificateBytes);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  CommandRunner<int> runnerWith(http.Client client) => CommandRunner<int>('test', 'Test for ProvisionCreateCommand')
    ..addCommand(ProvisionCreateCommand(logger: logger, httpClient: client));

  Map<String, dynamic> profilePayload({
    required String id,
    required String name,
    String state = 'ACTIVE',
    String bundleIdResourceId = _bundleIdResourceId,
    List<String> certificateIds = const [_certificateId],
  }) =>
      {
        'id': id,
        'attributes': {
          'name': name,
          'profileState': state,
          'profileContent': base64.encode(provisioningProfileBytes()),
        },
        'relationships': {
          'bundleId': {
            'data': {'id': bundleIdResourceId, 'type': 'bundleIds'},
          },
          'certificates': {
            'data': [
              for (final certificateId in certificateIds) {'id': certificateId, 'type': 'certificates'},
            ],
          },
        },
      };

  /// Answers the three reads every run makes, and hands anything else to [onWrite].
  MockClient apiWith({
    required List<Map<String, dynamic>> profiles,
    required Future<http.Response> Function(http.Request request) onWrite,
  }) =>
      MockClient((request) async {
        final endpoint = request.url.path;
        if (request.method == 'GET' && endpoint.endsWith('/certificates')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': _certificateId,
                  'attributes': {
                    'certificateType': 'DISTRIBUTION',
                    'certificateContent': base64.encode(_certificateBytes),
                  },
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET' && endpoint.endsWith('/bundleIds')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': _bundleIdResourceId,
                  'attributes': {'identifier': testBundleId},
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'GET' && endpoint.endsWith('/profiles')) {
          return http.Response(jsonEncode({'data': profiles}), 200);
        }
        return onWrite(request);
      });

  test('writes the profile and the team id it carries', () async {
    final client = apiWith(
      profiles: const [],
      onWrite: (request) async {
        expect(request.method, equals('POST'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>;
        expect((data['attributes'] as Map<String, dynamic>)['name'], equals('Provision'));
        expect((data['attributes'] as Map<String, dynamic>)['profileType'], equals('IOS_APP_STORE'));

        final relationships = data['relationships'] as Map<String, dynamic>;
        final bundleId = (relationships['bundleId'] as Map<String, dynamic>)['data'] as Map<String, dynamic>;
        expect(bundleId['id'], equals(_bundleIdResourceId));

        return http.Response(jsonEncode({'data': profilePayload(id: 'NEW01', name: 'Provision')}), 201);
      },
    );

    final result = await runnerWith(client).run(['provision-create', directory.path]);

    expect(result, equals(ExitCode.success.code));

    final profile = File(path.join(directory.path, 'Provision.mobileprovision'));
    expect(profile.readAsBytesSync(), equals(provisioningProfileBytes()));

    final metadata =
        jsonDecode(File(path.join(directory.path, 'upload-store-connect-metadata.json')).readAsStringSync())
            as Map<String, dynamic>;
    expect(metadata['team-id'], equals(testTeamId));
  });

  test('reuses a profile that already covers the bundle id and the certificate', () async {
    final client = apiWith(
      profiles: [profilePayload(id: 'OLD01', name: 'Provision')],
      onWrite: (request) async => fail('Nothing should be created: ${request.method} ${request.url}'),
    );

    final result = await runnerWith(client).run(['provision-create', directory.path]);

    expect(result, equals(ExitCode.success.code));
    expect(File(path.join(directory.path, 'Provision.mobileprovision')).existsSync(), isTrue);
  });

  test('does not mistake a longer name for the one asked for', () async {
    // `filter[name]` matches by prefix, so asking for "Provision" also returns
    // "Provision 1787669827" - a profile that happens to share the beginning.
    var created = false;
    final client = apiWith(
      profiles: [profilePayload(id: 'OTHER01', name: 'Provision 1787669827')],
      onWrite: (request) async {
        created = true;
        return http.Response(jsonEncode({'data': profilePayload(id: 'NEW01', name: 'Provision')}), 201);
      },
    );

    final result = await runnerWith(client).run(['provision-create', directory.path]);

    expect(result, equals(ExitCode.success.code));
    expect(created, isTrue);
  });

  test('leaves a name alone when it covers something else', () async {
    final client = apiWith(
      profiles: [profilePayload(id: 'OLD01', name: 'Provision', certificateIds: const ['ANOTHER'])],
      onWrite: (request) async => fail('Nothing should be touched: ${request.method} ${request.url}'),
    );

    final result = await runnerWith(client).run(['provision-create', directory.path]);

    expect(result, equals(ExitCode.usage.code));
    expect(File(path.join(directory.path, 'Provision.mobileprovision')).existsSync(), isFalse);
  });

  test('replaces that name only when asked to', () async {
    final requests = <String>[];
    final client = apiWith(
      profiles: [profilePayload(id: 'OLD01', name: 'Provision', certificateIds: const ['ANOTHER'])],
      onWrite: (request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return http.Response(jsonEncode({'data': profilePayload(id: 'NEW01', name: 'Provision')}), 201);
      },
    );

    final result = await runnerWith(client).run(['provision-create', '--replaceExisting', directory.path]);

    expect(result, equals(ExitCode.success.code));
    expect(requests, equals(['DELETE /v1/profiles/OLD01', 'POST /v1/profiles']));
  });

  test('stops when the certificate is not one the account knows', () async {
    File(path.join(directory.path, 'ios_distribution.cer')).writeAsBytesSync([0x31, 0x31]);

    final client = apiWith(
      profiles: const [],
      onWrite: (request) async => fail('Nothing should be created: ${request.method} ${request.url}'),
    );

    final result = await runnerWith(client).run(['provision-create', directory.path]);

    expect(result, equals(ExitCode.software.code));
  });
}
