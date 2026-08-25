import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';

import 'app_store_connect_constants.dart';
import 'app_store_connect_models.dart';

/// Reads and creates the signing resources App Store Connect owns: the
/// distribution certificate, the identifier it is issued against, and the
/// provisioning profile that ties the two together.
class AppStoreConnectClient {
  AppStoreConnectClient({
    required this.token,
    required this.logger,
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? appStoreConnectApiUrl;

  final String token;
  final Logger logger;

  final http.Client _httpClient;
  final String _baseUrl;

  Future<AppStoreCertificate> createCertificate({
    required String csrContent,
    required String certificateType,
  }) async {
    final response = await _post('/certificates', {
      'data': {
        'type': 'certificates',
        'attributes': {'certificateType': certificateType, 'csrContent': csrContent},
      },
    });
    return _certificate(response['data'] as Map<String, dynamic>);
  }

  Future<List<AppStoreCertificate>> certificates() async {
    final response = await _get('/certificates', {'limit': '200'});
    return (response['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_certificate)
        .toList(growable: false);
  }

  /// The resource id of the registered identifier [bundleId], or `null` when
  /// the identifier does not exist on the account.
  Future<String?> bundleIdResourceId(String bundleId) async {
    final response = await _get('/bundleIds', {'filter[identifier]': bundleId, 'limit': '200'});
    for (final entry in (response['data'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final attributes = entry['attributes'] as Map<String, dynamic>;
      if (attributes['identifier'] == bundleId) {
        return entry['id'] as String;
      }
    }
    return null;
  }

  Future<List<AppStoreProfile>> profiles({required String name}) async {
    final response = await _get('/profiles', {
      'filter[name]': name,
      'include': 'certificates,bundleId',
      'limit': '200',
    });
    return (response['data'] as List<dynamic>).cast<Map<String, dynamic>>().map(_profile).toList(growable: false);
  }

  Future<AppStoreProfile> createProfile({
    required String name,
    required String bundleIdResourceId,
    required List<String> certificateIds,
    required String profileType,
  }) async {
    final response = await _post('/profiles', {
      'data': {
        'type': 'profiles',
        'attributes': {'name': name, 'profileType': profileType},
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
      },
    });
    return _profile(response['data'] as Map<String, dynamic>);
  }

  Future<void> deleteProfile(String profileId) async {
    final uri = Uri.parse('$_baseUrl/profiles/$profileId');
    logger.detail('DELETE $uri');
    final response = await _httpClient.delete(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppStoreConnectException(response.statusCode, _errorMessage(response));
    }
  }

  void close() => _httpClient.close();

  AppStoreCertificate _certificate(Map<String, dynamic> data) {
    final attributes = data['attributes'] as Map<String, dynamic>;
    return AppStoreCertificate(
      id: data['id'] as String,
      content: attributes['certificateContent'] as String? ?? '',
      certificateType: attributes['certificateType'] as String? ?? '',
    );
  }

  AppStoreProfile _profile(Map<String, dynamic> data) {
    final attributes = data['attributes'] as Map<String, dynamic>;
    final relationships = data['relationships'] as Map<String, dynamic>? ?? const {};
    final certificates = relationships['certificates'] as Map<String, dynamic>? ?? const {};
    final linked = certificates['data'] as List<dynamic>? ?? const [];
    final bundleId = relationships['bundleId'] as Map<String, dynamic>? ?? const {};
    final linkedBundleId = bundleId['data'] as Map<String, dynamic>? ?? const {};
    return AppStoreProfile(
      id: data['id'] as String,
      name: attributes['name'] as String? ?? '',
      state: attributes['profileState'] as String? ?? '',
      content: attributes['profileContent'] as String? ?? '',
      bundleIdResourceId: linkedBundleId['id'] as String? ?? '',
      certificateIds: linked.cast<Map<String, dynamic>>().map((entry) => entry['id'] as String).toList(growable: false),
    );
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    logger.detail('GET $uri');
    return _decode(await _httpClient.get(uri, headers: _headers));
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    logger.detail('POST $uri');
    return _decode(await _httpClient.post(uri, headers: _headers, body: jsonEncode(body)));
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppStoreConnectException(response.statusCode, _errorMessage(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _errorMessage(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return response.body;
    }

    if (decoded is! Map<String, dynamic> || decoded['errors'] is! List) {
      return response.body;
    }

    final details = (decoded['errors'] as List<dynamic>).cast<Map<String, dynamic>>().map(_errorDetail);
    return details.join('; ');
  }

  String _errorDetail(Map<String, dynamic> error) =>
      [error['title'], error['detail']].whereType<String>().toSet().join(': ');
}
