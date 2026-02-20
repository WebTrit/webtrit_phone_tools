import 'package:data/datasource/datasource.dart';

class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    int maxRetries = 3,
    List<int> retryDelaysMs = const [2000, 4000, 8000],
  })  : assert(retryDelaysMs.length >= maxRetries, 'retryDelaysMs must contain at least maxRetries entries'),
        _dio = dio,
        _maxRetries = maxRetries,
        _retryDelaysMs = retryDelaysMs;

  static const _retryCountKey = 'retryCount';

  final Dio _dio;
  final int _maxRetries;
  final List<int> _retryDelaysMs;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) => _handleError(err, handler);

  Future<void> _handleError(DioException err, ErrorInterceptorHandler handler) async {
    try {
      if (_isUnauthorized(err)) {
        handler.reject(_buildUnauthorizedException(err));
        return;
      }

      final retryCount = (err.requestOptions.extra[_retryCountKey] as int?) ?? 0;

      if (!_shouldRetry(err) || retryCount >= _maxRetries) {
        handler.next(err);
        return;
      }

      await Future<void>.delayed(Duration(milliseconds: _retryDelaysMs[retryCount]));
      err.requestOptions.extra[_retryCountKey] = retryCount + 1;
      handler.resolve(await _dio.fetch(err.requestOptions));
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }

  bool _isUnauthorized(DioException err) => err.response?.statusCode == 401;

  bool _shouldRetry(DioException err) => _isServerError(err) || _isConnectionError(err);

  bool _isServerError(DioException err) => (err.response?.statusCode ?? 0) >= 500;

  bool _isConnectionError(DioException err) =>
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.connectionError;

  DioException _buildUnauthorizedException(DioException err) => DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: Exception('Authentication token has expired.'),
      );
}
