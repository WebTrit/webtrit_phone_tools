import 'package:data/datasource/datasource.dart';

import 'commands/app_resources/interceptors/interceptors.dart';
import 'constants.dart';

/// Builds the configurator backend data source the commands talk to.
///
/// [baseUrl] defaults to the address of the deployment this run is pointed at,
/// so a stand - or a test standing in for the backend - is selected by passing
/// its address here instead of by reaching into the wiring.
///
/// [logPrint] receives the request and response dumps; pass a sink of your own
/// to keep them out of the output.
ConfiguratorBackandDatasource createConfiguratorDatasource({
  String? baseUrl,
  void Function(Object?) logPrint = print,
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl ?? configuratorApiUrl))
    ..interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: logPrint,
    ));
  dio.interceptors.add(RetryInterceptor(dio: dio));
  // A command signs in with a static token, so there is no session to keep:
  // the store starts empty, the refresh interceptor finds nothing to renew,
  // and the token from the arguments does all the talking.
  return ConfiguratorBackandDatasource(
    dio,
    UnauthorizedInterceptor(),
    AuthPrefDatasource(_EphemeralStorage()),
  );
}

class _EphemeralStorage implements LocalStorage {
  final Map<String, String> _values = {};

  @override
  Future<void> setString(String key, String value) async => _values[key] = value;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  bool containsKey(String key) => _values.containsKey(key);
}
