import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'package:webtrit_phone_tools/src/commands/cert_create/cert_create.dart';

import 'signing_fixtures.dart';

void main() {
  late Logger logger;
  late Directory directory;

  setUp(() {
    logger = Logger();
    directory = Directory.systemTemp.createTempSync('cert_create');
    writeSigningFixtures(directory.path);
    File(path.join(directory.path, 'CertificateSigningRequest.certSigningRequest'))
        .writeAsStringSync('-----BEGIN CERTIFICATE REQUEST-----\nMIIB\n-----END CERTIFICATE REQUEST-----\n');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  CommandRunner<int> runnerWith(http.Client client) => CommandRunner<int>('test', 'Test for CertCreateCommand')
    ..addCommand(CertCreateCommand(logger: logger, httpClient: client));

  http.Response certificateResponse(List<int> certificate) => http.Response(
        jsonEncode({
          'data': {
            'id': 'ABC123',
            'attributes': {'certificateType': 'DISTRIBUTION', 'certificateContent': base64.encode(certificate)},
          },
        }),
        201,
      );

  test('writes the certificate App Store Connect issues', () async {
    final certificate = [0x30, 0x82, 0x01, 0x02];
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/certificates'));
      expect(request.method, equals('POST'));

      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final attributes = (body['data'] as Map<String, dynamic>)['attributes'] as Map<String, dynamic>;
      expect(attributes['certificateType'], equals('DISTRIBUTION'));
      expect(attributes['csrContent'], contains('BEGIN CERTIFICATE REQUEST'));

      return certificateResponse(certificate);
    });

    final result = await runnerWith(client).run(['cert-create', directory.path]);

    expect(result, equals(ExitCode.success.code));
    expect(File(path.join(directory.path, 'ios_distribution.cer')).readAsBytesSync(), equals(certificate));
  });

  test('signs the request with the key the metadata names', () async {
    var authorization = '';
    final client = MockClient((request) async {
      authorization = request.headers['Authorization'] ?? '';
      return certificateResponse([0x30]);
    });

    await runnerWith(client).run(['cert-create', directory.path]);

    final token = authorization.replaceFirst('Bearer ', '').split('.');
    expect(token, hasLength(3));

    final header = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token[0])))) as Map<String, dynamic>;
    expect(header['alg'], equals('ES256'));
    expect(header['kid'], equals(testKeyId));

    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token[1])))) as Map<String, dynamic>;
    expect(payload['iss'], equals(testIssuerId));
    expect(payload['aud'], equals('appstoreconnect-v1'));

    expect(base64Url.decode(base64Url.normalize(token[2])), hasLength(64));
  });

  test('stops before reaching Apple when the metadata names no key', () async {
    File(path.join(directory.path, 'upload-store-connect-metadata.json')).writeAsStringSync('{}');

    var reached = false;
    final client = MockClient((_) async {
      reached = true;
      return http.Response('', 500);
    });

    final result = await runnerWith(client).run(['cert-create', directory.path]);

    expect(result, equals(ExitCode.usage.code));
    expect(reached, isFalse);
  });

  test('reports what Apple refused', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'errors': [
              {
                'title': 'FORBIDDEN_ERROR',
                'detail': 'Only Team Admins can create Distribution certificates',
              },
            ],
          }),
          403,
        ));

    final result = await runnerWith(client).run(['cert-create', directory.path]);

    expect(result, equals(ExitCode.software.code));
    expect(File(path.join(directory.path, 'ios_distribution.cer')).existsSync(), isFalse);
  });
}
